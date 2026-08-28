`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/18/2026 08:01:49 PM
// Design Name: 
// Module Name: game_over_timer_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module game_over_timer_tb;

    localparam int  GAME_OVER_MS_TEST = 5;
    localparam time CLK_PERIOD        = 10ns;

    logic clk;
    logic reset;
    logic tick_1ms;
    logic game_over_enable;
    logic game_over_done;

    game_over_timer #(
        .GAME_OVER_MS(GAME_OVER_MS_TEST)
    ) dut (
        .clk              (clk),
        .reset            (reset),
        .tick_1ms         (tick_1ms),
        .game_over_enable (game_over_enable),
        .game_over_done   (game_over_done)
    );

    // Generacion del reloj de 100 MHz
    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    // Tarea que entrega un pulso de tick_1ms de un ciclo de duracion
    task automatic pulse_tick();
        @(posedge clk);
        tick_1ms <= 1'b1;
        @(posedge clk);
        tick_1ms <= 1'b0;
        #1; // deja resolver las asignaciones no bloqueantes del DUT antes de leer sus salidas
    endtask

    initial begin
        integer i;

        // Valores iniciales
        tick_1ms         = 1'b0;
        game_over_enable = 1'b0;
        reset             = 1'b1;

        @(posedge clk);
        @(posedge clk);
        reset = 1'b0;
        @(posedge clk);

        //----------------------------------------------------------------------
        // Test 1: sin game_over_enable, no debe activarse aunque lleguen ticks
        //----------------------------------------------------------------------
        for (i = 0; i < GAME_OVER_MS_TEST + 2; i = i + 1)
            pulse_tick();

        if (!game_over_done)
            $display("PASS: temporizador permanece detenido sin game_over_enable");
        else
            $error("FALLO: game_over_done se activo sin game_over_enable");

        //----------------------------------------------------------------------
        // Test 2: no debe haber pulso antes de cumplirse GAME_OVER_MS ticks
        //----------------------------------------------------------------------
        game_over_enable = 1'b1;

        for (i = 0; i < GAME_OVER_MS_TEST - 1; i = i + 1) begin
            pulse_tick();
            if (game_over_done)
                $error("FALLO: game_over_done aparecio antes de tiempo (tick %0d)", i);
        end
        $display("PASS: no hay game_over_done antes del limite");

        //----------------------------------------------------------------------
        // Test 3: en el tick exacto debe aparecer el pulso
        //----------------------------------------------------------------------
        pulse_tick();

        if (game_over_done)
            $display("PASS: game_over_done aparece exactamente en el limite");
        else
            $error("FALLO: game_over_done no aparecio en el limite esperado");

        //----------------------------------------------------------------------
        // Test 4: el pulso debe durar solamente un ciclo
        //----------------------------------------------------------------------
        @(posedge clk);
        #1;

        if (!game_over_done)
            $display("PASS: game_over_done dura solamente un ciclo");
        else
            $error("FALLO: game_over_done se mantuvo mas de un ciclo");

        //----------------------------------------------------------------------
        // Test 5: no debe repetirse mientras game_over_enable siga activo
        //----------------------------------------------------------------------
        for (i = 0; i < 5; i = i + 1) begin
            pulse_tick();
            if (game_over_done)
                $error("FALLO: game_over_done se repitio con game_over_enable activo");
        end
        $display("PASS: no se repite game_over_done mientras game_over_enable esta activo");

        //----------------------------------------------------------------------
        // Test 6: desactivar y reactivar permite un nuevo ciclo de GAME OVER
        //----------------------------------------------------------------------
        game_over_enable = 1'b0;
        pulse_tick();
        game_over_enable = 1'b1;

        for (i = 0; i < GAME_OVER_MS_TEST - 1; i = i + 1)
            pulse_tick();

        if (!game_over_done)
            $display("PASS: nuevo ciclo de GAME OVER no genera pulso antes de tiempo");
        else
            $error("FALLO: pulso prematuro en el nuevo ciclo de GAME OVER");

        pulse_tick();

        if (game_over_done)
            $display("PASS: nuevo ciclo de GAME OVER genera pulso correctamente");
        else
            $error("FALLO: no se genero pulso en el nuevo ciclo de GAME OVER");

        //----------------------------------------------------------------------
        // Test 7: reset limpia el temporizador
        //----------------------------------------------------------------------
        reset = 1'b1;
        @(posedge clk);
        reset = 1'b0;
        #1;

        if (!game_over_done)
            $display("PASS: reset limpia correctamente game_over_timer");
        else
            $error("FALLO: reset no limpio game_over_done");

        $display("-------------------------------------------");
        $display("TODAS LAS PRUEBAS game_over_timer PASARON");
        $display("-------------------------------------------");

        #100ns;
        $finish;
    end

endmodule
