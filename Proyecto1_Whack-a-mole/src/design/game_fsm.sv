`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Module Name: game_fsm
//
// Máquina de estados principal del juego Whack-a-Mole.
//
// Estados:
//
//   S_RESET     -> prepara una partida nueva.
//   S_REQUEST   -> solicita una nueva posición al circuito discreto.
//                  mole_request permanece activo durante REQUEST_HOLD_MS.
//                  Si la UART responde durante este tiempo, la posición
//                  se almacena temporalmente para no perder data_valid.
//
//   S_WAIT_UART -> espera una respuesta UART si esta no llegó durante
//                  S_REQUEST.
//
//   S_ACTIVE    -> turno activo. Espera hit, wrong hit o timeout.
//
//   S_EVALUATE  -> genera durante un ciclo count_hit/count_miss.
//
//   S_CHECK     -> revisa los fallos consecutivos.
//
//   S_GAMEOVER  -> mantiene el estado GAME OVER hasta completar
//                  el tiempo correspondiente.
//
//////////////////////////////////////////////////////////////////////////////////

module game_fsm #(

    // Tiempo que mole_request permanece activo.
    parameter int REQUEST_HOLD_MS = 5

)(

    // Reloj principal de la FPGA.
    input  logic       clk,

    // Reset general.
    input  logic       reset,

    // Pulso de 1 ms generado por tick_gen.
    input  logic       tick_1ms,

    // Byte recibido por UART.
    input  logic [7:0] data,

    // Pulso de un ciclo que indica que data contiene
    // un byte UART válido.
    input  logic       data_valid,

    // Eventos provenientes del evaluador de botones.
    input  logic       hit_event,
    input  logic       wrong_hit,

    // Timeout del turno.
    input  logic       timeout,

    // Número de fallos consecutivos.
    input  logic [1:0] consecutive_misses,

    // Indica que terminó el tiempo mínimo de GAME OVER.
    input  logic       game_over_done,

    // Solicitud hacia el circuito discreto.
    output logic       mole_request,

    // Posición activa del topo.
    output logic [2:0] mole_position,

    // Habilita el temporizador del turno.
    output logic       turn_enable,

    // Pulsos hacia los contadores.
    output logic       count_hit,
    output logic       count_miss,

    // Actualiza dificultad después de un acierto.
    output logic       hit_update,

    // Control de GAME OVER.
    output logic       game_over_enable,
    output logic       game_status_led,

    // Pulso para limpiar módulos al comenzar una partida nueva.
    output logic       new_game_pulse
);


    //--------------------------------------------------------------------------
    // Definición de estados
    //--------------------------------------------------------------------------

    typedef enum logic [2:0] {

        S_RESET,
        S_REQUEST,
        S_WAIT_UART,
        S_ACTIVE,
        S_EVALUATE,
        S_CHECK,
        S_GAMEOVER  

    } state_t;

    state_t state;


    //--------------------------------------------------------------------------
    // Señales internas
    //--------------------------------------------------------------------------

    // Número de bits necesarios para el contador de REQUEST.
    localparam int REQ_COUNT_WIDTH =
        (REQUEST_HOLD_MS <= 1) ? 1 : $clog2(REQUEST_HOLD_MS);

    logic [REQ_COUNT_WIDTH-1:0] req_counter;


    // Guarda si el turno anterior fue HIT o MISS.
    logic was_hit;


    //--------------------------------------------------------------------------
    // NUEVO:
    // almacenamiento de una respuesta UART temprana
    //--------------------------------------------------------------------------

    // Se pone en 1 cuando llega data_valid mientras todavía
    // estamos manteniendo mole_request en S_REQUEST.
    logic uart_pending;

    // Guarda los 3 bits de posición recibidos durante S_REQUEST.
    logic [2:0] pending_position;


    //--------------------------------------------------------------------------
    // Salidas Moore
    //--------------------------------------------------------------------------

    always_comb begin

        // mole_request permanece alto durante S_REQUEST.
        //¿Estoy en S_REQUEST? Sí → mole_request = 1
        mole_request = (state == S_REQUEST);

        // El temporizador solamente corre durante un turno activo.
        //¿Estoy en S_ACTIVE? Sí → turn_enable = 1
        turn_enable = (state == S_ACTIVE);

        // GAME OVER.
        //¿Estoy en S_GAMEOVER? Sí → game_over_enable = 1
        game_over_enable = (state == S_GAMEOVER);
        game_status_led  = (state == S_GAMEOVER);

        // Actualización de contadores.
        count_hit =
            (state == S_EVALUATE) && was_hit;

        count_miss =
            (state == S_EVALUATE) && !was_hit;

        // La dificultad solamente cambia después de un HIT.
        hit_update = count_hit;

        // Pulso de reinicio interno al comenzar una partida.
        new_game_pulse =
            (state == S_RESET);

    end


    //--------------------------------------------------------------------------
    // Registro de estado y lógica de transición
    //--------------------------------------------------------------------------

    always_ff @(posedge clk) begin

        //----------------------------------------------------------------------
        // RESET
        //----------------------------------------------------------------------

        if (reset) begin

            state            <= S_RESET;

            mole_position    <= 3'd0;

            req_counter      <= '0;

            was_hit          <= 1'b0;

            uart_pending     <= 1'b0;

            pending_position <= 3'd0;

        end

        //----------------------------------------------------------------------
        // FUNCIONAMIENTO NORMAL
        //----------------------------------------------------------------------

        else begin

            case (state)


                //--------------------------------------------------------------
                // S_RESET
                //
                // Estado transitorio de un ciclo.
                //--------------------------------------------------------------

                S_RESET: begin

                    req_counter <= '0;

                    was_hit <= 1'b0;

                    // No queremos conservar una respuesta UART
                    // de la partida anterior.
                    uart_pending <= 1'b0;

                    pending_position <= 3'd0;

                    state <= S_REQUEST;

                end


                //--------------------------------------------------------------
                // S_REQUEST
                //
                // mole_request está alto durante REQUEST_HOLD_MS.
                //
                // IMPORTANTE:
                // ahora también escuchamos data_valid mientras
                // mole_request permanece activo.
                //--------------------------------------------------------------

                S_REQUEST: begin


                    //----------------------------------------------------------
                    // Si la UART responde antes de que terminen los 5 ms,
                    // guardamos la posición.
                    //----------------------------------------------------------

                    if (data_valid) begin

                        pending_position <= data[2:0];

                        uart_pending <= 1'b1;

                    end


                    //----------------------------------------------------------
                    // Temporización de mole_request
                    //----------------------------------------------------------

                    if (tick_1ms) begin


                        //------------------------------------------------------
                        // Ya transcurrió REQUEST_HOLD_MS
                        //------------------------------------------------------

                        if (req_counter == REQUEST_HOLD_MS - 1) begin

                            req_counter <= '0;


                            //--------------------------------------------------
                            // CASO 1:
                            // data_valid llega exactamente en el mismo ciclo
                            // en que termina S_REQUEST.
                            //--------------------------------------------------

                            if (data_valid) begin

                                mole_position <= data[2:0];

                                uart_pending <= 1'b0;

                                state <= S_ACTIVE;

                            end


                            //--------------------------------------------------
                            // CASO 2:
                            // la UART respondió anteriormente mientras
                            // todavía estábamos en S_REQUEST.
                            //--------------------------------------------------

                            else if (uart_pending) begin

                                mole_position <= pending_position;

                                uart_pending <= 1'b0;

                                state <= S_ACTIVE;

                            end


                            //--------------------------------------------------
                            // CASO 3:
                            // todavía no hemos recibido respuesta.
                            //
                            // Entonces esperamos normalmente en WAIT_UART.
                            //--------------------------------------------------

                            else begin

                                state <= S_WAIT_UART;

                            end

                        end


                        //------------------------------------------------------
                        // Todavía no han pasado los 5 ms.
                        //------------------------------------------------------

                        else begin

                            req_counter <= req_counter + 1'b1;

                        end

                    end

                end


                //--------------------------------------------------------------
                // S_WAIT_UART
                //
                // Llegamos aquí únicamente si el circuito discreto
                // NO respondió durante S_REQUEST.
                //--------------------------------------------------------------

                S_WAIT_UART: begin

                    if (data_valid) begin

                        // Capturamos la posición.
                        mole_position <= data[2:0];

                        // Por seguridad limpiamos cualquier flag pendiente.
                        uart_pending <= 1'b0;

                        // Iniciamos el turno.
                        state <= S_ACTIVE;

                    end

                end


                //--------------------------------------------------------------
                // S_ACTIVE
                //
                // Turno activo.
                //--------------------------------------------------------------

                S_ACTIVE: begin


                    //----------------------------------------------------------
                    // HIT válido
                    //----------------------------------------------------------

                    if (hit_event) begin

                        was_hit <= 1'b1;

                        state <= S_EVALUATE;

                    end


                    //----------------------------------------------------------
                    // Botón incorrecto o timeout
                    //----------------------------------------------------------

                    else if (wrong_hit || timeout) begin

                        was_hit <= 1'b0;

                        state <= S_EVALUATE;

                    end

                end


                //--------------------------------------------------------------
                // S_EVALUATE
                //
                // Estado de un ciclo.
                //
                // Las señales count_hit/count_miss son Moore,
                // así que automáticamente se activan en este estado.
                //--------------------------------------------------------------

                S_EVALUATE: begin

                    state <= S_CHECK;

                end


                //--------------------------------------------------------------
                // S_CHECK
                //
                // Decide si continúa el juego o entra en GAME OVER.
                //--------------------------------------------------------------

                S_CHECK: begin

                    if (consecutive_misses >= 2'd3) begin

                        state <= S_GAMEOVER;

                    end

                    else begin

                        state <= S_REQUEST;

                    end

                end


                //--------------------------------------------------------------
                // S_GAMEOVER
                //--------------------------------------------------------------

                S_GAMEOVER: begin

                    if (game_over_done) begin

                        state <= S_RESET;

                    end

                end


                //--------------------------------------------------------------
                // Protección
                //--------------------------------------------------------------

                default: begin

                    state <= S_RESET;

                end


            endcase

        end

    end


endmodule