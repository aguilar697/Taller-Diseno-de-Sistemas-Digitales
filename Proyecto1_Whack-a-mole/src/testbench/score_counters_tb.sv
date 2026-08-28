`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.08.2026
// Design Name: Whack-a-Mole FPGA Game
// Module Name: score_counters_tb
// Project Name: project_1_fsm_game
// Target Devices: Basys 3 - Artix-7 XC7A35T-1CPG236C
// Tool Versions: Vivado 2026.1
// Description:
//
// Testbench autoverificable para score_counters.
//
// Se comprueba:
//   1. Inicialización de todos los contadores en cero.
//   2. Incremento correcto del contador de aciertos.
//   3. Incremento de fallos acumulados y consecutivos.
//   4. Reinicio de fallos consecutivos después de un HIT.
//   5. Detección del tercer fallo consecutivo.
//   6. Saturación de consecutive_misses en 3.
//   7. Saturación de hits y misses en 99.
//   8. Reinicio completo mediante reset.
//
// Dependencies:
// score_counters.sv
//
// Revision:
// Revision 0.01 - File Created
//////////////////////////////////////////////////////////////////////////////////


module score_counters_tb;


    //--------------------------------------------------------------------------
    // Señales
    //--------------------------------------------------------------------------

    logic       clk;
    logic       reset;

    logic       count_hit;
    logic       count_miss;

    logic [6:0] hits;
    logic [6:0] misses;

    logic [1:0] consecutive_misses;


    //--------------------------------------------------------------------------
    // Reloj
    //--------------------------------------------------------------------------

    localparam time CLK_PERIOD = 10ns;


    //--------------------------------------------------------------------------
    // DUT
    //--------------------------------------------------------------------------

    score_counters dut (

        .clk                (clk),
        .reset              (reset),

        .count_hit          (count_hit),
        .count_miss         (count_miss),

        .hits               (hits),
        .misses             (misses),
        .consecutive_misses (consecutive_misses)

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
    // Tarea para registrar un HIT
    //--------------------------------------------------------------------------

    task automatic generate_hit;

        begin

            @(negedge clk);

            count_hit  = 1'b1;
            count_miss = 1'b0;

            @(negedge clk);

            count_hit = 1'b0;

            #1ns;

        end

    endtask


    //--------------------------------------------------------------------------
    // Tarea para registrar un MISS
    //--------------------------------------------------------------------------

    task automatic generate_miss;

        begin

            @(negedge clk);

            count_hit  = 1'b0;
            count_miss = 1'b1;

            @(negedge clk);

            count_miss = 1'b0;

            #1ns;

        end

    endtask


    //--------------------------------------------------------------------------
    // Secuencia principal
    //--------------------------------------------------------------------------

    initial begin

        integer i;


        //----------------------------------------------------------------------
        // Inicialización
        //----------------------------------------------------------------------

        reset      = 1'b1;
        count_hit  = 1'b0;
        count_miss = 1'b0;

        repeat (3)
            @(posedge clk);

        @(negedge clk);

        reset = 1'b0;

        #1ns;


        //----------------------------------------------------------------------
        // PRUEBA 1
        // Todos los contadores deben comenzar en cero.
        //----------------------------------------------------------------------

        if ((hits !== 7'd0) ||
            (misses !== 7'd0) ||
            (consecutive_misses !== 2'd0)) begin

            $error(
                "ERROR: los contadores no iniciaron en cero"
            );

        end
        else begin

            $display(
                "PASS: contadores inicializados en cero"
            );

        end


        //----------------------------------------------------------------------
        // PRUEBA 2
        // Primer HIT
        //----------------------------------------------------------------------

        generate_hit();


        if ((hits !== 7'd1) ||
            (misses !== 7'd0) ||
            (consecutive_misses !== 2'd0)) begin

            $error(
                "ERROR: primer HIT incorrecto"
            );

        end
        else begin

            $display(
                "PASS: HIT incrementa correctamente hits"
            );

        end


        //----------------------------------------------------------------------
        // PRUEBA 3
        // Dos fallos consecutivos.
        //----------------------------------------------------------------------

        generate_miss();
        generate_miss();


        if ((misses !== 7'd2) ||
            (consecutive_misses !== 2'd2)) begin

            $error(
                "ERROR: dos MISS no fueron contabilizados correctamente"
            );

        end
        else begin

            $display(
                "PASS: fallos acumulados y consecutivos correctos"
            );

        end


        //----------------------------------------------------------------------
        // PRUEBA 4
        // Un HIT debe reiniciar consecutive_misses,
        // pero NO debe borrar misses.
        //----------------------------------------------------------------------

        generate_hit();


        if ((hits !== 7'd2) ||
            (misses !== 7'd2) ||
            (consecutive_misses !== 2'd0)) begin

            $error(
                "ERROR: HIT no reinicio correctamente los fallos consecutivos"
            );

        end
        else begin

            $display(
                "PASS: HIT reinicia solo los fallos consecutivos"
            );

        end


        //----------------------------------------------------------------------
        // PRUEBA 5
        // Tres fallos consecutivos.
        //----------------------------------------------------------------------

        generate_miss();
        generate_miss();
        generate_miss();


        if ((misses !== 7'd5) ||
            (consecutive_misses !== 2'd3)) begin

            $error(
                "ERROR: tercer fallo consecutivo incorrecto"
            );

        end
        else begin

            $display(
                "PASS: tercer fallo consecutivo correctamente detectado"
            );

        end


        //----------------------------------------------------------------------
        // PRUEBA 6
        // Un cuarto MISS no debe llevar consecutive_misses a cero.
        // Debe permanecer saturado en 3.
        //----------------------------------------------------------------------

        generate_miss();


        if (consecutive_misses !== 2'd3) begin

            $error(
                "ERROR: consecutive_misses no permanecio saturado en 3"
            );

        end
        else begin

            $display(
                "PASS: fallos consecutivos permanecen saturados en 3"
            );

        end


        //----------------------------------------------------------------------
        // PRUEBA 7
        // Saturación del contador de hits en 99.
        //
        // Primero un HIT también eliminará la condición de fallos consecutivos.
        //----------------------------------------------------------------------

        for (i = hits; i < 105; i = i + 1)
            generate_hit();


        if (hits !== 7'd99) begin

            $error(
                "ERROR: hits no se saturo en 99. Valor = %0d",
                hits
            );

        end
        else begin

            $display(
                "PASS: hits permanece saturado en 99"
            );

        end


        //----------------------------------------------------------------------
        // PRUEBA 8
        // Saturación del contador de misses en 99.
        //----------------------------------------------------------------------

        for (i = misses; i < 105; i = i + 1)
            generate_miss();


        if (misses !== 7'd99) begin

            $error(
                "ERROR: misses no se saturo en 99. Valor = %0d",
                misses
            );

        end
        else begin

            $display(
                "PASS: misses permanece saturado en 99"
            );

        end


        //----------------------------------------------------------------------
        // PRUEBA 9
        // Reset general.
        //----------------------------------------------------------------------

        @(negedge clk);

        reset = 1'b1;

        @(posedge clk);

        #1ns;


        if ((hits !== 7'd0) ||
            (misses !== 7'd0) ||
            (consecutive_misses !== 2'd0)) begin

            $error(
                "ERROR: reset no limpio todos los contadores"
            );

        end
        else begin

            $display(
                "PASS: reset limpia todos los contadores"
            );

        end


        //----------------------------------------------------------------------
        // Fin
        //----------------------------------------------------------------------

        $display(
            "-----------------------------------------"
        );

        $display(
            "TODAS LAS PRUEBAS score_counters PASARON"
        );

        $display(
            "-----------------------------------------"
        );


        #20ns;

        $finish;

    end

endmodule