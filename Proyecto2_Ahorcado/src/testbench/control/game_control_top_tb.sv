`timescale 1ns/1ps

module game_control_top_tb;

    localparam int unsigned TB_CLK_HZ              = 8;
    localparam int unsigned TB_EASY_SECONDS        = 20;
    localparam int unsigned TB_HARD_SECONDS        = 15;
    localparam int unsigned TB_RESULT_HOLD_SECONDS = 3;
    localparam int unsigned TB_DEBOUNCE_CYCLES     = 3;

    localparam logic [2:0] GS_MODE_SELECT   = 3'd0;
    localparam logic [2:0] GS_STARTING      = 3'd1;
    localparam logic [2:0] GS_ACTIVE        = 3'd2;
    localparam logic [2:0] GS_WIN           = 3'd3;
    localparam logic [2:0] GS_LOSE_ATTEMPTS = 3'd4;
    localparam logic [2:0] GS_LOSE_TIME     = 3'd5;

    logic clk_i;

    logic btn_sel_i;
    logic btn_ok_i;
    logic btn_rst_i;

    logic       rx_letter_valid_i;
    logic [7:0] rx_letter_i;

    logic        word_ready_i;
    logic [3:0]  word_length_i;
    logic [95:0] revealed_word_i;
    logic        letter_correct_i;
    logic        letter_repeated_i;
    logic        word_complete_i;

    logic        new_game_o;
    logic        difficulty_o;
    logic        letter_valid_o;
    logic [7:0]  letter_ascii_o;

    logic [2:0]  game_state_o;
    logic [95:0] revealed_word_o;
    logic [3:0]  word_length_o;
    logic [2:0]  attempts_left_o;
    logic [6:0]  time_remaining_o;
    logic [6:0]  wins_o;

    logic correct_pulse_o;
    logic wrong_pulse_o;
    logic game_over_pulse_o;
    logic game_won_o;

    integer errors;
    integer new_game_count;


    // ============================================================
    // CLOCK 100 MHz
    // ============================================================
    initial begin
        clk_i = 1'b0;
        forever #5 clk_i = ~clk_i;
    end


    // ============================================================
    // CONTADOR DE PULSOS new_game
    // ============================================================
    always @(posedge clk_i) begin
        if (new_game_o)
            new_game_count = new_game_count + 1;
    end


    // ============================================================
    // DUT
    // ============================================================
    game_control_top #(
        .CLK_HZ              (TB_CLK_HZ),
        .EASY_SECONDS        (TB_EASY_SECONDS),
        .HARD_SECONDS        (TB_HARD_SECONDS),
        .RESULT_HOLD_SECONDS (TB_RESULT_HOLD_SECONDS),
        .DEBOUNCE_CYCLES     (TB_DEBOUNCE_CYCLES)
    ) dut (
        .clk_i              (clk_i),

        .btn_sel_i          (btn_sel_i),
        .btn_ok_i           (btn_ok_i),
        .btn_rst_i          (btn_rst_i),

        .rx_letter_valid_i  (rx_letter_valid_i),
        .rx_letter_i        (rx_letter_i),

        .word_ready_i       (word_ready_i),
        .word_length_i      (word_length_i),
        .revealed_word_i    (revealed_word_i),
        .letter_correct_i   (letter_correct_i),
        .letter_repeated_i  (letter_repeated_i),
        .word_complete_i    (word_complete_i),

        .new_game_o         (new_game_o),
        .difficulty_o       (difficulty_o),
        .letter_valid_o     (letter_valid_o),
        .letter_ascii_o     (letter_ascii_o),

        .game_state_o       (game_state_o),
        .revealed_word_o    (revealed_word_o),
        .word_length_o      (word_length_o),
        .attempts_left_o    (attempts_left_o),
        .time_remaining_o   (time_remaining_o),
        .wins_o             (wins_o),

        .correct_pulse_o    (correct_pulse_o),
        .wrong_pulse_o      (wrong_pulse_o),
        .game_over_pulse_o  (game_over_pulse_o),
        .game_won_o         (game_won_o)
    );


    // ============================================================
    // CHECK GENÉRICO
    // ============================================================
    task automatic check_value(
        input logic [31:0] actual,
        input logic [31:0] expected,
        input string message
    );
        begin
            if (actual !== expected) begin
                $error(
                    "FAIL: %s | esperado=%0d obtenido=%0d",
                    message,
                    expected,
                    actual
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "OK: %s | valor=%0d",
                    message,
                    actual
                );
            end
        end
    endtask


    // ============================================================
    // PULSAR BTN_SEL
    // ============================================================
    task automatic press_sel;
        begin
            @(negedge clk_i);
            btn_sel_i = 1'b1;

            repeat (8)
                @(posedge clk_i);

            @(negedge clk_i);
            btn_sel_i = 1'b0;

            repeat (8)
                @(posedge clk_i);

            #1;
        end
    endtask


    // ============================================================
    // PULSAR BTN_OK
    // ============================================================
    task automatic press_ok;
        integer before_count;
        begin
            before_count = new_game_count;

            @(negedge clk_i);
            btn_ok_i = 1'b1;

            repeat (8)
                @(posedge clk_i);

            @(negedge clk_i);
            btn_ok_i = 1'b0;

            repeat (8)
                @(posedge clk_i);

            #1;

            if (new_game_count != before_count + 1) begin
                $error(
                    "FAIL: BTN_OK no genero exactamente un new_game"
                );
                errors = errors + 1;
            end
            else begin
                $display(
                    "OK: BTN_OK genero un unico new_game"
                );
            end
        end
    endtask


    // ============================================================
    // INICIAR PARTIDA
    // ============================================================
    task automatic start_game;
        begin

            press_ok();

            word_length_i   = 4'd6;
            revealed_word_i =
                96'h5F5F5F5F5F5F000000000000;

            @(negedge clk_i);
            word_ready_i = 1'b1;

            repeat (2)
                @(posedge clk_i);

            #1;

            word_ready_i = 1'b0;

            check_value(
                game_state_o,
                GS_ACTIVE,
                "Partida entra en ACTIVE"
            );

            check_value(
                attempts_left_o,
                3'd6,
                "Carga de seis intentos"
            );

            check_value(
                word_length_o,
                4'd6,
                "Longitud de palabra capturada"
            );

            check_value(
                time_remaining_o,
                TB_HARD_SECONDS,
                "Tiempo DIFICIL cargado"
            );

        end
    endtask


    // ============================================================
    // PRESENTAR LETRA AL CONTROL
    // ============================================================
    task automatic present_letter(
        input logic [7:0] letter
    );
        begin

            @(negedge clk_i);

            rx_letter_i       = letter;
            rx_letter_valid_i = 1'b1;

            @(posedge clk_i);
            #1;

            check_value(
                letter_valid_o,
                1'b1,
                "letter_valid generado"
            );

            check_value(
                letter_ascii_o,
                letter,
                "ASCII mantenido hacia Word Engine"
            );

            @(negedge clk_i);

            rx_letter_valid_i = 1'b0;

        end
    endtask


    // ============================================================
    // RESPUESTA DEL WORD ENGINE
    // ============================================================
    task automatic word_response(
        input logic correct,
        input logic repeated,
        input logic complete,
        input logic [95:0] next_revealed
    );
        begin

            letter_correct_i  = correct;
            letter_repeated_i = repeated;
            word_complete_i   = complete;
            revealed_word_i   = next_revealed;

            // ISSUE_LETTER -> CHECK_LETTER
            @(posedge clk_i);
            #1;

        end
    endtask


    // ============================================================
    // TERMINAR CICLO CHECK_LETTER
    // ============================================================
    task automatic finish_letter;
        begin

            @(posedge clk_i);
            #1;

            @(negedge clk_i);

            letter_correct_i  = 1'b0;
            letter_repeated_i = 1'b0;
            word_complete_i   = 1'b0;

        end
    endtask


    // ============================================================
    // ESPERAR RETORNO AUTOMÁTICO A MODE_SELECT
    // ============================================================
    task automatic wait_result_return;
        begin

            repeat (
                TB_CLK_HZ * TB_RESULT_HOLD_SECONDS + 6
            )
                @(posedge clk_i);

            #1;

            check_value(
                game_state_o,
                GS_MODE_SELECT,
                "Regreso automatico a MODE_SELECT"
            );

        end
    endtask


    // ============================================================
    // ESTÍMULOS
    // ============================================================
    initial begin

        errors         = 0;
        new_game_count = 0;

        btn_sel_i = 1'b0;
        btn_ok_i  = 1'b0;
        btn_rst_i = 1'b1;

        rx_letter_valid_i = 1'b0;
        rx_letter_i       = 8'h00;

        word_ready_i      = 1'b0;
        word_length_i     = 4'd0;
        revealed_word_i   = 96'd0;

        letter_correct_i  = 1'b0;
        letter_repeated_i = 1'b0;
        word_complete_i   = 1'b0;


        // ========================================================
        // RESET GLOBAL
        // ========================================================
        repeat (3)
            @(posedge clk_i);

        @(negedge clk_i);
        btn_rst_i = 1'b0;

        repeat (4)
            @(posedge clk_i);

        #1;

        check_value(
            game_state_o,
            GS_MODE_SELECT,
            "Reset -> MODE_SELECT"
        );

        check_value(
            difficulty_o,
            1'b0,
            "Dificultad inicial FACIL"
        );

        check_value(
            wins_o,
            7'd0,
            "Victorias iniciales"
        );


        // ========================================================
        // SELECCIONAR DIFICIL
        // ========================================================
        press_sel();

        check_value(
            difficulty_o,
            1'b1,
            "BTN_SEL selecciona DIFICIL"
        );


        // ========================================================
        // PARTIDA 1: VICTORIA
        // ========================================================
        $display("");
        $display("=== PARTIDA 1: VICTORIA ===");

        start_game();


        // --------------------------------------------------------
        // Letra correcta parcial: A
        // --------------------------------------------------------
        present_letter(8'h41);

        word_response(
            1'b1,
            1'b0,
            1'b0,
            96'h415F5F5F5F5F000000000000
        );

        check_value(
            correct_pulse_o,
            1'b1,
            "Letra correcta genera correct_pulse"
        );

        check_value(
            wrong_pulse_o,
            1'b0,
            "Letra correcta no genera wrong_pulse"
        );

        finish_letter();

        check_value(
            attempts_left_o,
            3'd6,
            "Letra correcta conserva intentos"
        );


        // --------------------------------------------------------
        // Letra repetida: A
        // --------------------------------------------------------
        present_letter(8'h41);

        word_response(
            1'b1,
            1'b1,
            1'b0,
            96'h415F5F5F5F5F000000000000
        );

        check_value(
            correct_pulse_o,
            1'b0,
            "Letra repetida no genera correct_pulse"
        );

        check_value(
            wrong_pulse_o,
            1'b0,
            "Letra repetida no genera wrong_pulse"
        );

        finish_letter();

        check_value(
            attempts_left_o,
            3'd6,
            "Letra repetida no consume intento"
        );


        // --------------------------------------------------------
        // Letra incorrecta: B
        // --------------------------------------------------------
        present_letter(8'h42);

        word_response(
            1'b0,
            1'b0,
            1'b0,
            96'h415F5F5F5F5F000000000000
        );

        check_value(
            wrong_pulse_o,
            1'b1,
            "Letra incorrecta genera wrong_pulse"
        );

        finish_letter();

        check_value(
            attempts_left_o,
            3'd5,
            "Letra incorrecta descuenta intento"
        );


        // --------------------------------------------------------
        // Letra final correcta: C
        // --------------------------------------------------------
        present_letter(8'h43);

        word_response(
            1'b1,
            1'b0,
            1'b1,
            96'h41484F524341000000000000
        );

        check_value(
            game_over_pulse_o,
            1'b1,
            "Victoria genera game_over_pulse"
        );

        finish_letter();

        check_value(
            game_state_o,
            GS_WIN,
            "Entrada a estado WIN"
        );

        check_value(
            game_won_o,
            1'b1,
            "game_won activo"
        );

        check_value(
            wins_o,
            7'd1,
            "Contador de victorias incrementado"
        );

        wait_result_return();


        // ========================================================
        // PARTIDA 2: DERROTA POR INTENTOS
        // ========================================================
        $display("");
        $display("=== PARTIDA 2: DERROTA POR INTENTOS ===");

        start_game();

        repeat (6) begin

            present_letter(8'h5A);

            word_response(
                1'b0,
                1'b0,
                1'b0,
                96'h5F5F5F5F5F5F000000000000
            );

            check_value(
                wrong_pulse_o,
                1'b1,
                "Error consume intento"
            );

            finish_letter();

        end

        check_value(
            attempts_left_o,
            3'd0,
            "Intentos agotados"
        );

        check_value(
            game_state_o,
            GS_LOSE_ATTEMPTS,
            "Derrota por intentos"
        );

        check_value(
            wins_o,
            7'd1,
            "Derrota no incrementa victorias"
        );

        wait_result_return();


        // ========================================================
        // PARTIDA 3: DERROTA POR TIEMPO
        // ========================================================
        $display("");
        $display("=== PARTIDA 3: DERROTA POR TIEMPO ===");

        start_game();

        repeat (
            TB_CLK_HZ * TB_HARD_SECONDS + 4
        )
            @(posedge clk_i);

        #1;

        check_value(
            time_remaining_o,
            7'd0,
            "Temporizador llega a cero"
        );

        check_value(
            game_state_o,
            GS_LOSE_TIME,
            "Derrota por tiempo"
        );

        check_value(
            game_won_o,
            1'b0,
            "Derrota no activa game_won"
        );

        wait_result_return();


        // ========================================================
        // RESULTADO FINAL
        // ========================================================
        if (errors == 0) begin

            $display("");
            $display("=======================================");
            $display("PASS: game_control_top");
            $display("Reset sincronizado          = OK");
            $display("BTN_SEL / dificultad        = OK");
            $display("BTN_OK / new_game           = OK");
            $display("Word Engine                 = OK");
            $display("UART / letras               = OK");
            $display("Intentos                    = OK");
            $display("Temporizador                = OK");
            $display("Victoria                    = OK");
            $display("Derrota por intentos        = OK");
            $display("Derrota por tiempo          = OK");
            $display("Retencion de resultado      = OK");
            $display("Contador de victorias       = OK");
            $display("=======================================");

        end
        else begin

            $display("");
            $display("=======================================");
            $display("FAIL: game_control_top");
            $display("Errores detectados = %0d", errors);
            $display("=======================================");

        end

        $finish;

    end

endmodule