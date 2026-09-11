module game_control_top #(
    parameter int unsigned CLK_HZ              = 100_000_000,
    parameter int unsigned EASY_SECONDS        = 60,
    parameter int unsigned HARD_SECONDS        = 45,
    parameter int unsigned RESULT_HOLD_SECONDS = 3,
    parameter int unsigned DEBOUNCE_CYCLES     = 2_000_000
)(
    // ============================================================
    // CLOCK Y BOTONES
    // ============================================================
    input  logic        clk_i,
    input  logic        btn_sel_i,
    input  logic        btn_ok_i,
    input  logic        btn_rst_i,

    // ============================================================
    // UART
    // ============================================================
    input  logic        rx_letter_valid_i,
    input  logic [7:0]  rx_letter_i,

    // ============================================================
    // WORD ENGINE -> CONTROL
    // ============================================================
    input  logic        word_ready_i,
    input  logic [3:0]  word_length_i,
    input  logic [95:0] revealed_word_i,
    input  logic        letter_correct_i,
    input  logic        letter_repeated_i,
    input  logic        word_complete_i,

    // ============================================================
    // CONTROL -> WORD ENGINE
    // ============================================================
    output logic        new_game_o,
    output logic        difficulty_o,
    output logic        letter_valid_o,
    output logic [7:0]  letter_ascii_o,

    // ============================================================
    // SALIDAS PÚBLICAS
    // UART / INTERFAZ LOCAL
    // ============================================================
    output logic [2:0]  game_state_o,
    output logic [95:0] revealed_word_o,
    output logic [3:0]  word_length_o,
    output logic [2:0]  attempts_left_o,
    output logic [6:0]  time_remaining_o,
    output logic [6:0]  wins_o,

    output logic        correct_pulse_o,
    output logic        wrong_pulse_o,
    output logic        game_over_pulse_o,
    output logic        game_won_o
);

    // ============================================================
    // SEÑALES INTERNAS
    // ============================================================

    logic rst_sync_s;

    logic btn_sel_pulse_s;
    logic btn_ok_pulse_s;

    logic toggle_difficulty_s;
    logic load_attempts_s;
    logic dec_attempts_s;
    logic inc_wins_s;
    logic capture_letter_s;
    logic capture_word_s;

    logic timer_load_s;
    logic timer_enable_s;
    logic time_expired_s;

    logic result_timer_start_s;
    logic result_hold_done_s;

    logic        difficulty_s;
    logic [2:0]  attempts_left_s;
    logic [6:0]  wins_s;
    logic [7:0]  letter_ascii_s;
    logic [3:0]  word_length_s;
    logic [95:0] revealed_word_s;
    logic [6:0]  time_remaining_s;

    logic        new_game_s;
    logic        letter_valid_s;
    logic [2:0]  game_state_s;
    logic        correct_pulse_s;
    logic        wrong_pulse_s;
    logic        game_over_pulse_s;
    logic        game_won_s;


    // ============================================================
    // RESET SYNCHRONIZER
    // ============================================================
    reset_sync u_reset_sync (
        .clk_i     (clk_i),
        .btn_rst_i (btn_rst_i),
        .rst_sync  (rst_sync_s)
    );


    // ============================================================
    // BTN_SEL
    // ============================================================
    button_conditioner #(
        .DEBOUNCE_CYCLES (DEBOUNCE_CYCLES)
    ) u_btn_sel (
        .clk_i     (clk_i),
        .rst_sync  (rst_sync_s),
        .btn_i     (btn_sel_i),
        .btn_pulse (btn_sel_pulse_s)
    );


    // ============================================================
    // BTN_OK
    // ============================================================
    button_conditioner #(
        .DEBOUNCE_CYCLES (DEBOUNCE_CYCLES)
    ) u_btn_ok (
        .clk_i     (clk_i),
        .rst_sync  (rst_sync_s),
        .btn_i     (btn_ok_i),
        .btn_pulse (btn_ok_pulse_s)
    );


    // ============================================================
    // DATAPATH
    // ============================================================
    game_datapath #(
        .MAX_ATTEMPTS (3'd6),
        .MAX_WINS     (7'd99)
    ) u_datapath (
        .clk_i                 (clk_i),
        .rst_sync              (rst_sync_s),

        .toggle_difficulty_i   (toggle_difficulty_s),
        .load_attempts_i       (load_attempts_s),
        .dec_attempts_i        (dec_attempts_s),
        .inc_wins_i            (inc_wins_s),
        .capture_letter_i      (capture_letter_s),
        .capture_word_i        (capture_word_s),

        .rx_letter_i           (rx_letter_i),
        .word_length_i         (word_length_i),
        .revealed_word_i       (revealed_word_i),

        .difficulty_o          (difficulty_s),
        .attempts_left_o       (attempts_left_s),
        .wins_o                (wins_s),
        .letter_ascii_o        (letter_ascii_s),
        .word_length_o         (word_length_s),
        .revealed_word_o       (revealed_word_s)
    );


    // ============================================================
    // TEMPORIZADOR REGRESIVO
    // ============================================================
    countdown_timer #(
        .CLK_HZ       (CLK_HZ),
        .EASY_SECONDS (EASY_SECONDS),
        .HARD_SECONDS (HARD_SECONDS)
    ) u_countdown_timer (
        .clk_i          (clk_i),
        .rst_sync       (rst_sync_s),
        .difficulty     (difficulty_s),
        .load           (timer_load_s),
        .enable         (timer_enable_s),

        .time_remaining (time_remaining_s),
        .expired        (time_expired_s)
    );


    // ============================================================
    // TEMPORIZADOR DE RESULTADO
    // ============================================================
    result_hold_timer #(
        .CLK_HZ       (CLK_HZ),
        .HOLD_SECONDS (RESULT_HOLD_SECONDS)
    ) u_result_hold_timer (
        .clk_i            (clk_i),
        .rst_sync         (rst_sync_s),
        .start            (result_timer_start_s),
        .result_hold_done (result_hold_done_s)
    );


    // ============================================================
    // FSM PRINCIPAL
    // ============================================================
    game_fsm u_game_fsm (
        .clk_i                 (clk_i),
        .rst_sync              (rst_sync_s),

        .btn_sel_pulse_i       (btn_sel_pulse_s),
        .btn_ok_pulse_i        (btn_ok_pulse_s),

        .rx_letter_valid_i     (rx_letter_valid_i),
        .rx_letter_i           (rx_letter_i),

        .word_ready_i          (word_ready_i),
        .letter_correct_i      (letter_correct_i),
        .letter_repeated_i     (letter_repeated_i),
        .word_complete_i       (word_complete_i),

        .attempts_left_i       (attempts_left_s),
        .time_expired_i        (time_expired_s),
        .result_hold_done_i    (result_hold_done_s),

        .toggle_difficulty_o   (toggle_difficulty_s),
        .load_attempts_o       (load_attempts_s),
        .dec_attempts_o        (dec_attempts_s),
        .inc_wins_o            (inc_wins_s),
        .capture_letter_o      (capture_letter_s),
        .capture_word_o        (capture_word_s),

        .timer_load_o          (timer_load_s),
        .timer_enable_o        (timer_enable_s),

        .result_timer_start_o  (result_timer_start_s),

        .new_game_o            (new_game_s),
        .letter_valid_o        (letter_valid_s),

        .game_state_o          (game_state_s),
        .correct_pulse_o       (correct_pulse_s),
        .wrong_pulse_o         (wrong_pulse_s),
        .game_over_pulse_o     (game_over_pulse_s),
        .game_won_o            (game_won_s)
    );


    // ============================================================
    // SALIDAS DEL SUBSISTEMA
    // ============================================================
    assign new_game_o       = new_game_s;
    assign difficulty_o     = difficulty_s;
    assign letter_valid_o   = letter_valid_s;
    assign letter_ascii_o   = letter_ascii_s;

    assign game_state_o     = game_state_s;
    assign revealed_word_o  = revealed_word_s;
    assign word_length_o    = word_length_s;
    assign attempts_left_o  = attempts_left_s;
    assign time_remaining_o = time_remaining_s;
    assign wins_o           = wins_s;

    assign correct_pulse_o   = correct_pulse_s;
    assign wrong_pulse_o     = wrong_pulse_s;
    assign game_over_pulse_o = game_over_pulse_s;
    assign game_won_o        = game_won_s;

endmodule