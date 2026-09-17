`timescale 1ns/1ps
module led_control (
    input  logic [2:0] game_state_i,
    output logic [1:0] led_estado_o
);

  // Codificacion de game_fsm.sv (Subsistema 1): no modificar aqui.
  localparam logic [2:0] GS_MODE_SELECT   = 3'd0;
  localparam logic [2:0] GS_STARTING      = 3'd1;
  localparam logic [2:0] GS_ACTIVE        = 3'd2;
  localparam logic [2:0] GS_WIN           = 3'd3;
  localparam logic [2:0] GS_LOSE_ATTEMPTS = 3'd4;
  localparam logic [2:0] GS_LOSE_TIME     = 3'd5;

  always_comb begin
    unique case (game_state_i)
      GS_MODE_SELECT:                    led_estado_o = 2'b00;
      GS_STARTING, GS_ACTIVE:            led_estado_o = 2'b01;
      GS_WIN, GS_LOSE_ATTEMPTS,
      GS_LOSE_TIME:                      led_estado_o = 2'b10;
      default:                           led_estado_o = 2'b00;
    endcase
  end

endmodule
