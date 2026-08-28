`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/18/2026 09:07:48 PM
// Design Name: 
// Module Name: sevenseg_driver
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//
// Controla el display de 4 digitos de 7 segmentos de la Basys 3 para
// mostrar los aciertos y los fallos de la partida. El display de la
// Basys 3 es de anodo comun con catodos compartidos entre los 4
// digitos (segun el manual de referencia), asi que solo se puede
// mostrar un digito fisico a la vez: la ilusion de ver los 4 al mismo
// tiempo se logra encendiendolos uno por uno muy rapido
// (multiplexado), aprovechando que el ojo humano no percibe el
// parpadeo por encima de ~60 Hz.
//
// Distribucion de los 4 digitos (de izquierda a derecha):
//   AN3 = decenas de aciertos    AN2 = unidades de aciertos
//   AN1 = decenas de fallos      AN0 = unidades de fallos
//
// Tanto los anodos (an) como los catodos (seg) son activos en bajo,
// tal como exige el hardware de la Basys 3 (ver manual de
// referencia, seccion 8.1).
// 
// Dependencies: 
// score_counters.sv (fuente de hits/misses), tick_gen.sv (fuente de
// tick_1ms)
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sevenseg_driver (

    // Reloj principal de 100 MHz.
    input  logic       clk,

    // Reset general del sistema.
    input  logic       reset,

    // Pulso de 1 ms proveniente de tick_gen.sv: se usa como base de
    // tiempo para decidir cuando cambiar de digito, sin crear ningun
    // reloj adicional.
    input  logic       tick_1ms,

    // Total de aciertos de la partida, 0 a 99 (viene de
    // score_counters.sv).
    input  logic [6:0] hits,

    // Total de fallos de la partida, 0 a 99 (viene de
    // score_counters.sv).
    input  logic [6:0] misses,

    // Catodos de los 7 segmentos, en el orden {a,b,c,d,e,f,g}. Activo
    // en bajo: un bit en 0 enciende ese segmento.
    output logic [6:0] seg,

    // Selector de digito (anodo), activo en bajo. Exactamente un bit
    // en 0 a la vez, indicando cual de los 4 digitos fisicos esta
    // recibiendo el patron de 'seg' en este instante.
    output logic [3:0] an

);

    //--------------------------------------------------------------------------
    // Descomposicion de hits y misses en digitos decimales
    //--------------------------------------------------------------------------

    // Como hits y misses van de 0 a 99, cada uno cabe exactamente en
    // dos digitos decimales. Dividir y sacar el resto entre 10 separa
    // las decenas de las unidades. Al ser hits/misses de solo 7 bits
    // (max 99), esta division por una constante es una operacion
    // pequena que Vivado sintetiza sin problema.
    logic [3:0] hits_tens;
    logic [3:0] hits_units;
    logic [3:0] misses_tens;
    logic [3:0] misses_units;

    // Bloque combinacional: se recalcula automaticamente cada vez que
    // hits o misses cambian, sin depender de un flanco de reloj.
    always_comb begin

        // Separamos las decenas y unidades de aciertos. Usamos un
        // cast explicito a 4 bits porque hits/misses van de 0 a 99,
        // asi que el cociente y el resto por 10 siempre caben en 4
        // bits (0-9); ser explicitos evita que el sintetizador (o
        // alguien leyendo el codigo) se pregunte si hay riesgo de
        // truncamiento de un valor mayor.
        hits_tens    = 4'(hits    / 10);
        hits_units   = 4'(hits    % 10);

        // Lo mismo para los fallos.
        misses_tens  = 4'(misses  / 10);
        misses_units = 4'(misses  % 10);

    end


    //--------------------------------------------------------------------------
    // Multiplexado de digitos
    //--------------------------------------------------------------------------

    // Recorre los 4 digitos en un ciclo de 2 bits (0,1,2,3,0,...).
    // Solo necesitamos 2 bits porque hay exactamente 4 digitos.
    logic [1:0] digit_sel;

    always_ff @(posedge clk) begin

        // El reset regresa siempre al primer digito del ciclo, para
        // que el multiplexado arranque de forma predecible.
        if (reset) begin

            digit_sel <= 2'd0;

        end
        // Solo avanzamos el selector de digito una vez por
        // milisegundo; el resto de los ciclos de reloj digit_sel se
        // mantiene igual (logica Moore para 'an' y 'seg' mas abajo).
        else if (tick_1ms) begin

            // Suma normal de 2 bits: al llegar a 3 (2'b11) se
            // desborda solo de vuelta a 0, completando el ciclo sin
            // necesidad de una condicion explicita.
            digit_sel <= digit_sel + 2'd1;

        end

    end


    //--------------------------------------------------------------------------
    // Seleccion del digito BCD activo y del anodo correspondiente
    //--------------------------------------------------------------------------

    // Digito decimal (0 a 9) que le corresponde mostrar al digito
    // fisico seleccionado en este instante.
    logic [3:0] active_digit;

    always_comb begin

        // Por defecto dejamos todos los anodos apagados (activo en
        // bajo, por lo que 1111 = ninguno encendido) y el digito en 0.
        // Esto solo se usaria si digit_sel tomara un valor fuera de
        // 0-3, lo cual no deberia ocurrir porque es un registro de
        // exactamente 2 bits.
        an           = 4'b1111;
        active_digit = 4'd0;

        case (digit_sel)

            // digit_sel = 0 -> unidades de fallos, digito fisico AN0.
            2'd0: begin
                an           = 4'b1110;
                active_digit = misses_units;
            end

            // digit_sel = 1 -> decenas de fallos, digito fisico AN1.
            2'd1: begin
                an           = 4'b1101;
                active_digit = misses_tens;
            end

            // digit_sel = 2 -> unidades de aciertos, digito fisico AN2.
            2'd2: begin
                an           = 4'b1011;
                active_digit = hits_units;
            end

            // digit_sel = 3 -> decenas de aciertos, digito fisico AN3.
            2'd3: begin
                an           = 4'b0111;
                active_digit = hits_tens;
            end

        endcase

    end


    //--------------------------------------------------------------------------
    // Decodificador BCD a 7 segmentos
    //--------------------------------------------------------------------------

    // Traduce un digito decimal (0-9) al patron de catodos activo en
    // bajo que enciende los segmentos correctos. Los patrones estan
    // en el orden {a,b,c,d,e,f,g} declarado en el puerto 'seg'.
    always_comb begin

        case (active_digit)

            // 0: encendidos a,b,c,d,e,f; apagado g.
            4'd0: seg = 7'b0000001;

            // 1: encendidos b,c; el resto apagados.
            4'd1: seg = 7'b1001111;

            // 2: encendidos a,b,g,e,d; apagados c,f.
            4'd2: seg = 7'b0010010;

            // 3: encendidos a,b,c,d,g; apagados e,f.
            4'd3: seg = 7'b0000110;

            // 4: encendidos f,g,b,c; apagados a,d,e.
            4'd4: seg = 7'b1001100;

            // 5: encendidos a,f,g,c,d; apagados b,e.
            4'd5: seg = 7'b0100100;

            // 6: encendidos a,f,g,e,d,c; apagado b.
            4'd6: seg = 7'b0100000;

            // 7: encendidos a,b,c; apagados d,e,f,g.
            4'd7: seg = 7'b0001111;

            // 8: los 7 segmentos encendidos.
            4'd8: seg = 7'b0000000;

            // 9: encendidos a,b,c,d,f,g; apagado e.
            4'd9: seg = 7'b0000100;

            // Proteccion defensiva: si por alguna razon active_digit
            // superara 9 (no deberia pasar, ya que hits/misses estan
            // limitados a 0-99 y la division por 10 nunca da un
            // resto mayor a 9), apagamos todos los segmentos en vez
            // de mostrar un patron indefinido.
            default: seg = 7'b1111111;

        endcase

    end

endmodule
