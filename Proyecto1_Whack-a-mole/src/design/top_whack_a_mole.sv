`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/18/2026 09:26:26 PM
// Design Name: 
// Module Name: top_whack_a_mole
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//
// Modulo de nivel superior (top) del subsistema FPGA del Whack-a-Mole.
// Instancia y conecta los 11 modulos del proyecto:
//
//   tick_gen          -> base de tiempo de 1 ms compartida por todo el diseno
//   uart_rx           -> recibe la posicion del topo desde el circuito discreto
//   buttons_frontend   -> sincroniza, filtra rebotes y detecta flancos de
//                         los 8 botones externos del jugador
//   hit_evaluator      -> compara el boton presionado con la posicion activa
//   difficulty_ctrl    -> reduce la ventana de tiempo tras cada acierto
//   turn_timer         -> controla cuanto dura activo cada turno
//   score_counters     -> lleva aciertos, fallos y fallos consecutivos
//   game_over_timer    -> sostiene la pantalla de GAME OVER un minimo de tiempo
//   game_fsm           -> coordina todo lo anterior (el "cerebro" del juego)
//   sevenseg_driver     -> multiplexa aciertos/fallos en los 4 displays
//
// Dependencies:
// tick_gen.sv, uart_rx.sv, button_conditioner.sv, buttons_frontend.sv,
// hit_evaluator.sv, difficulty_ctrl.sv, turn_timer.sv, score_counters.sv,
// game_over_timer.sv, game_fsm.sv, sevenseg_driver.sv
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// Los parametros de este modulo tienen como valor por defecto los
// numeros reales de hardware (100 MHz, 9600 baudios, ticks de 1 ms,
// etc.). El testbench de integracion (top_whack_a_mole_tb.sv) los
// sobreescribe con valores mas pequenos unicamente para que la
// simulacion corra rapido; la logica interna es exactamente la misma
// en ambos casos.
//
// La distribucion del reset sigue la regla acordada durante el
// diseno de game_fsm.sv: los modulos que NO guardan progreso de la
// partida (tick_gen, uart_rx, buttons_frontend, sevenseg_driver, la
// propia game_fsm) se resetean solo con reset_btn. Los modulos que SI
// guardan progreso de la partida (score_counters, difficulty_ctrl,
// turn_timer, game_over_timer) se resetean con system_reset, que
// combina reset_btn con new_game_pulse. Esto es lo que permite que la
// partida se reinicie automaticamente por completo tras un GAME OVER,
// sin depender de que el usuario presione el boton fisico.
//
//////////////////////////////////////////////////////////////////////////////////


module top_whack_a_mole #(

    // Frecuencia real del reloj de la Basys 3 (pin W5).
    parameter int CLK_FREQ       = 100_000_000,

    // Velocidad del enlace UART con el circuito discreto.
    parameter int BAUD_RATE      = 9600,

    // Frecuencia de la base de tiempo interna (1000 Hz = tick cada 1 ms).
    parameter int TICK_HZ        = 1000,

    // Cantidad de ticks de 1 ms que debe mantenerse estable un boton
    // antes de aceptarlo como pulsacion valida (filtro de rebotes).
    parameter int DEBOUNCE_TICKS = 20,

    // Milisegundos que se sostiene mole_request en alto para que el
    // circuito discreto lo detecte de forma confiable.
    parameter int REQUEST_HOLD_MS = 5,

    // Milisegundos minimos que permanece la pantalla de GAME OVER.
    parameter int GAME_OVER_MS    = 2000

)(

    // Reloj principal de 100 MHz (pin W5 en la Basys 3).
    input  logic       clk,

    // Boton fisico de reset (por ejemplo BTNC), ya acondicionado.
    input  logic       reset_btn,

    // 8 pulsadores externos del jugador, conectados por Pmod (no se
    // usan los 5 botones integrados de la tarjeta, segun exige el
    // instructivo del proyecto).
    input  logic [7:0] hit_buttons,

    // Linea serial UART proveniente del circuito discreto (TX del
    // protoboard), conectada por Pmod.
    input  logic       serial_data,

    // Hacia el circuito discreto: solicita una nueva posicion de topo.
    output logic       mole_request,

    // Catodos de los 7 segmentos, orden {a,b,c,d,e,f,g}, activo en bajo.
    output logic [6:0] seg,

    // Anodos (seleccion de digito), activo en bajo.
    output logic [3:0] an,

    // LED de estado: 1 = GAME OVER, 0 = partida activa.
    output logic       game_status_led

);

    //--------------------------------------------------------------------------
    // Reset combinado para los modulos que guardan progreso de partida
    //--------------------------------------------------------------------------

    // new_game_pulse (generado por game_fsm) se combina con reset_btn
    // para que score_counters, difficulty_ctrl, turn_timer y
    // game_over_timer arranquen limpios tanto en un reset manual como
    // en el reinicio automatico tras GAME OVER.
    logic new_game_pulse;
    logic system_reset;

    assign system_reset = reset_btn | new_game_pulse;


    //--------------------------------------------------------------------------
    // Senales internas que conectan los modulos entre si
    //--------------------------------------------------------------------------

    logic tick_1ms;

    logic [7:0] uart_data;
    logic       uart_data_valid;

    logic [7:0] press_pulse;

    logic [2:0] mole_position;

    logic hit_event;
    logic wrong_hit;

    logic [10:0] window_ms;

    logic turn_enable;

    logic timeout;

    logic count_hit;
    logic count_miss;
    logic hit_update;

    logic [6:0] hits;
    logic [6:0] misses;
    logic [1:0] consecutive_misses;

    logic game_over_enable;
    logic game_over_done;


    //--------------------------------------------------------------------------
    // Base de tiempo de 1 ms
    //--------------------------------------------------------------------------

    tick_gen #(
        .CLK_FREQ (CLK_FREQ),
        .TICK_HZ  (TICK_HZ)
    ) tick_gen_inst (
        .clk   (clk),
        .reset (reset_btn),
        .tick  (tick_1ms)
    );


    //--------------------------------------------------------------------------
    // Receptor UART (posicion del topo desde el circuito discreto)
    //--------------------------------------------------------------------------

    uart_rx #(
        .CLK_FREQ  (CLK_FREQ),
        .BAUD_RATE (BAUD_RATE)
    ) uart_rx_inst (
        .clk         (clk),
        .reset       (reset_btn),
        .serial_data (serial_data),
        .data        (uart_data),
        .data_valid  (uart_data_valid)
    );


    //--------------------------------------------------------------------------
    // Acondicionamiento de los 8 botones del jugador
    //--------------------------------------------------------------------------

    buttons_frontend #(
        .DEBOUNCE_TICKS (DEBOUNCE_TICKS)
    ) buttons_frontend_inst (
        .clk           (clk),
        .reset         (reset_btn),
        .tick_1ms      (tick_1ms),
        .buttons_in    (hit_buttons),
        .buttons_level (),
        .press_pulse   (press_pulse)
    );


    //--------------------------------------------------------------------------
    // Evaluador de golpe (combinacional, sin reset)
    //--------------------------------------------------------------------------

    hit_evaluator hit_evaluator_inst (
        .mole_position (mole_position),
        .press_pulse   (press_pulse),
        .hit_event     (hit_event),
        .wrong_hit     (wrong_hit),
        .any_press     ()
    );


    //--------------------------------------------------------------------------
    // Control de dificultad
    //--------------------------------------------------------------------------

    difficulty_ctrl difficulty_ctrl_inst (
        .clk        (clk),
        .reset      (system_reset),
        .hit_update (hit_update),
        .window_ms  (window_ms)
    );


    //--------------------------------------------------------------------------
    // Temporizador de turno
    //--------------------------------------------------------------------------

    turn_timer turn_timer_inst (
        .clk         (clk),
        .reset       (system_reset),
        .tick_1ms    (tick_1ms),
        .turn_enable (turn_enable),
        .window_ms   (window_ms),
        .timeout     (timeout)
    );


    //--------------------------------------------------------------------------
    // Contadores de aciertos y fallos
    //--------------------------------------------------------------------------

    score_counters score_counters_inst (
        .clk                (clk),
        .reset              (system_reset),
        .count_hit          (count_hit),
        .count_miss         (count_miss),
        .hits               (hits),
        .misses             (misses),
        .consecutive_misses (consecutive_misses)
    );


    //--------------------------------------------------------------------------
    // Temporizador de GAME OVER
    //--------------------------------------------------------------------------

    game_over_timer #(
        .GAME_OVER_MS (GAME_OVER_MS)
    ) game_over_timer_inst (
        .clk              (clk),
        .reset            (system_reset),
        .tick_1ms         (tick_1ms),
        .game_over_enable (game_over_enable),
        .game_over_done   (game_over_done)
    );


    //--------------------------------------------------------------------------
    // FSM principal del juego
    //--------------------------------------------------------------------------

    game_fsm #(
        .REQUEST_HOLD_MS (REQUEST_HOLD_MS)
    ) game_fsm_inst (
        .clk                (clk),
        .reset              (reset_btn),
        .tick_1ms           (tick_1ms),
        .data               (uart_data),
        .data_valid         (uart_data_valid),
        .hit_event          (hit_event),
        .wrong_hit          (wrong_hit),
        .timeout            (timeout),
        .consecutive_misses (consecutive_misses),
        .game_over_done     (game_over_done),
        .mole_request       (mole_request),
        .mole_position      (mole_position),
        .turn_enable        (turn_enable),
        .count_hit          (count_hit),
        .count_miss         (count_miss),
        .hit_update         (hit_update),
        .game_over_enable   (game_over_enable),
        .game_status_led    (game_status_led),
        .new_game_pulse     (new_game_pulse)
    );


    //--------------------------------------------------------------------------
    // Controlador de displays de 7 segmentos
    //--------------------------------------------------------------------------

    sevenseg_driver sevenseg_driver_inst (
        .clk      (clk),
        .reset    (reset_btn),
        .tick_1ms (tick_1ms),
        .hits     (hits),
        .misses   (misses),
        .seg      (seg),
        .an       (an)
    );

endmodule
