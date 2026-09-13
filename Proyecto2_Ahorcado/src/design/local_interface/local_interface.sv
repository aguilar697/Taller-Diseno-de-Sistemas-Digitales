`timescale 1ns/1ps
module local_interface (
    input  logic        clk_i,
    input  logic        rst_i,

    input  logic [2:0]  game_state_i,
    input  logic        difficulty_i,
    input  logic [2:0]  attempts_left_i,
    input  logic [6:0]  time_remaining_i,
    input  logic [6:0]  wins_i,
    input  logic        game_won_i,
    input  logic        correct_pulse_i,
    input  logic        wrong_pulse_i,
    input  logic        game_over_pulse_i,

    input  logic [95:0] revealed_word_i,
    input  logic [3:0]  word_length_i,

    output logic        lcd_ready_o,
    output logic        lcd_busy_o,
    output logic        screen_done_o,
    output logic        buzzer_busy_o,

    output logic [7:0]  lcd_db_o,
    output logic        lcd_rs_o,
    output logic        lcd_rw_o,
    output logic        lcd_e_o,
    output logic [6:0]  seg_o,
    output logic [3:0]  an_o,
    output logic [1:0]  led_estado_o,
    output logic        buzzer_o
);

  logic        lcd_we;
  logic [1:0]  lcd_addr;
  logic [31:0] lcd_wdata;
  logic [31:0] lcd_rdata;

  screen_manager u_screen_manager (
      .clk_i          (clk_i),
      .rst_i          (rst_i),
      .game_state_i   (game_state_i),
      .difficulty_i   (difficulty_i),
      .attempts_left_i(attempts_left_i),
      .game_won_i     (game_won_i),
      .revealed_word_i(revealed_word_i),
      .word_length_i  (word_length_i),
      .lcd_rdata_i    (lcd_rdata),
      .lcd_we_o       (lcd_we),
      .lcd_addr_o     (lcd_addr),
      .lcd_wdata_o    (lcd_wdata),
      .lcd_ready_o    (lcd_ready_o),
      .lcd_busy_o     (lcd_busy_o),
      .screen_done_o  (screen_done_o)
  );

  lcd_peripheral u_lcd_peripheral (
      .clk_i         (clk_i),
      .rst_i         (rst_i),
      .write_enable_i(lcd_we),
      .addr_i        (lcd_addr),
      .wdata_i       (lcd_wdata),
      .rdata_o       (lcd_rdata),
      .lcd_db        (lcd_db_o),
      .lcd_rs        (lcd_rs_o),
      .lcd_rw        (lcd_rw_o),
      .lcd_e         (lcd_e_o)
  );

  sevenseg_driver u_sevenseg_driver (
      .clk_i           (clk_i),
      .rst_i           (rst_i),
      .time_remaining_i(time_remaining_i),
      .wins_i          (wins_i),
      .seg_o           (seg_o),
      .an_o            (an_o)
  );

  led_control u_led_control (
      .game_state_i (game_state_i),
      .led_estado_o (led_estado_o)
  );

  buzzer_control u_buzzer_control (
      .clk_i            (clk_i),
      .rst_i            (rst_i),
      .correct_pulse_i  (correct_pulse_i),
      .wrong_pulse_i    (wrong_pulse_i),
      .game_over_pulse_i(game_over_pulse_i),
      .buzzer_o         (buzzer_o),
      .buzzer_busy_o    (buzzer_busy_o)
  );

endmodule
