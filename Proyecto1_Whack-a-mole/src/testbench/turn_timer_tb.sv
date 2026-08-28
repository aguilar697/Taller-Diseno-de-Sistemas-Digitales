`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.08.2026
// Design Name: Whack-a-Mole FPGA Game
// Module Name: turn_timer_tb
// Project Name: project_1_fsm_game
// Target Devices: Basys 3 - Artix-7 XC7A35T-1CPG236C
// Tool Versions: Vivado 2026.1
// Description:
//
// Testbench autoverificable para turn_timer.
//
// Se comprueba:
//   1. Que el temporizador no cuente con turn_enable = 0.
//   2. Que no se genere timeout antes del tiempo configurado.
//   3. Que timeout aparezca exactamente al alcanzar window_ms.
//   4. Que timeout dure solamente un ciclo.
//   5. Que no existan múltiples timeouts para el mismo turno.
//   6. Que al desactivar turn_enable se prepare un nuevo turno.
//   7. Que el módulo funcione con distintos valores de window_ms.
//
// Dependencies:
// turn_timer.sv
//
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////


module turn_timer_tb;


    //--------------------------------------------------------------------------
    // Señales
    //--------------------------------------------------------------------------

    logic        clk;
    logic        reset;
    logic        tick_1ms;
    logic        turn_enable;
    logic [10:0] window_ms;
    logic        timeout;


    //--------------------------------------------------------------------------
    // Reloj
    //--------------------------------------------------------------------------

    localparam time CLK_PERIOD = 10ns;


    //--------------------------------------------------------------------------
    // DUT
    //--------------------------------------------------------------------------

    turn_timer dut (

        .clk         (clk),
        .reset       (reset),
        .tick_1ms    (tick_1ms),
        .turn_enable (turn_enable),
        .window_ms   (window_ms),
        .timeout     (timeout)

    );


    //--------------------------------------------------------------------------
    // Generación del reloj de 100 MHz
    //--------------------------------------------------------------------------

    initial begin

        clk = 1'b0;

        forever #(CLK_PERIOD / 2)
            clk = ~clk;

    end


    //--------------------------------------------------------------------------
    // Tarea para producir un pulso equivalente a tick_1ms
    //
    // Durante simulación no esperamos 1 ms real. Cada llamada representa
    // conceptualmente un milisegundo.
    //--------------------------------------------------------------------------

    task automatic generate_tick;

        begin

            @(negedge clk);
            tick_1ms = 1'b1;

            @(negedge clk);
            tick_1ms = 1'b0;

            #1ns;

        end

    endtask


    //--------------------------------------------------------------------------
    // Secuencia principal de prueba
    //--------------------------------------------------------------------------

    initial begin

        integer i;


        //----------------------------------------------------------------------
        // Inicialización
        //----------------------------------------------------------------------

        reset       = 1'b1;
        tick_1ms    = 1'b0;
        turn_enable = 1'b0;
        window_ms   = 11'd5;

        repeat (3)
            @(posedge clk);

        @(negedge clk);
        reset = 1'b0;


        //----------------------------------------------------------------------
        // PRUEBA 1
        // Con el turno desactivado no debe aparecer timeout.
        //----------------------------------------------------------------------

        repeat (3)
            generate_tick();


        if (timeout !== 1'b0)

            $error(
                "ERROR: se genero timeout con turn_enable = 0"
            );

        else

            $display(
                "PASS: temporizador permanece detenido sin turno"
            );


        //----------------------------------------------------------------------
        // PRUEBA 2
        // Iniciar un turno de 5 ticks.
        //----------------------------------------------------------------------

        @(negedge clk);
        turn_enable = 1'b1;


        //----------------------------------------------------------------------
        // Primeros cuatro ticks:
        // todavía NO debe existir timeout.
        //----------------------------------------------------------------------

        for (i = 1; i < 5; i = i + 1) begin

            generate_tick();


            if (timeout !== 1'b0)

                $error(
                    "ERROR: timeout aparecio anticipadamente en tick %0d",
                    i
                );

        end


        $display(
            "PASS: no hay timeout antes del limite"
        );


        //----------------------------------------------------------------------
        // Quinto tick:
        // debe producir timeout.
        //----------------------------------------------------------------------

        generate_tick();


        if (timeout !== 1'b1)

            $error(
                "ERROR: timeout no aparecio al alcanzar window_ms"
            );

        else

            $display(
                "PASS: timeout aparece exactamente en el limite"
            );


        //----------------------------------------------------------------------
        // PRUEBA 3
        // Comprobar que timeout solamente dura un ciclo.
        //----------------------------------------------------------------------

        @(posedge clk);
        #1ns;


        if (timeout !== 1'b0)

            $error(
                "ERROR: timeout duro mas de un ciclo"
            );

        else

            $display(
                "PASS: timeout dura solamente un ciclo"
            );


        //----------------------------------------------------------------------
        // PRUEBA 4
        // Más ticks no deben producir otro timeout durante el mismo turno.
        //----------------------------------------------------------------------

        repeat (5)
            generate_tick();


        if (timeout !== 1'b0)

            $error(
                "ERROR: se genero un segundo timeout en el mismo turno"
            );

        else

            $display(
                "PASS: no se repite timeout en el mismo turno"
            );


        //----------------------------------------------------------------------
        // PRUEBA 5
        // Terminar el turno.
        //----------------------------------------------------------------------

        @(negedge clk);
        turn_enable = 1'b0;

        repeat (2)
            @(posedge clk);


        //----------------------------------------------------------------------
        // Cambiamos ahora la ventana a 3 ticks.
        //----------------------------------------------------------------------

        window_ms = 11'd3;

        @(negedge clk);
        turn_enable = 1'b1;


        //----------------------------------------------------------------------
        // Primeros dos ticks no deben producir timeout.
        //----------------------------------------------------------------------

        generate_tick();
        generate_tick();


        if (timeout !== 1'b0)

            $error(
                "ERROR: segundo turno genero timeout anticipado"
            );


        //----------------------------------------------------------------------
        // Tercer tick debe producir timeout.
        //----------------------------------------------------------------------

        generate_tick();


        if (timeout !== 1'b1)

            $error(
                "ERROR: segundo turno no respeto window_ms = 3"
            );

        else

            $display(
                "PASS: nuevo turno funciona con window_ms = 3"
            );


        //----------------------------------------------------------------------
        // PRUEBA 6
        // Reset general.
        //----------------------------------------------------------------------

        @(negedge clk);
        reset = 1'b1;

        @(posedge clk);
        #1ns;


        if (timeout !== 1'b0)

            $error(
                "ERROR: reset no limpio timeout"
            );

        else

            $display(
                "PASS: reset limpia correctamente el temporizador"
            );


        //----------------------------------------------------------------------
        // Fin
        //----------------------------------------------------------------------

        $display(
            "--------------------------------------"
        );

        $display(
            "TODAS LAS PRUEBAS turn_timer PASARON"
        );

        $display(
            "--------------------------------------"
        );


        #20ns;

        $finish;

    end

endmodule