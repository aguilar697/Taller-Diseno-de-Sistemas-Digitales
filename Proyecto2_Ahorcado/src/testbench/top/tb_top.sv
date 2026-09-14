`timescale 1ns/1ps
module tb_top;

 localparam real CLK_PERIOD_NS   = 10.0;   
    localparam int  SIM_CLK_HZ      = 1_000_000;
    localparam int  SIM_DEBOUNCE    = 5;      // ciclos de debounce en sim
    localparam int  BIT_CYCLES      = 864;    // 1 bit UART @115200 baud / 100MHz
    localparam int  RESULT_HOLD_TIMEOUT_CYCLES = SIM_CLK_HZ * 3 * 3; // 3x margen sobre RESULT_HOLD_SECONDS=3

    localparam logic [2:0] GS_MODE_SELECT   = 3'd0;
    localparam logic [2:0] GS_STARTING      = 3'd1;
    localparam logic [2:0] GS_ACTIVE        = 3'd2;
    localparam logic [2:0] GS_WIN           = 3'd3;
    localparam logic [2:0] GS_LOSE_ATTEMPTS = 3'd4;
    localparam logic [2:0] GS_LOSE_TIME     = 3'd5;

    logic       clk_i;
    logic       btn_rst_i;
    logic       btn_sel_i;
    logic       btn_ok_i;
    logic       uart_rx_i;
    logic       uart_tx_o;

    logic [7:0] lcd_db_o;
    logic       lcd_rs_o;
    logic       lcd_rw_o;
    logic       lcd_e_o;

    logic [6:0] seg_o;
    logic [3:0] an_o;
    logic [1:0] led_estado_o;
    logic       buzzer_o;

    int errors = 0;

    top #(
        .CLK_HZ          (SIM_CLK_HZ),
        .DEBOUNCE_CYCLES (SIM_DEBOUNCE)
    ) dut (
        .clk_i         (clk_i),
        .btn_rst_i     (btn_rst_i),
        .btn_sel_i     (btn_sel_i),
        .btn_ok_i      (btn_ok_i),
        .uart_rx_i     (uart_rx_i),
        .uart_tx_o     (uart_tx_o),
        .lcd_db_o      (lcd_db_o),
        .lcd_rs_o      (lcd_rs_o),
        .lcd_rw_o      (lcd_rw_o),
        .lcd_e_o       (lcd_e_o),
        .seg_o         (seg_o),
        .an_o          (an_o),
        .led_estado_o  (led_estado_o),
        .buzzer_o      (buzzer_o)
    );

    initial clk_i = 1'b0;
    always #(CLK_PERIOD_NS/2.0) clk_i = ~clk_i;

   task automatic check(input bit condition, input string msg);
        if (!condition) begin
            errors = errors + 1;
            $display("[%0t] ERROR: %s", $time, msg);
        end else begin
            $display("[%0t] OK: %s", $time, msg);
        end
    endtask

    task automatic press_button(ref logic btn);
        begin
            btn = 1'b1;
            repeat (SIM_DEBOUNCE + 10) @(posedge clk_i);
            btn = 1'b0;
            repeat (SIM_DEBOUNCE + 10) @(posedge clk_i);
        end
    endtask

    task automatic uart_send_byte(input logic [7:0] data);
        integer i;
        begin
            uart_rx_i = 1'b0;                    // start bit
            repeat (BIT_CYCLES) @(posedge clk_i);
            for (i = 0; i < 8; i = i + 1) begin
                uart_rx_i = data[i];
                repeat (BIT_CYCLES) @(posedge clk_i);
            end
            uart_rx_i = 1'b1;                    // stop bit
            repeat (BIT_CYCLES) @(posedge clk_i);
        end
    endtask

   logic rx_letter_valid_latch = 1'b0;
    always @(posedge dut.rx_letter_valid_s) rx_letter_valid_latch = 1'b1;

    localparam int LETTER_GAP_CYCLES = 300_000;

    task automatic send_letter(input logic [7:0] letter);
        int n;
        begin
            rx_letter_valid_latch = 1'b0;
            uart_send_byte(letter);
            n = 0;
            while (!rx_letter_valid_latch && (n < 200_000)) begin
                @(posedge clk_i);
                n = n + 1;
            end
            if (!rx_letter_valid_latch) begin
                $display("[%0t] ERROR: timeout esperando rx_letter_valid_s para '%c'", $time, letter);
                errors = errors + 1;
            end
            repeat (LETTER_GAP_CYCLES) @(posedge clk_i);
        end
    endtask

    logic word_ready_latch = 1'b0;
    always @(posedge dut.word_ready_s) word_ready_latch = 1'b1;

    task automatic arm_word_ready();
        word_ready_latch = 1'b0;
    endtask

    task automatic wait_word_ready(input string label, input int max_cycles);
        int n;
        begin
            n = 0;
            while (!word_ready_latch && (n < max_cycles)) begin
                @(posedge clk_i);
                n = n + 1;
            end
            check(word_ready_latch, {"word_ready_s detectado -- ", label});
        end
    endtask

  task automatic wait_flag(ref bit flag, input int max_cycles, input string what);
        int n;
        begin
            n = 0;
            while (!flag && (n < max_cycles)) begin
                @(posedge clk_i);
                n = n + 1;
            end
            check(flag, what);
        end
    endtask

    task automatic wait_for_state(input logic [2:0] target, input int max_cycles, input string what);
        int n;
        begin
            n = 0;
            while ((dut.game_state_s !== target) && (n < max_cycles)) begin
                @(posedge clk_i);
                n = n + 1;
            end
            check(dut.game_state_s === target, what);
        end
    endtask

    string tx_line = "";
    bit    saw_start_msg = 1'b0;
    bit    saw_hit_msg   = 1'b0;
    bit    saw_miss_msg  = 1'b0;
    bit    saw_win_msg   = 1'b0;
    bit    saw_lose_attempts_msg = 1'b0;

    function automatic bit starts_with(string s, string prefix);
        starts_with = (s.len() >= prefix.len()) &&
                      (s.substr(0, prefix.len()-1) == prefix);
    endfunction

    initial begin : uart_tx_monitor
        logic [7:0] rx_byte;
        integer i;
        forever begin
            @(negedge uart_tx_o);
            repeat (BIT_CYCLES + BIT_CYCLES/2) @(posedge clk_i); // centro del bit0
            for (i = 0; i < 8; i = i + 1) begin
                rx_byte[i] = uart_tx_o;
                repeat (BIT_CYCLES) @(posedge clk_i);
            end
            if (rx_byte == 8'h0A) begin
                $display("[%0t] UART TX <<< %s", $time, tx_line);
                if (starts_with(tx_line, "START,")) saw_start_msg = 1'b1;
                if (starts_with(tx_line, "HIT,"))   saw_hit_msg   = 1'b1;
                if (starts_with(tx_line, "MISS,"))  saw_miss_msg  = 1'b1;
                if (starts_with(tx_line, "WIN,"))   saw_win_msg   = 1'b1;
                if (starts_with(tx_line, "LOSE_ATTEMPTS,")) saw_lose_attempts_msg = 1'b1;
                tx_line = "";
            end else begin
                tx_line = {tx_line, string'(rx_byte)};
            end
        end
    end

    logic [95:0] secret_word;
    logic [3:0]  word_len;
    logic [25:0] mask;
    byte         unique_letters[0:11];
    int          num_unique;
    byte         wrong_letters[0:5];
    int          num_wrong;
    integer      k, li;
    logic [6:0]  wins_before;

    initial begin
        btn_rst_i = 1'b1;
        btn_sel_i = 1'b0;
        btn_ok_i  = 1'b0;
        uart_rx_i = 1'b1; 
        repeat (20) @(posedge clk_i);
        btn_rst_i = 1'b0;
        repeat (20) @(posedge clk_i);

        check(^{seg_o, an_o, lcd_db_o, led_estado_o, buzzer_o} !== 1'bx,
              "Sin X's en las salidas fisicas despues del reset");
        check(dut.game_state_s === GS_MODE_SELECT,
              "game_state_s == GS_MODE_SELECT despues del reset");

        $display("\n===== RONDA 1: intentando WIN =====");
        arm_word_ready();
        press_button(btn_ok_i); wait_word_ready("ronda 1", 2000);

        secret_word = dut.u_word_engine.secret_word;
        word_len    = dut.word_length_from_engine_s;
        begin
            string word_str;
            word_str = "";
            for (k = 0; k < word_len; k = k + 1)
                word_str = {word_str, string'(secret_word[8*k +: 8])};
            $display("[%0t] Palabra secreta (ronda 1, longitud=%0d): %s", $time, word_len, word_str);
        end

        wait_for_state(GS_ACTIVE, 200, "game_state_s == GS_ACTIVE tras EVENT_START");
        wait_flag(saw_start_msg, 200_000, "Se recibio mensaje START, por UART");

        mask = 26'b0;
        num_unique = 0;
        for (k = 0; k < word_len; k = k + 1) begin
            byte ch;
            ch = secret_word[8*k +: 8];
            if (!mask[ch - 8'h41]) begin
                mask[ch - 8'h41]        = 1'b1;
                unique_letters[num_unique] = ch;
                num_unique = num_unique + 1;
            end
        end

        for (k = 0; k < num_unique; k = k + 1) begin
            $display("[%0t] Enviando letra correcta '%c' (%0d/%0d)", $time, unique_letters[k], k+1, num_unique);
            send_letter(unique_letters[k]);
        end

        wait_for_state(GS_WIN, 2000, "game_state_s == GS_WIN tras completar la palabra");
        wait_flag(saw_hit_msg, 50_000, "Se recibio al menos un mensaje HIT, por UART");
        wait_flag(saw_win_msg, 300_000, "Se recibio mensaje WIN, por UART");
        check(dut.game_won_s === 1'b1, "game_won_s == 1 en el estado GS_WIN");

        wait_for_state(GS_MODE_SELECT, RESULT_HOLD_TIMEOUT_CYCLES, "Vuelta a GS_MODE_SELECT tras RESULT_HOLD");

         $display("\n===== RONDA 2: intentando LOSE_ATTEMPTS =====");
        wins_before = dut.wins_s;

        arm_word_ready();
        press_button(btn_ok_i); 
        wait_word_ready("ronda 2", 2000);

        secret_word = dut.u_word_engine.secret_word;
        word_len    = dut.word_length_from_engine_s;

        wait_for_state(GS_ACTIVE, 200, "game_state_s == GS_ACTIVE en ronda 2");

        
        mask = 26'b0;
        for (k = 0; k < word_len; k = k + 1) begin
            byte ch;
            ch = secret_word[8*k +: 8];
            mask[ch - 8'h41] = 1'b1;
        end
        num_wrong = 0;
        for (li = 0; li < 26 && num_wrong < 6; li = li + 1) begin
            if (!mask[li]) begin
                wrong_letters[num_wrong] = 8'h41 + li;
                num_wrong = num_wrong + 1;
            end
        end
        check(num_wrong == 6, "Se encontraron 6 letras ausentes en la palabra para forzar LOSE_ATTEMPTS");

        for (k = 0; k < num_wrong; k = k + 1) begin
            $display("[%0t] Enviando letra incorrecta '%c' (%0d/6)", $time, wrong_letters[k], k+1);
            send_letter(wrong_letters[k]);
        end

        wait_for_state(GS_LOSE_ATTEMPTS, 2000, "game_state_s == GS_LOSE_ATTEMPTS tras 6 errores");
        wait_flag(saw_miss_msg, 50_000, "Se recibio al menos un mensaje MISS, por UART");
        wait_flag(saw_lose_attempts_msg, 300_000, "Se recibio mensaje LOSE_ATTEMPTS, por UART");
        check(dut.wins_s === wins_before, "wins_s no cambio durante una derrota");

        wait_for_state(GS_MODE_SELECT, RESULT_HOLD_TIMEOUT_CYCLES, "Vuelta a GS_MODE_SELECT tras la derrota");

        
        repeat (50) @(posedge clk_i);
        if (errors == 0)
            $display("\n===== TESTBENCH PASO: 0 errores =====");
        else
            $display("\n===== TESTBENCH FALLO: %0d error(es) =====", errors);

        $finish;
    end


    initial begin
        #500_000_000;
        $display("[%0t] ERROR: watchdog global -- la simulacion no termino a tiempo", $time);
        $finish;
    end

endmodule
