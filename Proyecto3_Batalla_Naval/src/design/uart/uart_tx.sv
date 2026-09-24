// Transmisor UART 8N1, LSB-first.
module uart_tx #(
    parameter int unsigned CLK_FREQ_HZ = 100_000_000,
    parameter int unsigned BAUD_RATE   = 115_200
)(
    input  logic       clk_i,
    input  logic       rst_i,
    input  logic       start_i,
    input  logic [7:0] data_i,
    output logic       tx_o,
    output logic       ready_o
);
    localparam int unsigned CLKS_PER_BIT =
        (CLK_FREQ_HZ + (BAUD_RATE / 2)) / BAUD_RATE;
    localparam int unsigned COUNT_WIDTH =
        (CLKS_PER_BIT <= 1) ? 1 : $clog2(CLKS_PER_BIT);

    typedef enum logic [1:0] {
        TX_IDLE,
        TX_START,
        TX_DATA,
        TX_STOP
    } tx_state_t;

    tx_state_t state_q;
    logic [COUNT_WIDTH-1:0] baud_count_q;
    logic [2:0]             bit_index_q;
    logic [7:0]             data_q;

    assign ready_o = (state_q == TX_IDLE);

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            state_q      <= TX_IDLE;
            baud_count_q <= '0;
            bit_index_q  <= '0;
            data_q       <= '0;
            tx_o         <= 1'b1;
        end else begin
            case (state_q)
                TX_IDLE: begin
                    baud_count_q <= '0;
                    bit_index_q  <= '0;
                    tx_o         <= 1'b1;

                    if (start_i) begin
                        data_q <= data_i;
                        tx_o   <= 1'b0;
                        state_q <= TX_START;
                    end
                end

                TX_START: begin
                    if (baud_count_q == CLKS_PER_BIT - 1) begin
                        baud_count_q <= '0;
                        tx_o         <= data_q[0];
                        state_q      <= TX_DATA;
                    end else begin
                        baud_count_q <= baud_count_q + 1'b1;
                    end
                end

                TX_DATA: begin
                    if (baud_count_q == CLKS_PER_BIT - 1) begin
                        baud_count_q <= '0;
                        if (bit_index_q == 3'd7) begin
                            tx_o    <= 1'b1;
                            state_q <= TX_STOP;
                        end else begin
                            bit_index_q <= bit_index_q + 1'b1;
                            tx_o        <= data_q[bit_index_q + 1'b1];
                        end
                    end else begin
                        baud_count_q <= baud_count_q + 1'b1;
                    end
                end

                TX_STOP: begin
                    if (baud_count_q == CLKS_PER_BIT - 1) begin
                        baud_count_q <= '0;
                        tx_o         <= 1'b1;
                        state_q      <= TX_IDLE;
                    end else begin
                        baud_count_q <= baud_count_q + 1'b1;
                    end
                end

                default: begin
                    state_q <= TX_IDLE;
                    tx_o    <= 1'b1;
                end
            endcase
        end
    end
endmodule
