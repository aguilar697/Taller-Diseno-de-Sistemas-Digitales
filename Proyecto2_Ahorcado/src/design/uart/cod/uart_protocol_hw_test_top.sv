module uart_protocol_hw_test_top (
    input  logic clk_i,
    input  logic rst_i,
    input  logic rx_i,
    output logic tx_o
);

    logic [7:0] received_letter;
    logic       received_letter_valid;
    logic       event_pending;
    logic       event_ready;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            event_pending <= 1'b0;
        end else begin
            if (event_pending && event_ready) begin
                event_pending <= 1'b0;
            end else if (received_letter_valid) begin
                event_pending <= 1'b1;
            end
        end
    end

    uart_protocol_top uart_protocol_top_inst (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .letter_o       (received_letter),
        .letter_valid_o (received_letter_valid),
        .event_valid_i  (event_pending),
        .event_type_i   (3'd0),
        .difficulty_i   (1'b0),
        .word_length_i  (4'd7),
        .attempts_left_i(3'd0),
        .revealed_word_i(96'b0),
        .final_word_i   (96'b0),
        .event_ready_o  (event_ready),
        .rx_i           (rx_i),
        .tx_o           (tx_o)
    );

    // Esta prueba emite una respuesta fija. Si llega otra letra mientras
    // event_pending esta activo, se ignora porque no existe una cola.

endmodule
