`timescale 1ns/1ps

module game_datapath_tb;

    logic        clk_i;
    logic        rst_sync;

    logic        toggle_difficulty_i;
    logic        load_attempts_i;
    logic        dec_attempts_i;
    logic        inc_wins_i;
    logic        capture_letter_i;
    logic        capture_word_i;

    logic [7:0]  rx_letter_i;
    logic [3:0]  word_length_i;
    logic [95:0] revealed_word_i;

    logic        difficulty_o;
    logic [2:0]  attempts_left_o;
    logic [6:0]  wins_o;
    logic [7:0]  letter_ascii_o;
    logic [3:0]  word_length_o;
    logic [95:0] revealed_word_o;

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
    game_datapath dut (
        .clk_i                 (clk_i),
        .rst_sync              (rst_sync),

        .toggle_difficulty_i   (toggle_difficulty_i),
        .load_attempts_i       (load_attempts_i),
        .dec_attempts_i        (dec_attempts_i),
        .inc_wins_i            (inc_wins_i),
        .capture_letter_i      (capture_letter_i),
        .capture_word_i        (capture_word_i),

        .rx_letter_i           (rx_letter_i),
        .word_length_i         (word_length_i),
        .revealed_word_i       (revealed_word_i),

        .difficulty_o          (difficulty_o),
        .attempts_left_o       (attempts_left_o),
        .wins_o                (wins_o),
        .letter_ascii_o        (letter_ascii_o),
        .word_length_o         (word_length_o),
        .revealed_word_o       (revealed_word_o)
    );


    // ============================================================
    // COMPROBACIONES
    // ============================================================
    task automatic check_difficulty(
        input logic expected,
        input string message
    );
        if (difficulty_o !== expected) begin
            $error(
                "FAIL: %s | esperado=%b obtenido=%b",
                message,
                expected,
                difficulty_o
            );
            errors = errors + 1;
        end
        else begin
            $display(
                "OK: %s | difficulty=%b",
                message,
                difficulty_o
            );
        end
    endtask


    task automatic check_attempts(
        input logic [2:0] expected,
        input string message
    );
        if (attempts_left_o !== expected) begin
            $error(
                "FAIL: %s | esperado=%0d obtenido=%0d",
                message,
                expected,
                attempts_left_o
            );
            errors = errors + 1;
        end
        else begin
            $display(
                "OK: %s | attempts_left=%0d",
                message,
                attempts_left_o
            );
        end
    endtask


    task automatic check_wins(
        input logic [6:0] expected,
        input string message
    );
        if (wins_o !== expected) begin
            $error(
                "FAIL: %s | esperado=%0d obtenido=%0d",
                message,
                expected,
                wins_o
            );
            errors = errors + 1;
        end
        else begin
            $display(
                "OK: %s | wins=%0d",
                message,
                wins_o
            );
        end
    endtask


    // ============================================================
    // ESTÍMULOS
    // ============================================================
    initial begin

        errors = 0;

        rst_sync            = 1'b1;

        toggle_difficulty_i = 1'b0;
        load_attempts_i     = 1'b0;
        dec_attempts_i      = 1'b0;
        inc_wins_i          = 1'b0;
        capture_letter_i    = 1'b0;
        capture_word_i      = 1'b0;

        rx_letter_i         = 8'h00;
        word_length_i       = 4'd0;
        revealed_word_i     = 96'd0;


        // ========================================================
        // RESET
        // ========================================================
        repeat (2) @(posedge clk_i);

        @(negedge clk_i);
        rst_sync = 1'b0;

        @(posedge clk_i);
        #1;

        check_difficulty(
            1'b0,
            "Modo inicial FACIL"
        );

        check_attempts(
            3'd0,
            "Intentos despues del reset"
        );

        check_wins(
            7'd0,
            "Victorias despues del reset"
        );


        // ========================================================
        // PRUEBA 1: SELECCION DE DIFICULTAD
        // ========================================================
        @(negedge clk_i);
        toggle_difficulty_i = 1'b1;

        @(negedge clk_i);
        toggle_difficulty_i = 1'b0;

        #1;

        check_difficulty(
            1'b1,
            "Cambio FACIL -> DIFICIL"
        );


        @(negedge clk_i);
        toggle_difficulty_i = 1'b1;

        @(negedge clk_i);
        toggle_difficulty_i = 1'b0;

        #1;

        check_difficulty(
            1'b0,
            "Cambio DIFICIL -> FACIL"
        );


        // ========================================================
        // PRUEBA 2: CARGA DE INTENTOS
        // ========================================================
        @(negedge clk_i);
        load_attempts_i = 1'b1;

        @(negedge clk_i);
        load_attempts_i = 1'b0;

        #1;

        check_attempts(
            3'd6,
            "Carga inicial de 6 intentos"
        );


        // ========================================================
        // PRUEBA 3: DESCONTAR INTENTO
        // ========================================================
        @(negedge clk_i);
        dec_attempts_i = 1'b1;

        @(negedge clk_i);
        dec_attempts_i = 1'b0;

        #1;

        check_attempts(
            3'd5,
            "Descuento de un intento"
        );


        // ========================================================
        // PRUEBA 4: CAPTURA DE LETRA
        // ========================================================
        @(negedge clk_i);

        rx_letter_i      = 8'h4B;   // 'K'
        capture_letter_i = 1'b1;

        @(negedge clk_i);

        capture_letter_i = 1'b0;
        rx_letter_i      = 8'h5A;   // 'Z'

        #1;

        if (letter_ascii_o !== 8'h4B) begin
            $error(
                "FAIL: Letra capturada | esperado=K obtenido=%h",
                letter_ascii_o
            );
            errors = errors + 1;
        end
        else begin
            $display(
                "OK: Letra K capturada y mantenida estable"
            );
        end


        // ========================================================
        // PRUEBA 5: CAPTURA DE INFORMACION DE PALABRA
        // ========================================================
        @(negedge clk_i);

        word_length_i   = 4'd6;
        revealed_word_i = 96'h5F5F5F5F5F5F000000000000;
        capture_word_i  = 1'b1;

        @(negedge clk_i);

        capture_word_i = 1'b0;

        #1;

        if (
            word_length_o !== 4'd6 ||
            revealed_word_o !== 96'h5F5F5F5F5F5F000000000000
        ) begin
            $error("FAIL: Captura inicial de palabra");
            errors = errors + 1;
        end
        else begin
            $display(
                "OK: Longitud y palabra revelada capturadas"
            );
        end


        // Actualizar palabra revelada.
        @(negedge clk_i);

        revealed_word_i = 96'h415F5F5F5F5F000000000000;
        capture_word_i  = 1'b1;

        @(negedge clk_i);

        capture_word_i = 1'b0;

        #1;

        if (
            revealed_word_o !==
            96'h415F5F5F5F5F000000000000
        ) begin
            $error("FAIL: Actualizacion de revealed_word");
            errors = errors + 1;
        end
        else begin
            $display(
                "OK: revealed_word actualizado correctamente"
            );
        end


        // ========================================================
        // PRUEBA 6: INTENTOS HASTA CERO
        // ========================================================
        repeat (5) begin

            @(negedge clk_i);
            dec_attempts_i = 1'b1;

            @(negedge clk_i);
            dec_attempts_i = 1'b0;

        end

        #1;

        check_attempts(
            3'd0,
            "Intentos agotados"
        );


        // Intentar decrementar una vez más.
        @(negedge clk_i);
        dec_attempts_i = 1'b1;

        @(negedge clk_i);
        dec_attempts_i = 1'b0;

        #1;

        check_attempts(
            3'd0,
            "Proteccion contra underflow"
        );


        // ========================================================
        // PRUEBA 7: CONTADOR DE VICTORIAS
        // ========================================================

        @(negedge clk_i);
        inc_wins_i = 1'b1;

        @(negedge clk_i);
        inc_wins_i = 1'b0;

        #1;

        check_wins(
            7'd1,
            "Primera victoria"
        );


        // Comprobar que iniciar otra partida NO borra victorias.
        @(negedge clk_i);
        load_attempts_i = 1'b1;

        @(negedge clk_i);
        load_attempts_i = 1'b0;

        #1;

        check_wins(
            7'd1,
            "Victorias conservadas entre partidas"
        );


        // Llegar hasta 99 victorias.
        repeat (98) begin

            @(negedge clk_i);
            inc_wins_i = 1'b1;

            @(negedge clk_i);
            inc_wins_i = 1'b0;

        end

        #1;

        check_wins(
            7'd99,
            "Contador alcanza 99 victorias"
        );


        // Intentar superar 99.
        repeat (3) begin

            @(negedge clk_i);
            inc_wins_i = 1'b1;

            @(negedge clk_i);
            inc_wins_i = 1'b0;

        end

        #1;

        check_wins(
            7'd99,
            "Saturacion del contador en 99"
        );


        // ========================================================
        // RESULTADO FINAL
        // ========================================================
        if (errors == 0) begin

            $display("");
            $display("---------------------------------------");
            $display("PASS: game_datapath");
            $display("Dificultad          = OK");
            $display("Intentos             = OK");
            $display("Captura de letra     = OK");
            $display("Palabra revelada     = OK");
            $display("Victorias hasta 99   = OK");
            $display("---------------------------------------");

        end
        else begin

            $display("");
            $display("---------------------------------------");
            $display("FAIL: game_datapath");
            $display("Errores detectados = %0d", errors);
            $display("---------------------------------------");

        end

        $finish;

    end

endmodule