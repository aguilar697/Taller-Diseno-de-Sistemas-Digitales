`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.08.2026
// Design Name: Whack-a-Mole FPGA Game
// Module Name: turn_timer
// Project Name: project_1_fsm_game
// Target Devices: Basys 3 - Artix-7 XC7A35T-1CPG236C
// Tool Versions: Vivado 2026.1
// Description:
//
// Este módulo controla la duración temporal de cada turno del juego.
//
// Mientras turn_enable se encuentre activo, el módulo cuenta los pulsos
// tick_1ms provenientes de tick_gen.sv.
//
// La cantidad máxima de milisegundos permitidos está definida mediante
// window_ms, cuyo valor es proporcionado por difficulty_ctrl.sv.
//
// Cuando el número de milisegundos transcurridos alcanza window_ms,
// el módulo genera timeout durante un solo ciclo del reloj principal.
//
// Una vez generado timeout, el temporizador permanece expirado hasta que
// turn_enable sea desactivado. Esto evita generar múltiples timeouts
// correspondientes al mismo turno.
//
// Dependencies:
// tick_gen.sv
// difficulty_ctrl.sv
//
// Revision:
// Revision 0.01 - File Created
//
// Additional Comments:
// Este módulo no genera ningún reloj adicional. Toda la lógica funciona con
// clk y utiliza tick_1ms únicamente como clock enable.
//
//////////////////////////////////////////////////////////////////////////////////


module turn_timer (

    // Reloj principal de 100 MHz
    input  logic        clk,

    // Reinicio general del sistema
    input  logic        reset,

    // Pulso de habilitación generado cada 1 ms
    input  logic        tick_1ms,

    // Indica que actualmente existe un turno activo
    input  logic        turn_enable,

    // Duración máxima permitida para el turno
    input  logic [10:0] window_ms,

    // Pulso generado cuando se agota el tiempo
    output logic        timeout

);


    //--------------------------------------------------------------------------
    // Señales internas
    //--------------------------------------------------------------------------

    // Cuenta los milisegundos transcurridos durante el turno
    logic [10:0] elapsed_ms;

    // Indica que el timeout ya fue generado para el turno actual
    logic expired;


    //--------------------------------------------------------------------------
    // Temporizador del turno
    //--------------------------------------------------------------------------

    always_ff @(posedge clk) begin

        if (reset) begin

            elapsed_ms <= 11'd0;
            timeout    <= 1'b0;
            expired    <= 1'b0;

        end
        else begin

            //------------------------------------------------------------------
            // timeout es un pulso de un único ciclo
            //------------------------------------------------------------------

            timeout <= 1'b0;


            //------------------------------------------------------------------
            // Si el turno no está activo, preparamos el temporizador
            // para el siguiente turno.
            //------------------------------------------------------------------

            if (!turn_enable) begin

                elapsed_ms <= 11'd0;
                expired    <= 1'b0;

            end


            //------------------------------------------------------------------
            // Mientras exista un turno activo y aún no haya expirado,
            // contamos únicamente cuando llega tick_1ms.
            //------------------------------------------------------------------

            else if (!expired && tick_1ms) begin

                //--------------------------------------------------------------
                // Si este tick completa la duración configurada,
                // generamos timeout.
                //--------------------------------------------------------------

                if (elapsed_ms >= window_ms - 1'b1) begin

                    elapsed_ms <= elapsed_ms;
                    timeout    <= 1'b1;
                    expired    <= 1'b1;

                end

                //--------------------------------------------------------------
                // Todavía queda tiempo disponible.
                //--------------------------------------------------------------

                else begin

                    elapsed_ms <= elapsed_ms + 1'b1;

                end

            end

        end

    end

endmodule