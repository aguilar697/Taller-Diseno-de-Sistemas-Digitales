`timescale 1ns/1ps

// Testbench autoverificable
module tb_local_interface;

    localparam real CLK_PERIOD_NS = 10.0;

    // Estados del juego
    localparam logic [2:0] GS_MODE_SELECT   = 3'd0;
    localparam logic [2:0] GS_STARTING      = 3'd1;
    localparam logic [2:0] GS_ACTIVE        = 3'd2;
    localparam logic [2:0] GS_WIN           = 3'd3;
    localparam logic [2:0] GS_LOSE_ATTEMPTS = 3'd4;
    localparam logic [2:0] GS_LOSE_TIME     = 3'd5;

    // Estados del buzzer
    localparam logic [1:0] BUZZ_S_IDLE         = 2'd0;
    localparam logic [1:0] BUZZ_S_TONE_CORRECT = 2'd1;
    localparam logic [1:0] BUZZ_S_TONE_WRONG   = 2'd2;
    localparam logic [1:0] BUZZ_S_TONE_OVER    = 2'd3;

    // Señales del DUT
    logic        clk_i, rst_i;
    logic [2:0]  game_state_i;
    logic        difficulty_i;
    logic [2:0]  attempts_left_i;
    logic [6:0]  time_remaining_i;
    logic [6:0]  wins_i;
    logic        game_won_i;
    logic        correct_pulse_i;
    logic        wrong_pulse_i;
    logic        game_over_pulse_i;
    logic [95:0] revealed_word_i;
    logic [3:0]  word_length_i;

    logic        lcd_ready_o;
    logic        lcd_busy_o;
    logic        screen_done_o;
    logic        buzzer_busy_o;

    logic [7:0]  lcd_db_o;
    logic        lcd_rs_o;
    logic        lcd_rw_o;
    logic        lcd_e_o;

    logic [6:0]  seg_o;
    logic [3:0]  an_o;

    logic [1:0]  led_estado_o;
    logic        buzzer_o;

    int errors = 0;

    // DUT
    local_interface dut (
        .clk_i             (clk_i),
        .rst_i             (rst_i),
        .game_state_i      (game_state_i),
        .difficulty_i      (difficulty_i),
        .attempts_left_i   (attempts_left_i),
        .time_remaining_i  (time_remaining_i),
        .wins_i            (wins_i),
        .game_won_i        (game_won_i),
        .correct_pulse_i   (correct_pulse_i),
        .wrong_pulse_i     (wrong_pulse_i),
        .game_over_pulse_i (game_over_pulse_i),
        .revealed_word_i   (revealed_word_i),
        .word_length_i     (word_length_i),

        .lcd_ready_o       (lcd_ready_o),
        .lcd_busy_o        (lcd_busy_o),
        .screen_done_o     (screen_done_o),
        .buzzer_busy_o     (buzzer_busy_o),

        .lcd_db_o          (lcd_db_o),
        .lcd_rs_o          (lcd_rs_o),
        .lcd_rw_o          (lcd_rw_o),
        .lcd_e_o           (lcd_e_o),

        .seg_o             (seg_o),
        .an_o              (an_o),

        .led_estado_o      (led_estado_o),
        .buzzer_o          (buzzer_o)
    );

    // Reloj
    initial clk_i = 1'b0;

    always #(CLK_PERIOD_NS / 2.0)
        clk_i = ~clk_i;

    // Task de comprobación
    task automatic check(
        input bit condition,
        input string msg
    );
        begin
            if (!condition) begin
                errors = errors + 1;
                $display("[%0t] ERROR: %s", $time, msg);
            end
            else begin
                $display("[%0t] OK: %s", $time, msg);
            end
        end
    endtask

    // Modelo de referencia del 7 segmentos

    function automatic logic [3:0] ref_tens(
        input logic [6:0] value
    );
        logic [6:0] v;
        int idx_loop;

        begin
            v = value;

            for (idx_loop = 0; idx_loop < 13; idx_loop = idx_loop + 1)
                if (v >= 7'd10)
                    v = v - 7'd10;

            ref_tens = (value - v) / 10;
        end
    endfunction


    function automatic logic [3:0] ref_units(
        input logic [6:0] value
    );
        logic [6:0] v;
        int idx_loop;

        begin
            v = value;

            for (idx_loop = 0; idx_loop < 13; idx_loop = idx_loop + 1)
                if (v >= 7'd10)
                    v = v - 7'd10;

            ref_units = v[3:0];
        end
    endfunction


    function automatic logic [6:0] ref_seg(
        input logic [3:0] nibble
    );
        begin
            case (nibble)
                4'd0: ref_seg = 7'b1000000;
                4'd1: ref_seg = 7'b1111001;
                4'd2: ref_seg = 7'b0100100;
                4'd3: ref_seg = 7'b0110000;
                4'd4: ref_seg = 7'b0011001;
                4'd5: ref_seg = 7'b0010010;
                4'd6: ref_seg = 7'b0000010;
                4'd7: ref_seg = 7'b1111000;
                4'd8: ref_seg = 7'b0000000;
                4'd9: ref_seg = 7'b0010000;

                default:
                    ref_seg = 7'b1111111;
            endcase
        end
    endfunction


    // Comprobación de 7 segmentos multiplexados
    task automatic check_sevenseg(
        input logic [6:0] t,
        input logic [6:0] w,
        input string label
    );

        logic [3:0] exp_tt;
        logic [3:0] exp_tu;
        logic [3:0] exp_wt;
        logic [3:0] exp_wu;

        logic [3:0] seen_mask;

        int guard;

        begin

            time_remaining_i = t;
            wins_i            = w;

            exp_tt = ref_tens(t);
            exp_tu = ref_units(t);

            exp_wt = ref_tens(w);
            exp_wu = ref_units(w);

            seen_mask = 4'b0000;
            guard = 0;

            while ((seen_mask != 4'b1111) && (guard < 16)) begin

                @(an_o);
                #1;

                case (an_o)

                    // Unidades de tiempo
                    4'b1110: begin
                        check(
                            seg_o === ref_seg(exp_tu),
                            {label, ": digito unidades de tiempo"}
                        );

                        seen_mask[0] = 1'b1;
                    end

                    // Decenas de tiempo
                    4'b1101: begin
                        check(
                            seg_o === ref_seg(exp_tt),
                            {label, ": digito decenas de tiempo"}
                        );

                        seen_mask[1] = 1'b1;
                    end

                    // Unidades de victorias
                    4'b1011: begin
                        check(
                            seg_o === ref_seg(exp_wu),
                            {label, ": digito unidades de victorias"}
                        );

                        seen_mask[2] = 1'b1;
                    end

                    // Decenas de victorias
                    4'b0111: begin
                        check(
                            seg_o === ref_seg(exp_wt),
                            {label, ": digito decenas de victorias"}
                        );

                        seen_mask[3] = 1'b1;
                    end

                    default:
                        ;

                endcase

                guard = guard + 1;

            end

            check(
                seen_mask == 4'b1111,
                {label, ": se vieron los 4 digitos multiplexados"}
            );

        end
    endtask

    // Captura de datos del LCD

    byte line1_buf[0:15];
    byte line2_buf[0:15];

    int line1_idx = 0;
    int line2_idx = 0;

    bit cap1 = 1'b0;
    bit cap2 = 1'b0;

    bit line1_done = 1'b0;
    bit line2_done = 1'b0;


    always @(posedge lcd_e_o) begin

        #1;

        if (!lcd_rs_o) begin

            // Inicio de línea 1
            if (lcd_db_o == 8'h80) begin

                cap1      = 1'b1;
                cap2      = 1'b0;

                line1_idx = 0;
                line1_done = 1'b0;

            end

            // Inicio de línea 2
            else if (lcd_db_o == 8'hC0) begin

                cap2      = 1'b1;
                cap1      = 1'b0;

                line2_idx = 0;
                line2_done = 1'b0;

            end

        end

        else begin

            // Captura línea 1
            if (cap1 && (line1_idx < 16)) begin

                line1_buf[line1_idx] = lcd_db_o;

                line1_idx = line1_idx + 1;

                if (line1_idx == 16)
                    line1_done = 1'b1;

            end

            // Captura línea 2
            else if (cap2 && (line2_idx < 16)) begin

                line2_buf[line2_idx] = lcd_db_o;

                line2_idx = line2_idx + 1;

                if (line2_idx == 16)
                    line2_done = 1'b1;

            end

        end

    end

    // Caracteres ASCII

    localparam byte CH_SPACE = 8'h20;
    localparam byte CH_COLON = 8'h3A;
    localparam byte CH_EXCL  = 8'h21;
    localparam byte CH_ZERO  = 8'h30;

    // Modelo pantalla selección - línea 1

    function automatic byte g_mode_line1(
        input int idx,
        input bit diff
    );

        begin

            case (idx)

                0:  g_mode_line1 = "M";
                1:  g_mode_line1 = "O";
                2:  g_mode_line1 = "D";
                3:  g_mode_line1 = "O";
                4:  g_mode_line1 = CH_COLON;
                5:  g_mode_line1 = CH_SPACE;

                6:  g_mode_line1 = diff ? "D" : "F";
                7:  g_mode_line1 = diff ? "I" : "A";
                8:  g_mode_line1 = diff ? "F" : "C";
                9:  g_mode_line1 = "I";
                10: g_mode_line1 = diff ? "C" : "L";
                11: g_mode_line1 = diff ? "I" : CH_SPACE;
                12: g_mode_line1 = diff ? "L" : CH_SPACE;

                default:
                    g_mode_line1 = CH_SPACE;

            endcase

        end
    endfunction


    // Modelo pantalla selección - línea 2

    function automatic byte g_mode_line2(
        input int idx
    );

        begin

            case (idx)

                0:  g_mode_line2 = "S";
                1:  g_mode_line2 = "E";
                2:  g_mode_line2 = "L";
                3:  g_mode_line2 = "=";
                4:  g_mode_line2 = "M";
                5:  g_mode_line2 = "O";
                6:  g_mode_line2 = "D";
                7:  g_mode_line2 = "O";
                8:  g_mode_line2 = CH_SPACE;
                9:  g_mode_line2 = "O";
                10: g_mode_line2 = "K";
                11: g_mode_line2 = "=";
                12: g_mode_line2 = "I";
                13: g_mode_line2 = "R";

                default:
                    g_mode_line2 = CH_SPACE;

            endcase

        end
    endfunction


    // Modelo pantalla de intentos

    function automatic byte g_attempts_line(
        input int idx,
        input logic [2:0] att
    );

        begin

            case (idx)

                0:  g_attempts_line = "I";
                1:  g_attempts_line = "N";
                2:  g_attempts_line = "T";
                3:  g_attempts_line = "E";
                4:  g_attempts_line = "N";
                5:  g_attempts_line = "T";
                6:  g_attempts_line = "O";
                7:  g_attempts_line = "S";
                8:  g_attempts_line = CH_COLON;
                9:  g_attempts_line = CH_SPACE;

                10: g_attempts_line = CH_ZERO + byte'(att);

                default:
                    g_attempts_line = CH_SPACE;

            endcase

        end
    endfunction


    // Modelo pantalla de resultado

    function automatic byte g_result_line(
        input int idx,
        input bit won
    );

        begin

            case (idx)

                0: g_result_line = won ? "G" : "P";
                1: g_result_line = won ? "A" : "E";
                2: g_result_line = won ? "N" : "R";
                3: g_result_line = won ? "A" : "D";
                4: g_result_line = won ? "S" : "I";
                5: g_result_line = won ? "T" : "S";
                6: g_result_line = won ? "E" : "T";
                7: g_result_line = won ? CH_EXCL : "E";

                default:
                    g_result_line = CH_SPACE;

            endcase

        end
    endfunction


    // Modelo de palabra revelada

    function automatic byte g_word_char(
        input logic [95:0] w,
        input int idx,
        input int length
    );

        begin

            if (idx < length)
                g_word_char = w[8*idx +: 8];
            else
                g_word_char = CH_SPACE;

        end

    endfunction


    // Esperar que se complete una pantalla LCD

    task automatic wait_screen(
        input int max_cycles,
        input string label
    );

        int n;

        begin

            line1_done = 1'b0;
            line2_done = 1'b0;

            n = 0;

            while ((!line1_done || !line2_done) &&
                   (n < max_cycles)) begin

                @(posedge clk_i);

                n = n + 1;

            end

            check(
                line1_done && line2_done,
                {label, ": las dos lineas del LCD se completaron"}
            );

        end

    endtask


    // Comparación de las dos líneas LCD

    task automatic check_lines(
        input byte exp1[0:15],
        input byte exp2[0:15],
        input string label
    );

        int idx_l;

        bit ok1;
        bit ok2;

        begin

            ok1 = 1'b1;
            ok2 = 1'b1;

            for (idx_l = 0; idx_l < 16; idx_l = idx_l + 1) begin

                if (line1_buf[idx_l] !== exp1[idx_l])
                    ok1 = 1'b0;

                if (line2_buf[idx_l] !== exp2[idx_l])
                    ok2 = 1'b0;

            end

            check(
                ok1,
                {label, ": linea 1 del LCD coincide con el modelo de referencia"}
            );

            check(
                ok2,
                {label, ": linea 2 del LCD coincide con el modelo de referencia"}
            );

        end
    endtask


    // Secuencia principal

    byte exp1[0:15];
    byte exp2[0:15];

    int idx_main;


    initial begin

        // Valores iniciales

        rst_i             = 1'b1;

        game_state_i      = GS_MODE_SELECT;
        difficulty_i      = 1'b0;

        attempts_left_i   = 3'd6;
        time_remaining_i  = 7'd0;
        wins_i            = 7'd0;

        game_won_i        = 1'b0;

        correct_pulse_i   = 1'b0;
        wrong_pulse_i     = 1'b0;
        game_over_pulse_i = 1'b0;

        revealed_word_i   = {12{8'h20}};
        word_length_i     = 4'd0;


        // Reset

        repeat (10)
            @(posedge clk_i);

        rst_i = 1'b0;

        repeat (10)
            @(posedge clk_i);

        #1;

        check(
            ^{seg_o, an_o, led_estado_o, buzzer_o} !== 1'bx,
            "Sin X's en las salidas fisicas despues del reset"
        );


        // LED: cobertura de los 6 estados

        game_state_i = GS_MODE_SELECT;
        @(posedge clk_i);
        #1;

        check(
            led_estado_o === 2'b00,
            "LED en GS_MODE_SELECT"
        );


        game_state_i = GS_STARTING;
        @(posedge clk_i);
        #1;

        check(
            led_estado_o === 2'b01,
            "LED en GS_STARTING"
        );


        game_state_i = GS_ACTIVE;
        @(posedge clk_i);
        #1;

        check(
            led_estado_o === 2'b01,
            "LED en GS_ACTIVE"
        );


        game_state_i = GS_WIN;
        @(posedge clk_i);
        #1;

        check(
            led_estado_o === 2'b10,
            "LED en GS_WIN"
        );


        game_state_i = GS_LOSE_ATTEMPTS;
        @(posedge clk_i);
        #1;

        check(
            led_estado_o === 2'b10,
            "LED en GS_LOSE_ATTEMPTS"
        );


        game_state_i = GS_LOSE_TIME;
        @(posedge clk_i);
        #1;

        check(
            led_estado_o === 2'b10,
            "LED en GS_LOSE_TIME"
        );


        game_state_i = GS_MODE_SELECT;


        // 7 segmentos

        check_sevenseg(
            7'd0,
            7'd0,
            "7seg valores en 0"
        );


        check_sevenseg(
            7'd9,
            7'd10,
            "7seg borde 9/10"
        );


        check_sevenseg(
            7'd42,
            7'd7,
            "7seg valores normales"
        );


        check_sevenseg(
            7'd99,
            7'd99,
            "7seg valor maximo 99"
        );


        // BUZZER
        // Buzzer: tono de acierto

        correct_pulse_i = 1'b1;

        @(posedge clk_i);
        #1;

        correct_pulse_i = 1'b0;

        check(
            dut.u_buzzer_control.state == BUZZ_S_TONE_CORRECT,
            "Buzzer entra a S_TONE_CORRECT tras correct_pulse_i"
        );

        check(
            buzzer_busy_o === 1'b1,
            "buzzer_busy_o en alto durante el tono"
        );

        // Esperar hasta que termine.
        while (buzzer_busy_o === 1'b1)
            @(posedge clk_i);

        #1;

        check(
            buzzer_busy_o === 1'b0,
            "buzzer_busy_o vuelve a bajo al terminar el tono de acierto"
        );


        // Buzzer: prioridad entre correct y wrong

        correct_pulse_i = 1'b1;
        wrong_pulse_i   = 1'b1;

        @(posedge clk_i);
        #1;

        correct_pulse_i = 1'b0;
        wrong_pulse_i   = 1'b0;

        check(
            dut.u_buzzer_control.state == BUZZ_S_TONE_WRONG,
            "Prioridad: error le gana a acierto si llegan juntos"
        );


        // Reset para cancelar el tono anterior

        rst_i = 1'b1;

        @(posedge clk_i);
        #1;

        rst_i = 1'b0;

        @(posedge clk_i);
        #1;


        // Buzzer: prioridad entre wrong y game_over

        wrong_pulse_i     = 1'b1;
        game_over_pulse_i = 1'b1;

        @(posedge clk_i);
        #1;

        wrong_pulse_i     = 1'b0;
        game_over_pulse_i = 1'b0;

        check(
            dut.u_buzzer_control.state == BUZZ_S_TONE_OVER,
            "Prioridad: fin de partida le gana a error si llegan juntos"
        );


        // Reset final del buzzer

        rst_i = 1'b1;

        @(posedge clk_i);
        #1;

        rst_i = 1'b0;

        repeat (10)
            @(posedge clk_i);


        // LCD

        // Esperar inicialización real del HD44780.
        while (lcd_ready_o !== 1'b1)
            @(posedge clk_i);

        #1;

        check(
            lcd_ready_o === 1'b1,
            "lcd_ready_o se activa tras la inicializacion"
        );


        // Pantalla de selección - FACIL

        difficulty_i = 1'b0;
        game_state_i = GS_MODE_SELECT;

        wait_screen(
            300_000,
            "Seleccion FACIL"
        );


        for (idx_main = 0; idx_main < 16; idx_main = idx_main + 1) begin

            exp1[idx_main] =
                g_mode_line1(
                    idx_main,
                    1'b0
                );

            exp2[idx_main] =
                g_mode_line2(
                    idx_main
                );

        end


        check_lines(
            exp1,
            exp2,
            "Seleccion FACIL"
        );


        // Pantalla de selección - DIFICIL

        difficulty_i = 1'b1;

        wait_screen(
            300_000,
            "Seleccion DIFICIL"
        );


        for (idx_main = 0; idx_main < 16; idx_main = idx_main + 1) begin

            exp1[idx_main] =
                g_mode_line1(
                    idx_main,
                    1'b1
                );

            exp2[idx_main] =
                g_mode_line2(
                    idx_main
                );

        end


        check_lines(
            exp1,
            exp2,
            "Seleccion DIFICIL"
        );


        // Pantalla de partida activa

        game_state_i    = GS_ACTIVE;

        attempts_left_i = 3'd4;

        word_length_i   = 4'd6;

        revealed_word_i = {12{8'h20}};


        for (idx_main = 0; idx_main < 6; idx_main = idx_main + 1) begin

            revealed_word_i[8*idx_main +: 8] =
                (idx_main == 2) ? "T" : "_";

        end


        wait_screen(
            300_000,
            "Partida activa"
        );


        for (idx_main = 0; idx_main < 16; idx_main = idx_main + 1) begin

            exp1[idx_main] =
                g_word_char(
                    revealed_word_i,
                    idx_main,
                    6
                );

            exp2[idx_main] =
                g_attempts_line(
                    idx_main,
                    3'd4
                );

        end


        check_lines(
            exp1,
            exp2,
            "Partida activa"
        );


        // Pantalla de resultado - VICTORIA

        game_state_i = GS_WIN;

        game_won_i   = 1'b1;

        word_length_i = 4'd4;

        revealed_word_i = {12{8'h20}};

        revealed_word_i[7:0]   = "C";
        revealed_word_i[15:8]  = "A";
        revealed_word_i[23:16] = "S";
        revealed_word_i[31:24] = "A";


        wait_screen(
            300_000,
            "Resultado victoria"
        );


        for (idx_main = 0; idx_main < 16; idx_main = idx_main + 1) begin

            exp1[idx_main] =
                g_result_line(
                    idx_main,
                    1'b1
                );

            exp2[idx_main] =
                g_word_char(
                    revealed_word_i,
                    idx_main,
                    4
                );

        end


        check_lines(
            exp1,
            exp2,
            "Resultado victoria"
        );


        // Pantalla de resultado - DERROTA

        game_state_i = GS_LOSE_ATTEMPTS;

        game_won_i   = 1'b0;


        wait_screen(
            300_000,
            "Resultado derrota"
        );


        for (idx_main = 0; idx_main < 16; idx_main = idx_main + 1) begin

            exp1[idx_main] =
                g_result_line(
                    idx_main,
                    1'b0
                );

            exp2[idx_main] =
                g_word_char(
                    revealed_word_i,
                    idx_main,
                    4
                );

        end


        check_lines(
            exp1,
            exp2,
            "Resultado derrota"
        );


        // Resultado final

        if (errors == 0) begin

            $display("");
            $display("==============================================");
            $display(" TESTBENCH PASO: 0 errores");
            $display("==============================================");
            $display("");

        end
        else begin

            $display("");
            $display("==============================================");
            $display(
                " TESTBENCH FALLO: %0d error(es)",
                errors
            );
            $display("==============================================");
            $display("");

        end


        $finish;

    end


    // Watchdog global

    initial begin

        #400_000_000;

        $display(
            "[%0t] ERROR: watchdog global -- la simulacion no termino a tiempo",
            $time
        );

        $finish;

    end

endmodule
