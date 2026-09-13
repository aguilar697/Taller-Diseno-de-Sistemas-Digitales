`timescale 1ns/1ps
module sevenseg_driver #(
    parameter int unsigned DIGIT_CYCLES = 25_000
) (
    input  logic       clk_i,
    input  logic       rst_i,
    input  logic [6:0] time_remaining_i,
    input  logic [6:0] wins_i,
    output logic [6:0] seg_o,
    output logic [3:0] an_o
);

  localparam int CNT_W = $clog2(DIGIT_CYCLES + 1);

  logic [CNT_W-1:0] scan_cnt;
  logic [1:0]       digit_sel;
  logic             tick;

  assign tick = (scan_cnt >= CNT_W'(DIGIT_CYCLES - 1));

  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      scan_cnt  <= '0;
      digit_sel <= 2'b00;
    end else if (tick) begin
      scan_cnt  <= '0;
      digit_sel <= digit_sel + 1'b1;
    end else begin
      scan_cnt <= scan_cnt + 1'b1;
    end
  end

  function automatic logic [3:0] bin_tens(input logic [6:0] value);
    logic [6:0] v;
    logic [3:0] t;
    integer i;
    begin
      v = value;
      t = 4'd0;
      // Límite estático: con v de 7 bits (max 127), 13 iteraciones bastan
      // de sobra (floor(127/10) = 12) para dejar v < 10.
      for (i = 0; i < 13; i = i + 1) begin
        if (v >= 7'd10) begin
          v = v - 7'd10;
          t = t + 4'd1;
        end
      end
      bin_tens = t;
    end
  endfunction

  function automatic logic [3:0] bin_units(input logic [6:0] value);
    logic [6:0] v;
    integer i;
    begin
      v = value;
      for (i = 0; i < 13; i = i + 1) begin
        if (v >= 7'd10) begin
          v = v - 7'd10;
        end
      end
      bin_units = v[3:0];
    end
  endfunction

  function automatic logic [6:0] seg_decode(input logic [3:0] nibble);
    case (nibble)
      4'd0:    seg_decode = 7'b1000000;
      4'd1:    seg_decode = 7'b1111001;
      4'd2:    seg_decode = 7'b0100100;
      4'd3:    seg_decode = 7'b0110000;
      4'd4:    seg_decode = 7'b0011001;
      4'd5:    seg_decode = 7'b0010010;
      4'd6:    seg_decode = 7'b0000010;
      4'd7:    seg_decode = 7'b1111000;
      4'd8:    seg_decode = 7'b0000000;
      4'd9:    seg_decode = 7'b0010000;
      default: seg_decode = 7'b1111111;
    endcase
  endfunction

  logic [3:0] time_tens, time_units, wins_tens, wins_units;

  assign time_tens  = bin_tens(time_remaining_i);
  assign time_units = bin_units(time_remaining_i);
  assign wins_tens  = bin_tens(wins_i);
  assign wins_units = bin_units(wins_i);

  logic [3:0] active_nibble;

  always_comb begin
    unique case (digit_sel)
      2'd0: begin
        an_o          = 4'b1110;
        active_nibble = time_tens;
      end
      2'd1: begin
        an_o          = 4'b1101;
        active_nibble = time_units;
      end
      2'd2: begin
        an_o          = 4'b1011;
        active_nibble = wins_tens;
      end
      2'd3: begin
        an_o          = 4'b0111;
        active_nibble = wins_units;
      end
      default: begin
        an_o          = 4'b1111;
        active_nibble = 4'd0;
      end
    endcase
  end

  assign seg_o = seg_decode(active_nibble);

endmodule
