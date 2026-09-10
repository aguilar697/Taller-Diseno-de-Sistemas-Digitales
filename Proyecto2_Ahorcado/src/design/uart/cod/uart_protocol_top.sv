module uart_protocol_top (
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

    input  logic        rx_i,
    output logic        tx_o
);

    logic        mmio_write_enable;
    logic [1:0]  mmio_addr;
    logic [31:0] mmio_wdata;
    logic [31:0] mmio_rdata;

    protocol_controller protocol_controller_inst (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .letter_o       (letter_o),
        .letter_valid_o (letter_valid_o),
        .event_valid_i  (event_valid_i),
        .event_type_i   (event_type_i),
        .difficulty_i   (difficulty_i),
        .word_length_i  (word_length_i),
        .attempts_left_i(attempts_left_i),
        .revealed_word_i(revealed_word_i),
        .final_word_i   (final_word_i),
        .event_ready_o  (event_ready_o),
        .write_enable_o (mmio_write_enable),
        .addr_o         (mmio_addr),
        .wdata_o        (mmio_wdata),
        .rdata_i        (mmio_rdata)
    );

    uart_peripheral uart_peripheral_inst (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .write_enable_i (mmio_write_enable),
        .addr_i         (mmio_addr),
        .wdata_i        (mmio_wdata),
        .rdata_o        (mmio_rdata),
        .rx_i           (rx_i),
        .tx_o           (tx_o)
    );

endmodule
