// Decodificacion combinacional del mapa de datos y perifericos.
module address_decoder (
    input  logic [31:0] addr_i,
    output logic        ram_sel_o,
    output logic        uart_sel_o,
    output logic        input_sel_o,
    output logic        sevenseg_sel_o,
    output logic        led_sel_o,
    output logic        buzzer_sel_o,
    output logic        vga_sel_o,
    output logic [9:0]  ram_addr_o,
    output logic [1:0]  uart_addr_o,
    output logic [1:0]  input_addr_o,
    output logic [1:0]  sevenseg_addr_o,
    output logic [1:0]  led_addr_o,
    output logic [1:0]  buzzer_addr_o,
    output logic [8:0]  vga_addr_o
);
    localparam logic [31:0] RAM_BASE     = 32'h00002000;
    localparam logic [31:0] RAM_END      = 32'h00002FFF;
    localparam logic [31:0] UART_CONTROL = 32'h00010040;
    localparam logic [31:0] UART_TX      = 32'h00010044;
    localparam logic [31:0] UART_RX      = 32'h00010048;
    localparam logic [31:0] INPUT_ADDR   = 32'h00010120;
    localparam logic [31:0] SEVENSEG_ADDR= 32'h00010130;
    localparam logic [31:0] LED_ADDR     = 32'h00010138;
    localparam logic [31:0] BUZZER_ADDR  = 32'h00010140;
    localparam logic [31:0] VGA_BASE     = 32'h00011000;
    localparam logic [31:0] VGA_END      = 32'h000117FF;

    always_comb begin
        ram_sel_o=0; uart_sel_o=0; input_sel_o=0; sevenseg_sel_o=0;
        led_sel_o=0; buzzer_sel_o=0; vga_sel_o=0;
        ram_addr_o=0; uart_addr_o=0; input_addr_o=0; sevenseg_addr_o=0;
        led_addr_o=0; buzzer_addr_o=0; vga_addr_o=0;

        if(addr_i>=RAM_BASE && addr_i<=RAM_END)begin
            ram_sel_o=1;
            ram_addr_o=(addr_i-RAM_BASE)>>2;
        end else begin
            case(addr_i)
                UART_CONTROL:begin uart_sel_o=1;uart_addr_o=2'b00;end
                UART_TX:begin uart_sel_o=1;uart_addr_o=2'b01;end
                UART_RX:begin uart_sel_o=1;uart_addr_o=2'b10;end
                INPUT_ADDR:begin input_sel_o=1;input_addr_o=2'b00;end
                SEVENSEG_ADDR:begin sevenseg_sel_o=1;sevenseg_addr_o=2'b00;end
                LED_ADDR:begin led_sel_o=1;led_addr_o=2'b00;end
                BUZZER_ADDR:begin buzzer_sel_o=1;buzzer_addr_o=2'b00;end
                default:begin
                    if(addr_i>=VGA_BASE && addr_i<=VGA_END)begin
                        vga_sel_o=1;
                        vga_addr_o=(addr_i-VGA_BASE)>>2;
                    end
                end
            endcase
        end
    end
endmodule
