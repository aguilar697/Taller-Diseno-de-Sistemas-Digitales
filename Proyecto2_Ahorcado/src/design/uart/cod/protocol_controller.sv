module protocol_controller (
    input  logic        clk_i,
    input  logic        rst_i,

    output logic [7:0]  letter_o,
    output logic        letter_valid_o,

    input  logic        event_valid_i,
    input  logic [2:0]  event_type_i,
    input  logic        difficulty_i,
    input  logic [3:0]  word_length_i,
    input  logic [2:0]  attempts_left_i,
    input  logic [95:0] revealed_word_i,
    input  logic [95:0] final_word_i,
    output logic        event_ready_o,

    output logic        write_enable_o,
    output logic [1:0]  addr_o,
    output logic [31:0] wdata_o,
    input  logic [31:0] rdata_i
);

    localparam logic [1:0] ADDR_CONTROL = 2'b10;

    typedef enum logic {
        BUS_OWNER_TX,
        BUS_OWNER_RX
    } bus_owner_t;

    bus_owner_t bus_owner;

    logic        rx_bus_grant;
    logic        rx_write_enable;
    logic [1:0]  rx_addr;
    logic [31:0] rx_wdata;

    logic        tx_bus_grant;
    logic        tx_write_enable;
    logic [1:0]  tx_addr;
    logic [31:0] tx_wdata;

    protocol_rx_controller receiver_controller (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .bus_grant_i    (rx_bus_grant),
        .write_enable_o (rx_write_enable),
        .addr_o         (rx_addr),
        .wdata_o        (rx_wdata),
        .rdata_i        (rdata_i),
        .letter_o       (letter_o),
        .letter_valid_o (letter_valid_o)
    );

    protocol_tx_controller transmitter_controller (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .bus_grant_i    (tx_bus_grant),
        .event_valid_i  (event_valid_i),
        .event_type_i   (event_type_i),
        .difficulty_i   (difficulty_i),
        .word_length_i  (word_length_i),
        .attempts_left_i(attempts_left_i),
        .revealed_word_i(revealed_word_i),
        .final_word_i   (final_word_i),
        .event_ready_o  (event_ready_o),
        .write_enable_o (tx_write_enable),
        .addr_o         (tx_addr),
        .wdata_o        (tx_wdata),
        .rdata_i        (rdata_i)
    );

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            bus_owner <= BUS_OWNER_TX;
        end else begin
            case (bus_owner)
                BUS_OWNER_TX: begin
                    if (!tx_write_enable &&
                        (tx_addr == ADDR_CONTROL) &&
                        rdata_i[1]) begin
                        bus_owner <= BUS_OWNER_RX;
                    end
                end

                BUS_OWNER_RX: begin
                    if (rx_write_enable &&
                        (rx_addr == ADDR_CONTROL) &&
                        rx_wdata[1]) begin
                        bus_owner <= BUS_OWNER_TX;
                    end
                end

                default: begin
                    bus_owner <= BUS_OWNER_TX;
                end
            endcase
        end
    end

    always_comb begin
        rx_bus_grant  = 1'b0;
        tx_bus_grant  = 1'b0;
        write_enable_o = 1'b0;
        addr_o         = ADDR_CONTROL;
        wdata_o        = 32'b0;

        case (bus_owner)
            BUS_OWNER_TX: begin
                tx_bus_grant  = 1'b1;
                write_enable_o = tx_write_enable;
                addr_o         = tx_addr;
                wdata_o        = tx_wdata;
            end

            BUS_OWNER_RX: begin
                rx_bus_grant  = 1'b1;
                write_enable_o = rx_write_enable;
                addr_o         = rx_addr;
                wdata_o        = rx_wdata;
            end

            default: begin
            end
        endcase
    end

endmodule
