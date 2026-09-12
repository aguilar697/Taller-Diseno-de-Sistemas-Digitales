`timescale 1ns/1ps
// Generador de 63 estados no nulos. No se reinicia entre partidas:
// el instante de new_game influye en la palabra seleccionada.
module word_lfsr (
    input  logic       clk,
    input  logic       reset,
    output logic [5:0] state
);
    always_ff @(posedge clk) begin
        if (reset || state == 6'd0)
            state <= 6'd1;
        else
            state <= {state[4:0], state[5] ^ state[4]};
    end
endmodule
