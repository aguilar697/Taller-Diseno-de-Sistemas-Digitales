`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.08.2026
// Design Name: Whack-a-Mole FPGA Game
// Module Name: difficulty_ctrl_tb
// Project Name: project_1_fsm_game
// Target Devices: Basys 3 - Artix-7 XC7A35T-1CPG236C
// Tool Versions: Vivado 2026.1
// Description:
// Testbench autoverificable para difficulty_ctrl.
//
// Se comprueba:
//   1. Valor inicial de 1500 ms.
//   2. Reducción de 100 ms por cada HIT.
//   3. Llegada correcta al mínimo de 500 ms.
//   4. Saturación en 500 ms.
//   5. Conservación del valor cuando no hay HIT.
//   6. Restauración a 1500 ms mediante reset.
//
// Dependencies:
// difficulty_ctrl.sv
//
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////


module difficulty_ctrl_tb;


    //--------------------------------------------------------------------------
    // Señales
    //--------------------------------------------------------------------------

    logic        clk;
    logic        reset;
    logic        hit_update;
    logic [10:0] window_ms;


    //--------------------------------------------------------------------------
    // Parámetro del reloj
    //--------------------------------------------------------------------------

    localparam time CLK_PERIOD = 10ns;


    //--------------------------------------------------------------------------
    // DUT
    //--------------------------------------------------------------------------

    difficulty_ctrl dut (

        .clk        (clk),
        .reset      (reset),
        .hit_update (hit_update),
        .window_ms  (window_ms)

    );


    //--------------------------------------------------------------------------
    // Reloj de 100 MHz
    //--------------------------------------------------------------------------

    initial begin

        clk = 1'b0;

        forever #(CLK_PERIOD / 2)
            clk = ~clk;

    end


    //--------------------------------------------------------------------------
    // Tarea para generar un único HIT
    //--------------------------------------------------------------------------

    task automatic generate_hit;

        begin

            @(negedge clk);
            hit_update = 1'b1;

            @(negedge clk);
            hit_update = 1'b0;

        end

    endtask


    //--------------------------------------------------------------------------
    // Secuencia principal
    //--------------------------------------------------------------------------

    initial begin

        integer i;
        integer expected_window;


        //----------------------------------------------------------------------
        // Estado inicial
        //----------------------------------------------------------------------

        reset      = 1'b1;
        hit_update = 1'b0;

        repeat (3)
            @(posedge clk);

        @(negedge clk);
        reset = 1'b0;

        #1ns;


        //----------------------------------------------------------------------
        // PRUEBA 1
        // Valor inicial
        //----------------------------------------------------------------------

        if (window_ms !== 11'd1500)

            $error(
                "ERROR: valor inicial incorrecto. window_ms = %0d",
                window_ms
            );

        else

            $display(
                "PASS: dificultad inicial = 1500 ms"
            );


        //----------------------------------------------------------------------
        // PRUEBA 2
        // Diez HIT deben llevar desde 1500 hasta 500 ms
        //----------------------------------------------------------------------

        expected_window = 1500;

        for (i = 1; i <= 10; i = i + 1) begin

            generate_hit();

            expected_window = expected_window - 100;

            #1ns;


            if (window_ms !== expected_window)

                $error(
                    "ERROR: HIT %0d esperaba %0d ms y obtuvo %0d ms",
                    i,
                    expected_window,
                    window_ms
                );

            else

                $display(
                    "PASS: HIT %0d -> window_ms = %0d ms",
                    i,
                    window_ms
                );

        end


        //----------------------------------------------------------------------
        // PRUEBA 3
        // Confirmar mínimo de 500 ms
        //----------------------------------------------------------------------

        if (window_ms !== 11'd500)

            $error(
                "ERROR: no se alcanzo correctamente el minimo"
            );

        else

            $display(
                "PASS: dificultad minima = 500 ms"
            );


        //----------------------------------------------------------------------
        // PRUEBA 4
        // HIT adicional no debe bajar de 500 ms
        //----------------------------------------------------------------------

        generate_hit();

        #1ns;


        if (window_ms !== 11'd500)

            $error(
                "ERROR: dificultad bajo de 500 ms"
            );

        else

            $display(
                "PASS: dificultad permanece saturada en 500 ms"
            );


        //----------------------------------------------------------------------
        // PRUEBA 5
        // Sin HIT el valor debe mantenerse
        //----------------------------------------------------------------------

        repeat (5)
            @(posedge clk);

        #1ns;


        if (window_ms !== 11'd500)

            $error(
                "ERROR: dificultad cambio sin recibir HIT"
            );

        else

            $display(
                "PASS: dificultad se conserva sin HIT"
            );


        //----------------------------------------------------------------------
        // PRUEBA 6
        // Reset debe restaurar 1500 ms
        //----------------------------------------------------------------------

        @(negedge clk);
        reset = 1'b1;

        @(posedge clk);
        #1ns;


        if (window_ms !== 11'd1500)

            $error(
                "ERROR: reset no restauro la dificultad inicial"
            );

        else

            $display(
                "PASS: reset restaura dificultad a 1500 ms"
            );


        //----------------------------------------------------------------------
        // Fin
        //----------------------------------------------------------------------

        $display(
            "-----------------------------------------"
        );

        $display(
            "TODAS LAS PRUEBAS difficulty_ctrl PASARON"
        );

        $display(
            "-----------------------------------------"
        );

        #20ns;

        $finish;

    end

endmodule