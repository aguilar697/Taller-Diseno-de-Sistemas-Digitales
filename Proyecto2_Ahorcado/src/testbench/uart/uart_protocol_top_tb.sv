module uart_protocol_top_tb;

    timeunit 1ns;
    timeprecision 1ps;

    localparam time CLK_PERIOD       = 10ns;
    localparam time BIT_PERIOD       = 8680ns;
    localparam time WATCHDOG_TIMEOUT = 10ms;

    localparam int WAIT_CYCLES = 400_000;

    localparam logic [2:0] EVENT_START         = 3'd0;
    localparam logic [2:0] EVENT_LOSE_ATTEMPTS = 3'd5;

    logic clk_i = 1'b0;
    logic rst_i = 1'b1;

    logic [7:0] letter_o;
    logic       letter_valid_o;

    logic        event_valid_i = 1'b0;
    logic [2:0]  event_type_i = 3'd0;
    logic        difficulty_i = 1'b0;
    logic [3:0]  word_length_i = 4'd0;
    logic [2:0]  attempts_left_i = 3'd0;
    logic [95:0] revealed_word_i = 96'b0;
    logic [95:0] final_word_i = 96'b0;
    logic        event_ready_o;

    logic rx_i = 1'b1;
    logic tx_o;

    logic [7:0] uart_byte_queue[$];
    bit          uart_frame_active = 1'b0;
    int unsigned letter_valid_count = 0;
    int unsigned total_uart_bytes = 0;
    int unsigned expected_uart_bytes = 0;

    always #(CLK_PERIOD / 2) clk_i = ~clk_i;

    uart_protocol_top dut (
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
        .rx_i           (rx_i),
        .tx_o           (tx_o)
    );

    function automatic logic [95:0] pack_word (input string text);
        logic [95:0] packed_word;
        begin
            packed_word = 96'b0;

            for (int character_index = 0;
                 (character_index < text.len()) && (character_index < 12);
                 character_index++) begin
                packed_word[(8 * character_index) +: 8] = text[character_index];
            end

            return packed_word;
        end
    endfunction

    task automatic send_uart_byte (input logic [7:0] data);
        begin
            rx_i = 1'b1;
            #(BIT_PERIOD);

            rx_i = 1'b0;
            #(BIT_PERIOD);

            for (int bit_index = 0; bit_index < 8; bit_index++) begin
                rx_i = data[bit_index];
                #(BIT_PERIOD);
            end

            rx_i = 1'b1;
            #(BIT_PERIOD);
        end
    endtask

    task automatic receive_uart_byte (output logic [7:0] data);
        begin
            @(negedge tx_o);
            uart_frame_active = 1'b1;

            #(BIT_PERIOD / 2);
            if (tx_o !== 1'b0) begin
                $fatal(1, "UART TX: start bit invalido");
            end

            for (int bit_index = 0; bit_index < 8; bit_index++) begin
                #(BIT_PERIOD);
                data[bit_index] = tx_o;
            end

            #(BIT_PERIOD);
            if (tx_o !== 1'b1) begin
                $fatal(1, "UART TX: stop bit invalido");
            end

            uart_frame_active = 1'b0;
        end
    endtask

    task automatic wait_until_ready;
        bit observed;
        begin
            observed = 1'b0;

            for (int cycle = 0; cycle < WAIT_CYCLES; cycle++) begin
                @(negedge clk_i);
                if (event_ready_o === 1'b1) begin
                    observed = 1'b1;
                    break;
                end
            end

            if (!observed) begin
                $fatal(1, "Timeout esperando event_ready_o");
            end
        end
    endtask

    task automatic wait_for_letter_count (input int unsigned expected_count);
        bit observed;
        begin
            observed = 1'b0;

            for (int cycle = 0; cycle < WAIT_CYCLES; cycle++) begin
                if (letter_valid_count >= expected_count) begin
                    observed = 1'b1;
                    break;
                end
                @(posedge clk_i);
            end

            if (!observed) begin
                $fatal(1, "Timeout esperando letter_valid_o");
            end
        end
    endtask

    task automatic present_event (
        input logic [2:0]  event_type,
        input logic        difficulty,
        input logic [3:0]  word_length,
        input logic [2:0]  attempts_left,
        input logic [95:0] revealed_word,
        input logic [95:0] final_word
    );
        begin
            wait_until_ready();

            @(negedge clk_i);
            event_type_i      = event_type;
            difficulty_i      = difficulty;
            word_length_i     = word_length;
            attempts_left_i   = attempts_left;
            revealed_word_i   = revealed_word;
            final_word_i      = final_word;
            event_valid_i     = 1'b1;

            @(posedge clk_i);
            if (!(event_valid_i && event_ready_o)) begin
                $fatal(1, "No ocurrio el handshake del evento %0d", event_type);
            end

            @(negedge clk_i);
            event_valid_i = 1'b0;

            if (event_ready_o !== 1'b0) begin
                $fatal(1,
                    "event_ready_o no bajo tras aceptar el evento %0d",
                    event_type);
            end
        end
    endtask

    task automatic expect_uart_message (
        input string message_name,
        input string expected_message
    );
        logic [7:0] observed_byte;
        begin
            for (int byte_index = 0;
                 byte_index < expected_message.len();
                 byte_index++) begin
                while (uart_byte_queue.size() == 0) begin
                    @(posedge clk_i);
                end

                observed_byte = uart_byte_queue.pop_front();

                if (observed_byte !== expected_message[byte_index]) begin
                    $fatal(1,
                        "%s byte %0d: esperado 0x%02h, recibido 0x%02h",
                        message_name, byte_index,
                        expected_message[byte_index], observed_byte);
                end

                if (observed_byte == 8'h0D) begin
                    $fatal(1, "%s: se recibio CR; solo se permite LF", message_name);
                end
            end

            expected_uart_bytes += expected_message.len();
            wait_until_ready();
            @(negedge clk_i);

            if (uart_byte_queue.size() != 0) begin
                $fatal(1, "%s: se transmitieron bytes adicionales", message_name);
            end

            if (uart_frame_active) begin
                $fatal(1, "%s: existe una trama UART adicional activa", message_name);
            end

            if (tx_o !== 1'b1) begin
                $fatal(1, "%s: tx_o no regreso al nivel de reposo", message_name);
            end

            if (expected_message[expected_message.len() - 1] != 8'h0A) begin
                $fatal(1, "%s: el mensaje esperado no termina en LF", message_name);
            end
        end
    endtask

    initial begin : uart_tx_monitor
        logic [7:0] received_byte;

        forever begin
            receive_uart_byte(received_byte);
            uart_byte_queue.push_back(received_byte);
            total_uart_bytes++;
        end
    end

    initial begin : letter_valid_monitor
        time pulse_start;

        forever begin
            @(posedge letter_valid_o);
            pulse_start = $time;

            case (letter_valid_count)
                0: begin
                    if (letter_o !== 8'h41) begin
                        $fatal(1,
                            "Primera letra: esperada 0x41, recibida 0x%02h",
                            letter_o);
                    end
                end

                1: begin
                    if (letter_o !== 8'h5A) begin
                        $fatal(1,
                            "Segunda letra: esperada 0x5A, recibida 0x%02h",
                            letter_o);
                    end
                end

                default: begin
                    $fatal(1, "Se observo un letter_valid_o adicional");
                end
            endcase

            @(negedge letter_valid_o);

            if (($time - pulse_start) != CLK_PERIOD) begin
                $fatal(1,
                    "letter_valid_o duro %0t; se esperaba %0t",
                    $time - pulse_start, CLK_PERIOD);
            end

            letter_valid_count++;
        end
    end

    initial begin : stimulus
        rst_i            = 1'b1;
        rx_i             = 1'b1;
        event_valid_i    = 1'b0;
        event_type_i     = 3'd0;
        difficulty_i     = 1'b0;
        word_length_i    = 4'd0;
        attempts_left_i  = 3'd0;
        revealed_word_i  = 96'b0;
        final_word_i     = 96'b0;

        repeat (3) @(posedge clk_i);
        @(negedge clk_i);

        if (letter_o !== 8'h00) begin
            $fatal(1, "Reset: letter_o no fue limpiado");
        end

        if (letter_valid_o !== 1'b0) begin
            $fatal(1, "Reset: letter_valid_o no fue limpiado");
        end

        if (event_ready_o !== 1'b1) begin
            $fatal(1, "Reset: event_ready_o no esta disponible");
        end

        if (tx_o !== 1'b1) begin
            $fatal(1, "Reset: tx_o no esta en reposo logico 1");
        end

        if (rx_i !== 1'b1) begin
            $fatal(1, "Reset: rx_i no esta en reposo logico 1");
        end

        rst_i = 1'b0;

        send_uart_byte(8'h41);
        wait_for_letter_count(1);
        wait_until_ready();

        if (letter_o !== 8'h41) begin
            $fatal(1, "RX representativo: letter_o no contiene 0x41");
        end

        present_event(EVENT_START, 1'b0, 4'd7, 3'd0,
            96'b0, 96'b0);
        expect_uart_message("START EASY", "START,EASY,7\n");

        present_event(EVENT_LOSE_ATTEMPTS, 1'b0, 4'd12, 3'd0,
            96'b0, pack_word("ABCDEFGHIJKL"));

        @(negedge tx_o);
        send_uart_byte(8'h5A);

        if (event_ready_o !== 1'b0) begin
            $fatal(1, "RX durante TX: event_ready_o subio durante el mensaje");
        end

        wait_for_letter_count(2);

        if (letter_o !== 8'h5A) begin
            $fatal(1, "RX durante TX: letter_o no contiene 0x5A");
        end

        expect_uart_message("LOSE_ATTEMPTS con RX simultaneo",
            "LOSE_ATTEMPTS,ABCDEFGHIJKL\n");

        if (letter_valid_count != 2) begin
            $fatal(1,
                "Conteo letter_valid_o: esperados 2, observados %0d",
                letter_valid_count);
        end

        if (total_uart_bytes != expected_uart_bytes) begin
            $fatal(1,
                "Conteo UART TX: esperados %0d, observados %0d",
                expected_uart_bytes, total_uart_bytes);
        end

        if (uart_byte_queue.size() != 0) begin
            $fatal(1, "La cola UART contiene bytes no verificados");
        end

        $display("uart_protocol_top_tb: todas las pruebas finalizaron correctamente");
        $finish;
    end

    initial begin : watchdog
        #WATCHDOG_TIMEOUT;
        $fatal(1, "uart_protocol_top_tb: tiempo maximo de simulacion excedido");
    end

endmodule
