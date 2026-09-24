// Periferico UART con tres registros MMIO de 32 bits.
module uart_peripheral #(
    parameter int unsigned CLK_FREQ_HZ = 100_000_000,
    parameter int unsigned BAUD_RATE   = 115_200
)(
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        write_enable_i,
    input  logic [1:0]  addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,
    input  logic        uart_rx_i,
    output logic        uart_tx_o
);
    localparam logic [1:0] ADDR_CONTROL = 2'b00;
    localparam logic [1:0] ADDR_TX_DATA = 2'b01;
    localparam logic [1:0] ADDR_RX_DATA = 2'b10;

    logic [7:0] tx_data_q;
    logic [7:0] rx_data_q;
    logic       tx_start_q;
    logic       tx_core_ready;
    logic [7:0] rx_core_data;
    logic       rx_core_valid;
    logic       rx_valid_q;
    logic       tx_ready_status;

    // El request registrado impide aceptar otra escritura antes de que TX
    // observe el pulso de inicio.
    assign tx_ready_status = tx_core_ready && !tx_start_q;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            tx_data_q  <= '0;
            rx_data_q  <= '0;
            tx_start_q <= 1'b0;
            rx_valid_q <= 1'b0;
        end else begin
            tx_start_q <= 1'b0;

            if (write_enable_i && addr_i == ADDR_TX_DATA &&
                tx_ready_status) begin
                tx_data_q  <= wdata_i[7:0];
                tx_start_q <= 1'b1;
            end

            if (write_enable_i && addr_i == ADDR_CONTROL &&
                wdata_i[1]) begin
                rx_valid_q <= 1'b0;
            end

            // Una recepción nueva tiene prioridad sobre una limpieza simultánea.
            if (rx_core_valid) begin
                rx_data_q  <= rx_core_data;
                rx_valid_q <= 1'b1;
            end
        end
    end

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            rdata_o <= 32'b0;
        end else begin
            case (addr_i)
                ADDR_CONTROL:
                    rdata_o <= {30'b0, rx_valid_q, tx_ready_status};
                ADDR_TX_DATA:
                    rdata_o <= {24'b0, tx_data_q};
                ADDR_RX_DATA:
                    rdata_o <= {24'b0, rx_data_q};
                default:
                    rdata_o <= 32'b0;
            endcase
        end
    end

    uart_tx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) tx_core (
        .clk_i  (clk_i),
        .rst_i  (rst_i),
        .start_i(tx_start_q),
        .data_i (tx_data_q),
        .tx_o   (uart_tx_o),
        .ready_o(tx_core_ready)
    );

    uart_rx #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .BAUD_RATE  (BAUD_RATE)
    ) rx_core (
        .clk_i  (clk_i),
        .rst_i  (rst_i),
        .rx_i   (uart_rx_i),
        .data_o (rx_core_data),
        .valid_o(rx_core_valid)
    );
endmodule
