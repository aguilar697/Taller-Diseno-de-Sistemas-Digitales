// Interconexion entre la interfaz de datos del CPU y los destinos MMIO.
module data_bus (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic [31:0] cpu_addr_i,
    input  logic [31:0] cpu_wdata_i,
    input  logic        cpu_we_i,
    output logic [31:0] cpu_rdata_o,
    input  logic [31:0] ram_rdata_i,
    input  logic [31:0] uart_rdata_i,
    input  logic [31:0] input_rdata_i,
    input  logic [31:0] sevenseg_rdata_i,
    input  logic [31:0] led_rdata_i,
    input  logic [31:0] buzzer_rdata_i,
    input  logic [31:0] vga_rdata_i,
    output logic [31:0] peripheral_wdata_o,
    output logic [9:0]  ram_addr_o,
    output logic [1:0]  uart_addr_o,
    output logic [1:0]  input_addr_o,
    output logic [1:0]  sevenseg_addr_o,
    output logic [1:0]  led_addr_o,
    output logic [1:0]  buzzer_addr_o,
    output logic [8:0]  vga_addr_o,
    output logic        ram_write_enable_o,
    output logic        uart_write_enable_o,
    output logic        input_write_enable_o,
    output logic        sevenseg_write_enable_o,
    output logic        led_write_enable_o,
    output logic        buzzer_write_enable_o,
    output logic        vga_write_enable_o
);
    localparam logic [2:0] READ_NONE=3'd0, READ_RAM=3'd1, READ_UART=3'd2,
                           READ_INPUT=3'd3, READ_SEVENSEG=3'd4,
                           READ_LED=3'd5, READ_BUZZER=3'd6, READ_VGA=3'd7;

    logic ram_sel,uart_sel,input_sel,sevenseg_sel,led_sel,buzzer_sel,vga_sel;
    logic [2:0] read_sel_q;

    address_decoder decoder(
        .addr_i(cpu_addr_i),
        .ram_sel_o(ram_sel),.uart_sel_o(uart_sel),.input_sel_o(input_sel),
        .sevenseg_sel_o(sevenseg_sel),.led_sel_o(led_sel),
        .buzzer_sel_o(buzzer_sel),.vga_sel_o(vga_sel),
        .ram_addr_o(ram_addr_o),.uart_addr_o(uart_addr_o),
        .input_addr_o(input_addr_o),.sevenseg_addr_o(sevenseg_addr_o),
        .led_addr_o(led_addr_o),.buzzer_addr_o(buzzer_addr_o),
        .vga_addr_o(vga_addr_o)
    );

    always_comb begin
        peripheral_wdata_o=cpu_wdata_i;
        ram_write_enable_o=cpu_we_i && ram_sel && !rst_i;
        uart_write_enable_o=cpu_we_i && uart_sel && !rst_i;
        input_write_enable_o=cpu_we_i && input_sel && !rst_i;
        sevenseg_write_enable_o=cpu_we_i && sevenseg_sel && !rst_i;
        led_write_enable_o=cpu_we_i && led_sel && !rst_i;
        buzzer_write_enable_o=cpu_we_i && buzzer_sel && !rst_i;
        vga_write_enable_o=cpu_we_i && vga_sel && !rst_i;
    end

    always_ff @(posedge clk_i) begin
        if(rst_i || cpu_we_i) read_sel_q<=READ_NONE;
        else if(ram_sel) read_sel_q<=READ_RAM;
        else if(uart_sel) read_sel_q<=READ_UART;
        else if(input_sel) read_sel_q<=READ_INPUT;
        else if(sevenseg_sel) read_sel_q<=READ_SEVENSEG;
        else if(led_sel) read_sel_q<=READ_LED;
        else if(buzzer_sel) read_sel_q<=READ_BUZZER;
        else if(vga_sel) read_sel_q<=READ_VGA;
        else read_sel_q<=READ_NONE;
    end

    always_comb begin
        case(read_sel_q)
            READ_RAM:cpu_rdata_o=ram_rdata_i;
            READ_UART:cpu_rdata_o=uart_rdata_i;
            READ_INPUT:cpu_rdata_o=input_rdata_i;
            READ_SEVENSEG:cpu_rdata_o=sevenseg_rdata_i;
            READ_LED:cpu_rdata_o=led_rdata_i;
            READ_BUZZER:cpu_rdata_o=buzzer_rdata_i;
            READ_VGA:cpu_rdata_o=vga_rdata_i;
            default:cpu_rdata_o=32'h00000000;
        endcase
    end
endmodule
