`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.08.2026 14:54:37
// Design Name: Whack-a-Mole FPGA Game
// Module Name: hit_evaluator
// Project Name: project_1_fsm_game
// Target Devices: Basys 3 - Artix-7 XC7A35T-1CPG236C
// Tool Versions: Vivado 2026.1
// Description: 
// Este módulo evalúa la pulsación realizada por el jugador y determina
// si corresponde con la posición activa del topo.
//
// La posición del topo se recibe mediante mole_position[2:0], mientras que
// press_pulse[7:0] contiene los pulsos ya sincronizados, filtrados y
// acondicionados provenientes de los ocho botones externos.
//
// El módulo genera:
//   - hit_event: indica que se presionó exactamente el botón correcto.
//   - wrong_hit: indica que se presionó uno o varios botones incorrectos.
//   - any_press: indica que hubo al menos una pulsación.
//
// Si no se presiona ningún botón, no se genera ningún evento. El caso de
// ausencia de pulsación hasta finalizar el tiempo será manejado posteriormente
// por el temporizador del turno y la FSM del juego.
//
// Dependencies: 
// buttons_frontend.sv
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// Se considera una pulsación correcta únicamente cuando press_pulse coincide
// exactamente con la posición activa. Si se presionan varios botones al mismo
// tiempo, se considera una entrada incorrecta.
//
//////////////////////////////////////////////////////////////////////////////////


module hit_evaluator (

    // Posición activa del topo: valores de 0 a 7
    input  logic [2:0] mole_position,

    // Pulsos provenientes de los ocho botones externos
    input  logic [7:0] press_pulse,

    // Indica una pulsación correcta
    output logic       hit_event,

    // Indica una pulsación incorrecta
    output logic       wrong_hit,

    // Indica que al menos un botón fue presionado
    output logic       any_press

);

    // Máscara one-hot que representa el botón correcto
    logic [7:0] expected_button;


    //--------------------------------------------------------------------------
    // Lógica combinacional de evaluación
    //--------------------------------------------------------------------------

    always_comb begin

        //----------------------------------------------------------------------
        // Conversión de la posición del topo a una representación one-hot
        //
        // Ejemplos:
        // mole_position = 0  -> expected_button = 00000001
        // mole_position = 3  -> expected_button = 00001000
        // mole_position = 5  -> expected_button = 00100000
        //----------------------------------------------------------------------

        expected_button = 8'b00000001 << mole_position;


        //----------------------------------------------------------------------
        // Detección de cualquier pulsación
        //
        // El operador de reducción OR genera:
        //   any_press = 0 si press_pulse = 00000000
        //   any_press = 1 si cualquier bit de press_pulse es 1
        //----------------------------------------------------------------------

        any_press = |press_pulse;


        //----------------------------------------------------------------------
        // Evaluación de acierto
        //
        // Solo se considera HIT cuando press_pulse coincide exactamente con
        // el botón asociado a mole_position.
        //----------------------------------------------------------------------

        hit_event = (press_pulse == expected_button);


        //----------------------------------------------------------------------
        // Evaluación de pulsación incorrecta
        //
        // Se genera wrong_hit cuando:
        //   1. Se presionó al menos un botón.
        //   2. La combinación no coincide exactamente con el botón correcto.
        //
        // Esto también permite considerar varias pulsaciones simultáneas
        // como una entrada incorrecta.
        //----------------------------------------------------------------------

        wrong_hit = any_press &&
                    (press_pulse != expected_button);

    end

endmodule