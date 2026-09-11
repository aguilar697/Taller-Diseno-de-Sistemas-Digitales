`timescale 1ns/1ps

module game_fsm_tb;

    localparam logic [2:0] GS_MODE_SELECT   = 3'd0;
    localparam logic [2:0] GS_STARTING      = 3'd1;
    localparam logic [2:0] GS_ACTIVE        = 3'd2;
    localparam logic [2:0] GS_WIN           = 3'd3;
    localparam logic [2:0] GS_LOSE_ATTEMPTS = 3'd4;
    localparam logic [2:0] GS_LOSE_TIME     = 3'd5;

    logic clk_i;
    logic rst_sync;

    logic btn_sel_pulse_i;
    logic btn_ok_pulse_i;

    logic       rx_letter_valid_i;
    logic [7:0] rx_letter_i;

    logic word_ready_i;
    logic letter_correct_i;
    logic letter_repeated_i;
    logic word_complete_i;

    logic [2:0] attempts_left_i;
    logic       time_expired_i;
    logic       result_hold_done_i;

    logic toggle_difficulty_o;
    logic load_attempts_o;
    logic dec_attempts_o;
    logic inc_wins_o;
    logic capture_letter_o;
    logic capture_word_o;

    logic timer_load_o;
    logic timer_enable_o;

    logic result_timer_start_o;

    logic new_game_o;
    logic letter_valid_o;

    logic [2:0] game_state_o;
    logic correct_pulse_o;
    logic wrong_pulse_o;
    logic game_over_pulse_o;
    logic game_won_o;

    integer errors;


    // ============================================================
    // CLOCK 100 MHz
    // ============================================================
    initial begin
        clk_i = 1'b0;
        forever #5 clk_i = ~clk_i;
    end


    // ============================================================
    // DUT
    // ============================================================
    game_fsm dut (
        .clk_i                 (clk_i),
        .rst_sync              (rst_sync),

        .btn_sel_pulse_i       (btn_sel_pulse_i),
        .btn_ok_pulse_i        (btn_ok_pulse_i),

        .rx_letter_valid_i     (rx_letter_valid_i),
        .rx_letter_i           (rx_letter_i),

        .word_ready_i          (word_ready_i),
        .letter_correct_i      (letter_correct_i),
        .letter_repeated_i     (letter_repeated_i),
        .word_complete_i       (word_complete_i),

        .attempts_left_i       (attempts_left_i),
        .time_expired_i        (time_expired_i),
        .result_hold_done_i    (result_hold_done_i),

        .toggle_difficulty_o   (toggle_difficulty_o),
        .load_attempts_o       (load_attempts_o),
        .dec_attempts_o        (dec_attempts_o),
        .inc_wins_o            (inc_wins_o),
        .capture_letter_o      (capture_letter_o),
        .capture_word_o        (capture_word_o),

        .timer_load_o          (timer_load_o),
        .timer_enable_o        (timer_enable_o),

        .result_timer_start_o  (result_timer_start_o),

        .new_game_o            (new_game_o),
        .letter_valid_o        (letter_valid_o),

        .game_state_o          (game_state_o),
        .correct_pulse_o       (correct_pulse_o),
        .wrong_pulse_o         (wrong_pulse_o),
        .game_over_pulse_o     (game_over_pulse_o),
        .game_won_o            (game_won_o)
    );


    // ============================================================
    // COMPROBACIONES
    // ============================================================
    task automatic check_bit(
        input logic actual,
        input logic expected,
        input string message
    );
        if (actual !== expected) begin
            $error(
                "FAIL: %s | esperado=%b obtenido=%b",
                message,
                expected,
                actual
            );
            errors++;
        end
        else begin
            $display("OK: %s", message);
        end
    endtask


    task automatic check_state(
        input logic [2:0] expected,
        input string message
    );
        if (game_state_o !== expected) begin
            $error(
                "FAIL: %s | estado esperado=%0d obtenido=%0d",
                message,
                expected,
                game_state_o
            );
            errors++;
        end
        else begin
            $display(
                "OK: %s | state=%0d",
                message,
                game_state_o
            );
        end
    endtask


    // ============================================================
    // INICIAR UNA PARTIDA
    // ============================================================
    task automatic start_game;
        begin

            // BTN_OK
            @(negedge clk_i);
            btn_ok_pulse_i = 1'b1;

            @(posedge clk_i);
            #1;

            check_state(
                GS_STARTING,
                "MODE_SELECT -> REQUEST_WORD"
            );

            check_bit(
                new_game_o,
                1'b1,
                "new_game activo durante un ciclo"
            );

            @(negedge clk_i);
            btn_ok_pulse_i = 1'b0;


            // REQUEST_WORD -> WAIT_WORD
            @(posedge clk_i);
            #1;

            check_state(
                GS_STARTING,
                "Espera de Word Engine"
            );


            // Word Engine listo
            @(negedge clk_i);
            word_ready_i = 1'b1;

            #1;

            check_bit(
                capture_word_o,
                1'b1,
                "Captura inicial de palabra"
            );


            // Entrar a INIT_GAME
            @(posedge clk_i);
            #1;

            check_bit(
                load_attempts_o,
                1'b1,
                "Carga de seis intentos"
            );

            check_bit(
                timer_load_o,
                1'b1,
                "Carga del temporizador"
            );


            @(negedge clk_i);
            word_ready_i = 1'b0;


            // INIT_GAME -> WAIT_LETTER
            @(posedge clk_i);
            #1;

            check_state(
                GS_ACTIVE,
                "Juego activo"
            );

            check_bit(
                timer_enable_o,
                1'b1,
                "Temporizador habilitado"
            );

        end
    endtask


    // ============================================================
    // ENVIAR LETRA Y LLEGAR A CHECK_LETTER
    // ============================================================
    task automatic send_letter_to_check(
        input logic [7:0] letter,
        input logic correct,
        input logic repeated,
        input logic complete,
        input logic expired
    );
        begin

            // WAIT_LETTER
            @(negedge clk_i);

            rx_letter_i       = letter;
            rx_letter_valid_i = 1'b1;

            #1;

            check_bit(
                capture_letter_o,
                1'b1,
                "Letra UART aceptada"
            );


            // ISSUE_LETTER
            @(posedge clk_i);
            #1;

            check_bit(
                letter_valid_o,
                1'b1,
                "letter_valid hacia Word Engine"
            );


            // Preparar respuesta del Word Engine
            @(negedge clk_i);

            rx_letter_valid_i = 1'b0;

            letter_correct_i  = correct;
            letter_repeated_i = repeated;
            word_complete_i   = complete;
            time_expired_i    = expired;


            // CHECK_LETTER
            @(posedge clk_i);
            #1;

            check_state(
                GS_ACTIVE,
                "Evaluacion de letra"
            );

        end
    endtask


    // ============================================================
    // RETORNO DESDE ESTADO DE RESULTADO
    // ============================================================
    task automatic finish_result;
        begin

            @(negedge clk_i);
            result_hold_done_i = 1'b1;

            @(posedge clk_i);
            #1;

            result_hold_done_i = 1'b0;

            check_state(
                GS_MODE_SELECT,
                "Resultado finalizado -> MODE_SELECT"
            );

        end
    endtask


    // ============================================================
    // ESTÍMULOS
    // ============================================================
    initial begin

        errors = 0;

        rst_sync          = 1'b1;

        btn_sel_pulse_i   = 1'b0;
        btn_ok_pulse_i    = 1'b0;

        rx_letter_valid_i = 1'b0;
        rx_letter_i       = 8'h00;

        word_ready_i      = 1'b0;
        letter_correct_i  = 1'b0;
        letter_repeated_i = 1'b0;
        word_complete_i   = 1'b0;

        attempts_left_i   = 3'd6;
        time_expired_i    = 1'b0;
        result_hold_done_i = 1'b0;


        // ========================================================
        // RESET
        // ========================================================
        repeat (2) @(posedge clk_i);

        @(negedge clk_i);
        rst_sync = 1'b0;

        @(posedge clk_i);
        #1;

        check_state(
            GS_MODE_SELECT,
            "Reset lleva a MODE_SELECT"
        );


        // ========================================================
        // BTN_SEL
        // ========================================================
        @(negedge clk_i);
        btn_sel_pulse_i = 1'b1;

        #1;

        check_bit(
            toggle_difficulty_o,
            1'b1,
            "BTN_SEL solicita cambio de dificultad"
        );

        @(posedge clk_i);

        @(negedge clk_i);
        btn_sel_pulse_i = 1'b0;


        // ========================================================
        // PARTIDA 1
        // ========================================================
        start_game();


        // --------------------------------------------------------
        // Caracter inválido: '1'
        // --------------------------------------------------------
        @(negedge clk_i);

        rx_letter_i       = 8'h31;
        rx_letter_valid_i = 1'b1;

        #1;

        check_bit(
            capture_letter_o,
            1'b0,
            "Caracter no A-Z ignorado"
        );

        @(posedge clk_i);
        #1;

        check_bit(
            letter_valid_o,
            1'b0,
            "Caracter invalido no enviado"
        );

        @(negedge clk_i);
        rx_letter_valid_i = 1'b0;


        // --------------------------------------------------------
        // Letra correcta parcial
        // --------------------------------------------------------
        send_letter_to_check(
            8'h41,     // A
            1'b1,
            1'b0,
            1'b0,
            1'b0
        );

        check_bit(
            correct_pulse_o,
            1'b1,
            "Letra correcta genera correct_pulse"
        );

        check_bit(
            dec_attempts_o,
            1'b0,
            "Letra correcta no consume intento"
        );

        check_bit(
            capture_word_o,
            1'b1,
            "Actualizacion de revealed_word"
        );

        @(posedge clk_i);
        #1;

        letter_correct_i = 1'b0;

        check_state(
            GS_ACTIVE,
            "Continua despues de letra correcta"
        );


        // --------------------------------------------------------
        // Letra repetida
        // --------------------------------------------------------
        send_letter_to_check(
            8'h41,     // A nuevamente
            1'b0,
            1'b1,
            1'b0,
            1'b0
        );

        check_bit(
            dec_attempts_o,
            1'b0,
            "Letra repetida no consume intento"
        );

        check_bit(
            wrong_pulse_o,
            1'b0,
            "Letra repetida no genera wrong_pulse"
        );

        @(posedge clk_i);
        #1;

        letter_repeated_i = 1'b0;


        // --------------------------------------------------------
        // Letra incorrecta, pero quedan intentos
        // --------------------------------------------------------
        attempts_left_i = 3'd6;

        send_letter_to_check(
            8'h42,     // B
            1'b0,
            1'b0,
            1'b0,
            1'b0
        );

        check_bit(
            wrong_pulse_o,
            1'b1,
            "Letra incorrecta genera wrong_pulse"
        );

        check_bit(
            dec_attempts_o,
            1'b1,
            "Letra incorrecta descuenta intento"
        );

        check_bit(
            game_over_pulse_o,
            1'b0,
            "Partida continua con intentos disponibles"
        );

        @(posedge clk_i);
        #1;


        // ========================================================
        // VICTORIA
        // Además se prueba prioridad sobre time_expired.
        // ========================================================
        send_letter_to_check(
            8'h43,     // C
            1'b1,
            1'b0,
            1'b1,
            1'b1       // tiempo también expira
        );

        check_bit(
            inc_wins_o,
            1'b1,
            "Victoria incrementa contador de ganadas"
        );

        check_bit(
            game_over_pulse_o,
            1'b1,
            "Victoria genera game_over_pulse"
        );

        check_bit(
            result_timer_start_o,
            1'b1,
            "Victoria inicia retencion de resultado"
        );

        @(posedge clk_i);
        #1;

        word_complete_i  = 1'b0;
        letter_correct_i = 1'b0;
        time_expired_i   = 1'b0;

        check_state(
            GS_WIN,
            "word_complete tiene prioridad -> WIN"
        );

        check_bit(
            game_won_o,
            1'b1,
            "game_won activo en RESULT_WIN"
        );

        finish_result();


        // ========================================================
        // PARTIDA 2: DERROTA POR INTENTOS
        // ========================================================
        start_game();

        attempts_left_i = 3'd1;

        send_letter_to_check(
            8'h44,     // D
            1'b0,
            1'b0,
            1'b0,
            1'b1       // tiempo también expira
        );

        check_bit(
            dec_attempts_o,
            1'b1,
            "Ultimo error descuenta intento"
        );

        check_bit(
            game_over_pulse_o,
            1'b1,
            "Ultimo intento genera game_over"
        );

        @(posedge clk_i);
        #1;

        time_expired_i = 1'b0;

        check_state(
            GS_LOSE_ATTEMPTS,
            "Intentos agotados tienen prioridad sobre tiempo"
        );

        finish_result();


        // ========================================================
        // PARTIDA 3: DERROTA POR TIEMPO
        // ========================================================
        start_game();

        attempts_left_i = 3'd6;

        @(negedge clk_i);

        time_expired_i    = 1'b1;
        rx_letter_valid_i = 1'b1;
        rx_letter_i       = 8'h45; // E

        #1;

        check_bit(
            capture_letter_o,
            1'b0,
            "Letra ignorada cuando tiempo ya expiro"
        );

        check_bit(
            game_over_pulse_o,
            1'b1,
            "Tiempo agotado genera game_over"
        );

        check_bit(
            result_timer_start_o,
            1'b1,
            "Tiempo agotado inicia retencion"
        );


        @(posedge clk_i);
        #1;

        time_expired_i    = 1'b0;
        rx_letter_valid_i = 1'b0;

        check_state(
            GS_LOSE_TIME,
            "Derrota por tiempo"
        );

        finish_result();


        // ========================================================
        // RESULTADO FINAL
        // ========================================================
        if (errors == 0) begin

            $display("");
            $display("---------------------------------------");
            $display("PASS: game_fsm");
            $display("MODE_SELECT          = OK");
            $display("Inicio de partida    = OK");
            $display("UART / letras        = OK");
            $display("Victoria              = OK");
            $display("Derrota por intentos = OK");
            $display("Derrota por tiempo   = OK");
            $display("Prioridades FSM       = OK");
            $display("---------------------------------------");

        end
        else begin

            $display("");
            $display("---------------------------------------");
            $display("FAIL: game_fsm");
            $display("Errores detectados = %0d", errors);
            $display("---------------------------------------");

        end

        $finish;

    end

endmodule