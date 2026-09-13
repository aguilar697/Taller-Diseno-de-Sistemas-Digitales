`timescale 1ns/1ps
module buzzer_control #(
    parameter int unsigned HALF_PERIOD_CORRECT = 50_000,
    parameter int unsigned HALF_PERIOD_WRONG   = 166_667,
    parameter int unsigned HALF_PERIOD_OVER    = 83_333,
    parameter int unsigned DURATION_CORRECT    = 10_000_000,
    parameter int unsigned DURATION_WRONG      = 20_000_000,
    parameter int unsigned DURATION_OVER       = 40_000_000
) (
    input  logic clk_i,
    input  logic rst_i,
    input  logic correct_pulse_i,
    input  logic wrong_pulse_i,
    input  logic game_over_pulse_i,
    output logic buzzer_o,
    output logic buzzer_busy_o
);

  localparam int unsigned MAX_HALF_PERIOD = 166_667;
  localparam int unsigned MAX_DURATION    = 40_000_000;

  localparam int HALF_CNT_W = $clog2(MAX_HALF_PERIOD + 1);
  localparam int DUR_CNT_W  = $clog2(MAX_DURATION + 1);

  typedef enum logic [1:0] {
    S_IDLE,
    S_TONE_CORRECT,
    S_TONE_WRONG,
    S_TONE_OVER
  } buzz_state_e;

  buzz_state_e state;

  logic [HALF_CNT_W-1:0] half_cnt;
  logic [DUR_CNT_W-1:0]  dur_cnt;
  logic                  tone_level;

  logic [HALF_CNT_W-1:0] half_target;
  logic [DUR_CNT_W-1:0]  dur_target;

  always_comb begin
    unique case (state)
      S_TONE_CORRECT: begin
        half_target = HALF_CNT_W'(HALF_PERIOD_CORRECT);
        dur_target  = DUR_CNT_W'(DURATION_CORRECT);
      end
      S_TONE_WRONG: begin
        half_target = HALF_CNT_W'(HALF_PERIOD_WRONG);
        dur_target  = DUR_CNT_W'(DURATION_WRONG);
      end
      S_TONE_OVER: begin
        half_target = HALF_CNT_W'(HALF_PERIOD_OVER);
        dur_target  = DUR_CNT_W'(DURATION_OVER);
      end
      default: begin
        half_target = HALF_CNT_W'(HALF_PERIOD_CORRECT);
        dur_target  = DUR_CNT_W'(DURATION_CORRECT);
      end
    endcase
  end

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      state      <= S_IDLE;
      half_cnt   <= '0;
      dur_cnt    <= '0;
      tone_level <= 1'b0;
    end else begin
      unique case (state)

        S_IDLE: begin
          half_cnt   <= '0;
          dur_cnt    <= '0;
          tone_level <= 1'b0;
          if (game_over_pulse_i)
            state <= S_TONE_OVER;
          else if (wrong_pulse_i)
            state <= S_TONE_WRONG;
          else if (correct_pulse_i)
            state <= S_TONE_CORRECT;
        end

        S_TONE_CORRECT, S_TONE_WRONG, S_TONE_OVER: begin
          if (dur_cnt >= dur_target - 1'b1) begin
            state      <= S_IDLE;
            half_cnt   <= '0;
            dur_cnt    <= '0;
            tone_level <= 1'b0;
          end else begin
            dur_cnt <= dur_cnt + 1'b1;
            if (half_cnt >= half_target - 1'b1) begin
              half_cnt   <= '0;
              tone_level <= ~tone_level;
            end else begin
              half_cnt <= half_cnt + 1'b1;
            end
          end
        end

        default: state <= S_IDLE;

      endcase
    end
  end

  assign buzzer_o      = tone_level;
  assign buzzer_busy_o = (state != S_IDLE);

endmodule
