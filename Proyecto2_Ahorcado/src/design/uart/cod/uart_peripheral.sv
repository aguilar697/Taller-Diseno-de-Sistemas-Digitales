module uart_peripheral (
    input  logic        clk_i,
    input  logic        rst_i,

    input  logic        write_enable_i,
    input  logic [1:0]  addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,

    input  logic        rx_i,
    output logic        tx_o
);

    localparam logic [1:0] ADDR_TX_DATA = 2'b00;
    localparam logic [1:0] ADDR_RX_DATA = 2'b01;
    localparam logic [1:0] ADDR_CONTROL = 2'b10;
    localparam logic [1:0] ADDR_RESERVED = 2'b11;

    logic [7:0] tx_data_reg;
    logic [7:0] rx_data_reg;
    logic       send_reg;
    logic       new_rx_reg;

    logic       uart_tx_start;
    logic       uart_tx_rdy;
    logic       uart_rx_data_rdy;
    logic [7:0] uart_data_out;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            tx_data_reg  <= 8'b0;
            rx_data_reg  <= 8'b0;
            send_reg     <= 1'b0;
            new_rx_reg   <= 1'b0;
            uart_tx_start <= 1'b0;
        end else begin
            uart_tx_start <= 1'b0;

            if (uart_tx_rdy) begin
                send_reg <= 1'b0;
            end

            if (write_enable_i) begin
                case (addr_i)
                    ADDR_TX_DATA: begin
                        tx_data_reg <= wdata_i[7:0];
                    end

                    ADDR_CONTROL: begin
                        if (wdata_i[0] && !send_reg) begin
                            send_reg      <= 1'b1;
                            uart_tx_start <= 1'b1;
                        end

                        if (wdata_i[1]) begin
                            new_rx_reg <= 1'b0;
                        end
                    end

                    default: begin
                    end
                endcase
            end

            if (uart_rx_data_rdy) begin
                rx_data_reg <= uart_data_out;
                new_rx_reg  <= 1'b1;
            end
        end
    end

    always_comb begin
        rdata_o = 32'b0;

        case (addr_i)
            ADDR_TX_DATA: begin
                rdata_o = {24'b0, tx_data_reg};
            end

            ADDR_RX_DATA: begin
                rdata_o = {24'b0, rx_data_reg};
            end

            ADDR_CONTROL: begin
                rdata_o[0] = send_reg;
                rdata_o[1] = new_rx_reg;
            end

            ADDR_RESERVED: begin
                rdata_o = 32'b0;
            end

            default: begin
                rdata_o = 32'b0;
            end
        endcase
    end

    UART uart_core (
        .clk         (clk_i),
        .reset       (rst_i),
        .tx_start    (uart_tx_start),
        .tx_rdy      (uart_tx_rdy),
        .rx_data_rdy (uart_rx_data_rdy),
        .data_in     (tx_data_reg),
        .data_out    (uart_data_out),
        .rx          (rx_i),
        .tx          (tx_o)
    );

endmodule
