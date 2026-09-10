module protocol_rx_controller (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        bus_grant_i,

    output logic        write_enable_o,
    output logic [1:0]  addr_o,
    output logic [31:0] wdata_o,
    input  logic [31:0] rdata_i,

    output logic [7:0]  letter_o,
    output logic        letter_valid_o
);

    localparam logic [1:0] ADDR_RX_DATA = 2'b01;
    localparam logic [1:0] ADDR_CONTROL = 2'b10;

    typedef enum logic [1:0] {
        RX_POLL_CONTROL,
        RX_READ_DATA,
        RX_VALIDATE,
        RX_ACK
    } rx_state_t;

    rx_state_t state;
    logic [7:0] rx_byte;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            state          <= RX_POLL_CONTROL;
            rx_byte        <= 8'b0;
            letter_o       <= 8'b0;
            letter_valid_o <= 1'b0;
        end else begin
            letter_valid_o <= 1'b0;

            if (bus_grant_i) begin
                case (state)
                    RX_POLL_CONTROL: begin
                        if (rdata_i[1]) begin
                            state <= RX_READ_DATA;
                        end
                    end

                    RX_READ_DATA: begin
                        rx_byte <= rdata_i[7:0];
                        state   <= RX_VALIDATE;
                    end

                    RX_VALIDATE: begin
                        if ((rx_byte >= 8'h41) && (rx_byte <= 8'h5A)) begin
                            letter_o       <= rx_byte;
                            letter_valid_o <= 1'b1;
                        end

                        state <= RX_ACK;
                    end

                    RX_ACK: begin
                        state <= RX_POLL_CONTROL;
                    end

                    default: begin
                        state          <= RX_POLL_CONTROL;
                        rx_byte        <= 8'b0;
                        letter_o       <= 8'b0;
                        letter_valid_o <= 1'b0;
                    end
                endcase
            end
        end
    end

    always_comb begin
        write_enable_o = 1'b0;
        addr_o         = ADDR_CONTROL;
        wdata_o        = 32'b0;

        case (state)
            RX_POLL_CONTROL: begin
                addr_o = ADDR_CONTROL;
            end

            RX_READ_DATA: begin
                addr_o = ADDR_RX_DATA;
            end

            RX_VALIDATE: begin
                addr_o = ADDR_CONTROL;
            end

            RX_ACK: begin
                write_enable_o = bus_grant_i;
                addr_o         = ADDR_CONTROL;
                wdata_o        = 32'h0000_0002;
            end

            default: begin
                write_enable_o = 1'b0;
                addr_o         = ADDR_CONTROL;
                wdata_o        = 32'b0;
            end
        endcase
    end

endmodule
