`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.08.2026
// Design Name: Whack-a-Mole FPGA Game
// Module Name: score_counters
// Project Name: project_1_fsm_game
// Target Devices: Basys 3 - Artix-7 XC7A35T-1CPG236C
// Tool Versions: Vivado 2026.1
// Description:
//
// Este módulo almacena los contadores principales del juego:
//
//   - hits: número total de aciertos de la partida.
//   - misses: número total de fallos de la partida.
//   - consecutive_misses: número de fallos consecutivos.
//
// Los contadores hits y misses pueden tomar valores entre 0 y 99.
// Una vez alcanzado 99, permanecen saturados en dicho valor.
//
// Cuando ocurre un acierto:
//   - hits aumenta en uno.
//   - consecutive_misses vuelve a cero.
//
// Cuando ocurre un fallo:
//   - misses aumenta en uno.
//   - consecutive_misses aumenta hasta un máximo de 3.
//
// El contador consecutive_misses será utilizado posteriormente por la FSM
// para determinar cuándo debe entrar al estado GAME OVER.
//
// Dependencies:
// None
//
// Revision:
// Revision 0.01 - File Created
//
// Additional Comments:
// Se supone que count_hit y count_miss son pulsos mutuamente exclusivos
// generados por la FSM del juego.
//
//////////////////////////////////////////////////////////////////////////////////


module score_counters (

    // Reloj principal de la FPGA
    input  logic       clk,

    // Reinicio general de la partida
    input  logic       reset,

    // Pulso para registrar un acierto
    input  logic       count_hit,

    // Pulso para registrar un fallo
    input  logic       count_miss,

    // Total de aciertos: 0 a 99
    output logic [6:0] hits,

    // Total de fallos: 0 a 99
    output logic [6:0] misses,

    // Fallos consecutivos: 0 a 3
    output logic [1:0] consecutive_misses

);


    //--------------------------------------------------------------------------
    // Constantes
    //--------------------------------------------------------------------------

    localparam logic [6:0] MAX_SCORE = 7'd99;
    localparam logic [1:0] MAX_CONSECUTIVE_MISSES = 2'd3;


    //--------------------------------------------------------------------------
    // Contadores del juego
    //--------------------------------------------------------------------------

    always_ff @(posedge clk) begin

        if (reset) begin

            hits               <= 7'd0;
            misses             <= 7'd0;
            consecutive_misses <= 2'd0;

        end
        else begin

            //------------------------------------------------------------------
            // Registro de HIT
            //
            // count_hit y count_miss deben ser mutuamente exclusivos.
            //------------------------------------------------------------------

            if (count_hit && !count_miss) begin

                //--------------------------------------------------------------
                // Saturación del contador de aciertos en 99
                //--------------------------------------------------------------

                if (hits < MAX_SCORE)
                    hits <= hits + 1'b1;

                else
                    hits <= MAX_SCORE;


                //--------------------------------------------------------------
                // Un acierto rompe la cadena de fallos consecutivos
                //--------------------------------------------------------------

                consecutive_misses <= 2'd0;

            end


            //------------------------------------------------------------------
            // Registro de MISS
            //------------------------------------------------------------------

            else if (count_miss && !count_hit) begin

                //--------------------------------------------------------------
                // Saturación del contador de fallos acumulados en 99
                //--------------------------------------------------------------

                if (misses < MAX_SCORE)
                    misses <= misses + 1'b1;

                else
                    misses <= MAX_SCORE;


                //--------------------------------------------------------------
                // Fallos consecutivos saturados en 3
                //--------------------------------------------------------------

                if (consecutive_misses < MAX_CONSECUTIVE_MISSES)
                    consecutive_misses <= consecutive_misses + 1'b1;

                else
                    consecutive_misses <= MAX_CONSECUTIVE_MISSES;

            end

        end

    end

endmodule