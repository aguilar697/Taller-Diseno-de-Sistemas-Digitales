`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/18/2026 07:52:40 PM
// Design Name: 
// Module Name: game_over_timer
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description:
//
// Este modulo mantiene el estado GAME OVER activo durante al menos
// GAME_OVER_MS milisegundos (2000 ms por defecto = 2 s).
//
// Mientras game_over_enable se encuentre activo, el modulo cuenta los
// pulsos tick_1ms provenientes de tick_gen.sv. Cuando el numero de
// milisegundos transcurridos alcanza GAME_OVER_MS, el modulo genera
// game_over_done durante un solo ciclo del reloj principal.
//
// Una vez generado game_over_done, el temporizador permanece expirado
// hasta que game_over_enable sea desactivado. Esto evita generar
// multiples pulsos durante la misma pantalla de GAME OVER. 
// 
// Dependencies: 
// tick_gen.sv  
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module game_over_timer #(
    // Duracion minima del estado GAME OVER, en milisegundos.
    parameter int GAME_OVER_MS = 2000
)(
    input  logic clk, // Reloj principal de 100 MHz
    input  logic reset, // Reinicio general del sistema
    input  logic tick_1ms, // Pulso de habilitacion generado cada 1 ms
    input  logic game_over_enable, // Indica que actualmente el juego esta en estado GAME OVER
    output logic game_over_done // Pulso generado cuando se cumplen los GAME_OVER_MS
);

    //--------------------------------------------------------------------------
    // Senales internas
    //--------------------------------------------------------------------------

    // Ancho necesario para contar hasta GAME_OVER_MS
    localparam int COUNT_WIDTH =
        (GAME_OVER_MS <= 1) ? 1 : $clog2(GAME_OVER_MS + 1);

    // Cuenta los milisegundos transcurridos durante GAME OVER
    logic [COUNT_WIDTH-1:0] elapsed_ms;

    // Indica que game_over_done ya fue generado para este ciclo
    logic expired;


    //--------------------------------------------------------------------------
    // Temporizador de GAME OVER
    //--------------------------------------------------------------------------

    always_ff @(posedge clk) begin

        if (reset) begin

            elapsed_ms     <= '0;
            game_over_done <= 1'b0;
            expired        <= 1'b0;

        end
        else begin

            //------------------------------------------------------------------
            // game_over_done es un pulso de un unico ciclo
            //------------------------------------------------------------------

            game_over_done <= 1'b0;


            //------------------------------------------------------------------
            // Si GAME OVER no esta activo, preparamos el temporizador
            // para la siguiente vez que se necesite.
            //------------------------------------------------------------------

            if (!game_over_enable) begin

                elapsed_ms <= '0;
                expired    <= 1'b0;

            end


            //------------------------------------------------------------------
            // Mientras GAME OVER este activo y aun no haya expirado,
            // contamos unicamente cuando llega tick_1ms.
            //------------------------------------------------------------------

            else if (!expired && tick_1ms) begin

                //--------------------------------------------------------------
                // Si este tick completa la duracion configurada,
                // generamos game_over_done.
                //--------------------------------------------------------------

                if (elapsed_ms >= GAME_OVER_MS - 1) begin

                    elapsed_ms     <= elapsed_ms;
                    game_over_done <= 1'b1;
                    expired        <= 1'b1;

                end

                //--------------------------------------------------------------
                // Todavia no se cumple la duracion minima.
                //--------------------------------------------------------------

                else begin

                    elapsed_ms <= elapsed_ms + 1'b1;

                end

            end

        end

    end

endmodule






