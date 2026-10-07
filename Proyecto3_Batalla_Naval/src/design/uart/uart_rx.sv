// Receptor UART 8N1 con sincronizador de entrada de dos flip-flops.
module uart_rx #(
    parameter int unsigned CLK_FREQ_HZ = 100_000_000,
    parameter int unsigned BAUD_RATE   = 115_200
)(
    input  logic       clk_i,
    input  logic       rst_i,
    input  logic       rx_i,
    output logic [7:0] data_o,
    output logic       valid_o
);
    localparam int unsigned CLKS_PER_BIT =
        (CLK_FREQ_HZ + (BAUD_RATE / 2)) / BAUD_RATE;
    localparam int unsigned HALF_BIT_CLKS = CLKS_PER_BIT / 2;
    localparam int unsigned COUNT_WIDTH =
        (CLKS_PER_BIT <= 1) ? 1 : $clog2(CLKS_PER_BIT);

    typedef enum logic [1:0] {
        RX_IDLE,
        RX_START,
        RX_DATA,
        RX_STOP
    } rx_state_t;

    rx_state_t state_q;
    // Conserva y agrupa las dos etapas que reciben la entrada asincrona.
    (* ASYNC_REG = "TRUE" *) logic rx_meta_q;
    (* ASYNC_REG = "TRUE" *) logic rx_sync_q;
    logic [COUNT_WIDTH-1:0] baud_count_q;
    logic [2:0]             bit_index_q;
    logic [7:0]             data_q;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            rx_meta_q <= 1'b1;
            rx_sync_q <= 1'b1;
        end else begin
            rx_meta_q <= rx_i;
            rx_sync_q <= rx_meta_q;
        end
    end

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            state_q      <= RX_IDLE;
            baud_count_q <= '0;
            bit_index_q  <= '0;
            data_q       <= '0;
            data_o       <= '0;
            valid_o      <= 1'b0;
        end else begin
            valid_o <= 1'b0;

            case (state_q)
                RX_IDLE: begin
                    baud_count_q <= '0;
                    bit_index_q  <= '0;
                    if (!rx_sync_q) begin
                        state_q <= RX_START;
                    end
                end

                RX_START: begin
                    if (baud_count_q == HALF_BIT_CLKS - 1) begin
                        baud_count_q <= '0;
                        if (!rx_sync_q) begin
                            state_q <= RX_DATA;
                        end else begin
                            state_q <= RX_IDLE;
                        end
                    end else begin
                        baud_count_q <= baud_count_q + 1'b1;
                    end
                end

                RX_DATA: begin
                    if (baud_count_q == CLKS_PER_BIT - 1) begin
                        baud_count_q       <= '0;
                        data_q[bit_index_q] <= rx_sync_q;
                        if (bit_index_q == 3'd7) begin
                            state_q <= RX_STOP;
                        end else begin
                            bit_index_q <= bit_index_q + 1'b1;
                        end
                    end else begin
                        baud_count_q <= baud_count_q + 1'b1;
                    end
                end

                RX_STOP: begin
                    if (baud_count_q == CLKS_PER_BIT - 1) begin
                        baud_count_q <= '0;
                        if (rx_sync_q) begin
                            data_o  <= data_q;
                            valid_o <= 1'b1;
                        end
                        state_q <= RX_IDLE;
                    end else begin
                        baud_count_q <= baud_count_q + 1'b1;
                    end
                end

                default: begin
                    state_q <= RX_IDLE;
                end
            endcase
        end
    end
endmodule
