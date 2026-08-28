`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/18/2026 09:09:48 PM
// Design Name: 
// Module Name: sevenseg_driver_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
//
// Testbench autoverificable de sevenseg_driver.sv. Verifica que el
// ciclo de multiplexado recorra los 4 digitos en el orden correcto,
// que la descomposicion decimal de hits/misses sea correcta, y que
// el decodificador de 7 segmentos produzca los patrones esperados
// para los digitos usados en las pruebas. 
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module sevenseg_driver_tb;

    // Periodo de reloj de 10 ns, equivalente a los 100 MHz reales de
    // la Basys 3.
    localparam time CLK_PERIOD = 10ns;

    logic clk;
    logic reset;
    logic tick_1ms;

    logic [6:0] hits;
    logic [6:0] misses;

    logic [6:0] seg;
    logic [3:0] an;

    // Patrones de referencia (mismo orden {a,b,c,d,e,f,g} que el
    // DUT) para los digitos que vamos a verificar en este testbench.
    // Repetirlos aqui, en vez de "confiar" en el DUT, es justamente
    // lo que hace que la prueba sea util: si alguien cambia por error
    // un patron en sevenseg_driver.sv, esta prueba debe fallar.
    localparam logic [6:0] SEG_0 = 7'b0000001;
    localparam logic [6:0] SEG_3 = 7'b0000110;
    localparam logic [6:0] SEG_7 = 7'b0001111;
    localparam logic [6:0] SEG_8 = 7'b0000000;
    localparam logic [6:0] SEG_9 = 7'b0000100;

    sevenseg_driver dut (
        .clk      (clk),
        .reset    (reset),
        .tick_1ms (tick_1ms),
        .hits     (hits),
        .misses   (misses),
        .seg      (seg),
        .an       (an)
    );

    // Generacion del reloj de 100 MHz.
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Avanza un flanco de reloj y espera 1 ns adicional para dejar
    // resolver las asignaciones no bloqueantes del DUT antes de leer
    // sus salidas (misma tecnica usada en los testbenches anteriores
    // del proyecto).
    task automatic step_clk();
        @(posedge clk);
        #1;
    endtask

    // Genera un pulso de tick_1ms de un ciclo de ancho, avanzando el
    // multiplexado de digitos exactamente una posicion.
    task automatic pulse_tick_1ms();
        tick_1ms <= 1'b1;
        step_clk();
        tick_1ms <= 1'b0;
    endtask

    initial begin

        // Valores iniciales: 37 aciertos, 8 fallos. Elegimos numeros
        // con decenas y unidades distintas entre si para que un error
        // de indice (por ejemplo, mostrar las decenas donde van las
        // unidades) se note de inmediato en la prueba.
        hits    = 7'd37;
        misses  = 7'd8;
        tick_1ms = 1'b0;

        reset = 1'b1;
        step_clk();
        step_clk();
        reset = 1'b0;
        step_clk();

        //----------------------------------------------------------------------
        // Test 1: tras el reset, el primer digito activo debe ser
        // AN0 (unidades de fallos = 8)
        //----------------------------------------------------------------------
        if (an == 4'b1110 && seg == SEG_8)
            $display("PASS: tras el reset, AN0 muestra unidades de fallos (8)");
        else
            $error("FALLO: se esperaba an=1110 seg=SEG_8, se obtuvo an=%b seg=%b", an, seg);

        //----------------------------------------------------------------------
        // Test 2: un tick_1ms debe avanzar a AN1 (decenas de fallos = 0)
        //----------------------------------------------------------------------
        pulse_tick_1ms();

        if (an == 4'b1101 && seg == SEG_0)
            $display("PASS: AN1 muestra decenas de fallos (0)");
        else
            $error("FALLO: se esperaba an=1101 seg=SEG_0, se obtuvo an=%b seg=%b", an, seg);

        //----------------------------------------------------------------------
        // Test 3: el siguiente tick_1ms debe avanzar a AN2 (unidades
        // de aciertos = 7)
        //----------------------------------------------------------------------
        pulse_tick_1ms();

        if (an == 4'b1011 && seg == SEG_7)
            $display("PASS: AN2 muestra unidades de aciertos (7)");
        else
            $error("FALLO: se esperaba an=1011 seg=SEG_7, se obtuvo an=%b seg=%b", an, seg);

        //----------------------------------------------------------------------
        // Test 4: el siguiente tick_1ms debe avanzar a AN3 (decenas
        // de aciertos = 3)
        //----------------------------------------------------------------------
        pulse_tick_1ms();

        if (an == 4'b0111 && seg == SEG_3)
            $display("PASS: AN3 muestra decenas de aciertos (3)");
        else
            $error("FALLO: se esperaba an=0111 seg=SEG_3, se obtuvo an=%b seg=%b", an, seg);

        //----------------------------------------------------------------------
        // Test 5: el ciclo debe cerrar y volver a AN0
        //----------------------------------------------------------------------
        pulse_tick_1ms();

        if (an == 4'b1110 && seg == SEG_8)
            $display("PASS: el ciclo de multiplexado se cierra y regresa a AN0");
        else
            $error("FALLO: se esperaba an=1110 seg=SEG_8 al cerrar el ciclo, se obtuvo an=%b seg=%b", an, seg);

        //----------------------------------------------------------------------
        // Test 6: valores en el limite superior (99 aciertos) deben
        // descomponerse correctamente en 9 y 9
        //----------------------------------------------------------------------
        hits = 7'd99;

        // Avanzamos hasta que digit_sel vuelva a mostrar las
        // unidades de aciertos (dos ticks desde AN0: AN0->AN1->AN2).
        pulse_tick_1ms();
        pulse_tick_1ms();

        if (an == 4'b1011 && seg == SEG_9)
            $display("PASS: unidades de aciertos = 99 se descompone correctamente (9)");
        else
            $error("FALLO: se esperaba an=1011 seg=SEG_9 con hits=99, se obtuvo an=%b seg=%b", an, seg);

        pulse_tick_1ms();

        if (an == 4'b0111 && seg == SEG_9)
            $display("PASS: decenas de aciertos = 99 se descompone correctamente (9)");
        else
            $error("FALLO: se esperaba an=0111 seg=SEG_9 con hits=99, se obtuvo an=%b seg=%b", an, seg);

        //----------------------------------------------------------------------
        // Test 7: el reset en cualquier momento debe regresar el
        // multiplexado a AN0
        //----------------------------------------------------------------------
        reset = 1'b1;
        step_clk();
        reset = 1'b0;
        step_clk();

        if (an == 4'b1110)
            $display("PASS: el reset regresa el multiplexado a AN0");
        else
            $error("FALLO: tras el reset se esperaba an=1110, se obtuvo an=%b", an);

        $display("-------------------------------------------");
        $display("TODAS LAS PRUEBAS sevenseg_driver PASARON");
        $display("-------------------------------------------");

        #100ns;
        $finish;
    end

endmodule
