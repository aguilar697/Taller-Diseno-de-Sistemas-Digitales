`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.08.2026
// Design Name: Whack-a-Mole FPGA Game
// Module Name: difficulty_ctrl
// Project Name: project_1_fsm_game
// Target Devices: Basys 3 - Artix-7 XC7A35T-1CPG236C
// Tool Versions: Vivado 2026.1
// Description: 
// Este módulo controla la duración de la ventana activa de cada turno.
//
// La dificultad inicial corresponde a una ventana de 1500 ms.
// Cada vez que se recibe un pulso hit_update, la duración disminuye
// 100 ms hasta alcanzar un mínimo de 500 ms.
//
// Una vez alcanzados los 500 ms, la dificultad permanece en ese nivel
// aunque continúen ocurriendo aciertos.
//
// Los fallos no modifican este módulo. Por lo tanto, la dificultad alcanzada
// se conserva durante toda la partida hasta que ocurra un reset.
//
// Dependencies:
// None
//
// Revision:
// Revision 0.01 - File Created
//
// Additional Comments:
// La salida window_ms será utilizada posteriormente por turn_timer.sv
// para determinar cuánto tiempo permanece activo cada topo.
//
//////////////////////////////////////////////////////////////////////////////////


module difficulty_ctrl (

    // Reloj principal de la FPGA
    input  logic        clk,

    // Reinicio del juego
    input  logic        reset,

    // Pulso generado cuando un HIT debe aumentar la dificultad
    input  logic        hit_update,

    // Duración actual de la ventana del turno en milisegundos
    output logic [10:0] window_ms

);


    //--------------------------------------------------------------------------
    // Constantes de dificultad
    //--------------------------------------------------------------------------

    localparam logic [10:0] INITIAL_WINDOW = 11'd1500;
    localparam logic [10:0] MIN_WINDOW     = 11'd500;
    localparam logic [10:0] STEP_WINDOW    = 11'd100;


    //--------------------------------------------------------------------------
    // Registro de dificultad
    //--------------------------------------------------------------------------

    always_ff @(posedge clk) begin

        if (reset) begin

            // Cada nueva partida comienza con 1500 ms
            window_ms <= INITIAL_WINDOW;

        end
        else begin

            //------------------------------------------------------------------
            // La dificultad solamente se modifica cuando ocurre un HIT.
            //------------------------------------------------------------------

            if (hit_update) begin

                //--------------------------------------------------------------
                // Si todavía estamos por encima del mínimo,
                // reducimos 100 ms.
                //--------------------------------------------------------------

                if (window_ms > MIN_WINDOW) begin

                    window_ms <= window_ms - STEP_WINDOW;

                end

                //--------------------------------------------------------------
                // Una vez alcanzados 500 ms, se conserva el valor.
                //--------------------------------------------------------------

                else begin

                    window_ms <= MIN_WINDOW;

                end

            end

        end

    end

endmodule