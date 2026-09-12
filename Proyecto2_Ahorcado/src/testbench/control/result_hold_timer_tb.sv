`timescale 1ns/1ps

module result_hold_timer_tb;

    localparam int unsigned TB_CLK_HZ       = 4;
    localparam int unsigned TB_HOLD_SECONDS = 3;
    localparam int unsigned TB_HOLD_CYCLES  =
        TB_CLK_HZ * TB_HOLD_SECONDS;

    logic clk_i;
    logic rst_sync;
    logic start;

    logic result_hold_done;

    integer errors;


    // ============================================================
    // CLOCK DE 100 MHz
    // Periodo = 10 ns
    // ============================================================
    initial begin
        clk_i = 1'b0;
        forever #5 clk_i = ~clk_i;
    end


    // ============================================================
    // DUT
    // ============================================================
    result_hold_timer #(
        .CLK_HZ       (TB_CLK_HZ),
        .HOLD_SECONDS (TB_HOLD_SECONDS)
    ) dut (
        .clk_i            (clk_i),
        .rst_sync         (rst_sync),
        .start            (start),
        .result_hold_done (result_hold_done)
    );


    // ============================================================
    // ESPERAR N CICLOS
    // ============================================================
    task automatic wait_cycles(input int n);
        repeat (n)
            @(posedge clk_i);

        #1;
    endtask


    // ============================================================
    // COMPROBAR RESULTADO
    // ============================================================
    task automatic check_done(
        input logic expected,
        input string message
    );

        if (result_hold_done !== expected) begin
            $error(
                "FAIL: %s | esperado=%b obtenido=%b",
                message,
                expected,
                result_hold_done
            );

            errors = errors + 1;
        end
        else begin
            $display(
                "OK: %s | result_hold_done=%b",
                message,
                result_hold_done
            );
        end

    endtask


    // ============================================================
    // ESTÍMULOS
    // ============================================================
    initial begin

        errors   = 0;
        rst_sync = 1'b1;
        start    = 1'b0;


        // --------------------------------------------------------
        // RESET
        // --------------------------------------------------------
        wait_cycles(2);

        rst_sync = 1'b0;

        wait_cycles(1);

        check_done(
            1'b0,
            "Salida despues del reset"
        );


        // ========================================================
        // PRUEBA 1
        // Iniciar retencion del resultado
        // ========================================================

        start = 1'b1;

        wait_cycles(1);

        start = 1'b0;

        check_done(
            1'b0,
            "Inicio del temporizador"
        );


        // Todavía NO deben haberse cumplido los 3 segundos.
        wait_cycles(TB_HOLD_CYCLES - 1);

        check_done(
            1'b0,
            "Antes de completar los 3 segundos"
        );


        // Ciclo que completa los 3 segundos.
        wait_cycles(1);

        check_done(
            1'b1,
            "Retencion de 3 segundos completada"
        );


        // ========================================================
        // PRUEBA 2
        // done debe mantenerse activo
        // ========================================================

        wait_cycles(5);

        check_done(
            1'b1,
            "done permanece activo despues de finalizar"
        );


        // ========================================================
        // PRUEBA 3
        // Un nuevo start debe reiniciar el temporizador
        // ========================================================

        start = 1'b1;

        wait_cycles(1);

        start = 1'b0;

        check_done(
            1'b0,
            "Nuevo start reinicia result_hold_done"
        );


        wait_cycles(TB_HOLD_CYCLES);

        check_done(
            1'b1,
            "Segunda retencion completada"
        );


        // ========================================================
        // RESULTADO FINAL
        // ========================================================

        if (errors == 0) begin

            $display("");
            $display("---------------------------------------");
            $display("PASS: result_hold_timer");
            $display("Tiempo de retencion = 3 segundos");
            $display("Reinicio por start   = OK");
            $display("---------------------------------------");

        end
        else begin

            $display("");
            $display("---------------------------------------");
            $display("FAIL: result_hold_timer");
            $display("Errores detectados = %0d", errors);
            $display("---------------------------------------");

        end

        $finish;

    end

endmodule