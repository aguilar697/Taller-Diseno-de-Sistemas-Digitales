module protocol_tx_controller_tb;

    timeunit 1ns;
    timeprecision 1ps;

    localparam time CLK_PERIOD       = 10ns;
    localparam time BIT_PERIOD       = 8680ns;
    localparam time WATCHDOG_TIMEOUT = 20ms;

    localparam int READY_WAIT_CYCLES = 100_000;

    localparam logic [2:0] EVENT_START         = 3'd0;
    localparam logic [2:0] EVENT_HIT           = 3'd1;
    localparam logic [2:0] EVENT_MISS          = 3'd2;
    localparam logic [2:0] EVENT_REPEAT        = 3'd3;
    localparam logic [2:0] EVENT_WIN           = 3'd4;
    localparam logic [2:0] EVENT_LOSE_ATTEMPTS = 3'd5;
    localparam logic [2:0] EVENT_LOSE_TIME     = 3'd6;
    localparam logic [2:0] EVENT_RESERVED      = 3'd7;

    logic        clk_i = 1'b0;
    logic        rst_i = 1'b1;
    logic        bus_grant_i = 1'b1;

    logic        event_valid_i = 1'b0;
    logic [2:0]  event_type_i = EVENT_RESERVED;
    logic        difficulty_i = 1'b0;
    logic [3:0]  word_length_i = 4'd0;
    logic [2:0]  attempts_left_i = 3'd0;
    logic [95:0] revealed_word_i = 96'b0;
    logic [95:0] final_word_i = 96'b0;
    logic        event_ready_o;

    logic        mmio_write_enable;
    logic [1:0]  mmio_addr;
    logic [31:0] mmio_wdata;
    logic [31:0] mmio_rdata;

    logic        rx_i = 1'b1;
    logic        tx_o;

    logic [7:0] uart_byte_queue[$];
    bit         uart_frame_active = 1'b0;
    int unsigned total_uart_bytes = 0;
    int unsigned expected_uart_bytes = 0;

    always #(CLK_PERIOD / 2) clk_i = ~clk_i;

    protocol_tx_controller protocol_tx_controller_dut (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .bus_grant_i    (bus_grant_i),
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

    uart_peripheral uart_peripheral_dut (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .write_enable_i (mmio_write_enable),
        .addr_i         (mmio_addr),
        .wdata_i        (mmio_wdata),
        .rdata_o        (mmio_rdata),
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

    task automatic receive_uart_byte (output logic [7:0] data);
        begin
            @(negedge tx_o);
            uart_frame_active = 1'b1;

            #(BIT_PERIOD / 2);
            if (tx_o !== 1'b0) begin
                $fatal(1, "UART TX: start bit inválido");
            end

            for (int bit_index = 0; bit_index < 8; bit_index++) begin
                #(BIT_PERIOD);
                data[bit_index] = tx_o;
            end

            #(BIT_PERIOD);
            if (tx_o !== 1'b1) begin
                $fatal(1, "UART TX: stop bit inválido");
            end

            uart_frame_active = 1'b0;
        end
    endtask

    task automatic wait_until_ready;
        bit observed;
        begin
            observed = 1'b0;

            for (int cycle = 0; cycle < READY_WAIT_CYCLES; cycle++) begin
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
            event_type_i     = event_type;
            difficulty_i     = difficulty;
            word_length_i    = word_length;
            attempts_left_i  = attempts_left;
            revealed_word_i  = revealed_word;
            final_word_i     = final_word;
            event_valid_i    = 1'b1;

            @(posedge clk_i);
            if (!(event_valid_i && event_ready_o)) begin
                $fatal(1, "No ocurrió el handshake del evento");
            end

            @(negedge clk_i);
            event_valid_i = 1'b0;

            if (event_ready_o !== 1'b0) begin
                $fatal(1,
                    "event_ready_o no bajó después de aceptar el evento %0d",
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
                        message_name,
                        byte_index,
                        expected_message[byte_index],
                        observed_byte);
                end

                if (observed_byte == 8'h0D) begin
                    $fatal(1, "%s: se recibió CR; solo se permite LF", message_name);
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
                $fatal(1, "%s: tx_o no regresó al nivel de reposo", message_name);
            end
        end
    endtask

    task automatic expect_no_uart_activity (
        input string test_name,
        input time   observation_time
    );
        int unsigned byte_count_before;
        begin
            byte_count_before = total_uart_bytes;

            if ((uart_byte_queue.size() != 0) || uart_frame_active ||
                (tx_o !== 1'b1)) begin
                $fatal(1, "%s: la UART no estaba inactiva al iniciar", test_name);
            end

            #(observation_time);

            if ((total_uart_bytes != byte_count_before) ||
                (uart_byte_queue.size() != 0) || uart_frame_active ||
                (tx_o !== 1'b1)) begin
                $fatal(1, "%s: se detectó actividad UART inesperada", test_name);
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

    initial begin : stimulus
        rst_i = 1'b1;
        rx_i  = 1'b1;
        event_valid_i = 1'b0;

        repeat (3) @(posedge clk_i);
        @(negedge clk_i);

        if (event_ready_o !== 1'b1) begin
            $fatal(1, "Reset: event_ready_o no está disponible");
        end

        if (tx_o !== 1'b1) begin
            $fatal(1, "Reset: tx_o no está en reposo lógico 1");
        end

        if (mmio_write_enable !== 1'b0) begin
            $fatal(1, "Reset: existe una escritura MMIO activa");
        end

        if (uart_frame_active || (uart_byte_queue.size() != 0)) begin
            $fatal(1, "Reset: se detectó una transmisión UART activa");
        end

        rst_i = 1'b0;

        present_event(EVENT_START, 1'b0, 4'd7, 3'd0,
            96'b0, 96'b0);
        expect_uart_message("START EASY", "START,EASY,7\n");

        present_event(EVENT_START, 1'b1, 4'd12, 3'd0,
            96'b0, 96'b0);
        expect_uart_message("START HARD", "START,HARD,12\n");

        present_event(EVENT_HIT, 1'b0, 4'd7, 3'd5,
            pack_word("_A__A__"), 96'b0);
        expect_uart_message("HIT", "HIT,_A__A__,5\n");

        present_event(EVENT_MISS, 1'b0, 4'd7, 3'd4,
            pack_word("_A__A__"), 96'b0);
        expect_uart_message("MISS", "MISS,_A__A__,4\n");

        present_event(EVENT_REPEAT, 1'b0, 4'd7, 3'd4,
            pack_word("_A__A__"), 96'b0);
        expect_uart_message("REPEAT", "REPEAT,_A__A__,4\n");

        present_event(EVENT_WIN, 1'b0, 4'd7, 3'd0,
            96'b0, pack_word("PALABRA"));
        expect_uart_message("WIN", "WIN,PALABRA\n");

        present_event(EVENT_LOSE_ATTEMPTS, 1'b0, 4'd12, 3'd0,
            96'b0, pack_word("ABCDEFGHIJKL"));
        expect_uart_message("LOSE_ATTEMPTS máximo",
            "LOSE_ATTEMPTS,ABCDEFGHIJKL\n");

        present_event(EVENT_LOSE_TIME, 1'b0, 4'd6, 3'd0,
            96'b0, pack_word("TIEMPO"));
        expect_uart_message("LOSE_TIME", "LOSE_TIME,TIEMPO\n");

        present_event(EVENT_HIT, 1'b0, 4'd7, 3'd0,
            pack_word("_A__A__"), 96'b0);
        expect_uart_message("HIT attempts_left=0", "HIT,_A__A__,0\n");

        present_event(EVENT_RESERVED, 1'b0, 4'd4, 3'd0,
            pack_word("____"), pack_word("TEST"));
        wait_until_ready();
        expect_no_uart_activity("EVENT_RESERVED", 12 * BIT_PERIOD);

        if (total_uart_bytes != expected_uart_bytes) begin
            $fatal(1,
                "Conteo UART final: esperados %0d bytes, recibidos %0d",
                expected_uart_bytes, total_uart_bytes);
        end

        if (uart_byte_queue.size() != 0) begin
            $fatal(1, "La cola UART contiene bytes no verificados");
        end

        $display("protocol_tx_controller_tb: todas las pruebas finalizaron correctamente");
        $finish;
    end

    initial begin : watchdog
        #WATCHDOG_TIMEOUT;
        $fatal(1,
            "protocol_tx_controller_tb: tiempo máximo de simulación excedido");
    end

endmodule
