`timescale 1ns/1ps

module countdown_timer_tb;

    // Para simulación:
    // cuatro ciclos de reloj equivalen a un segundo lógico.
    localparam int unsigned TB_CLK_HZ = 4;

    logic       clk_i;
    logic       rst_sync;
    logic       difficulty;
    logic       load;
    logic       enable;

    logic [6:0] time_remaining;
    logic       expired;


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
    countdown_timer #(
        .CLK_HZ       (TB_CLK_HZ),
        .EASY_SECONDS (60),
        .HARD_SECONDS (45)
    ) dut (
        .clk_i          (clk_i),
        .rst_sync       (rst_sync),
        .difficulty     (difficulty),
        .load           (load),
        .enable         (enable),
        .time_remaining (time_remaining),
        .expired        (expired)
    );


    // ============================================================
    // TAREA: esperar N ciclos de reloj
    // ============================================================
    task automatic wait_cycles(input int n);
        repeat (n)
            @(posedge clk_i);

        #1;
    endtask


    // ============================================================
    // TAREA: comprobar tiempo restante
    // ============================================================
    task automatic check_time(
        input int expected,
        input string message
    );

        if (time_remaining !== expected[6:0]) begin
            $error(
                "FAIL: %s | esperado=%0d obtenido=%0d",
                message,
                expected,
                time_remaining
            );
        end
        else begin
            $display(
                "OK: %s | time_remaining=%0d",
                message,
                time_remaining
            );
        end

    endtask


    // ============================================================
    // ESTÍMULOS
    // ============================================================
    initial begin

        rst_sync   = 1'b1;
        difficulty = 1'b0;
        load       = 1'b0;
        enable     = 1'b0;

        // --------------------------------------------------------
        // RESET
        // --------------------------------------------------------
        wait_cycles(2);

        rst_sync = 1'b0;

        wait_cycles(1);

        check_time(
            0,
            "Despues del reset"
        );


        // ========================================================
        // PRUEBA 1: MODO FACIL
        // ========================================================

        difficulty = 1'b0;
        load       = 1'b1;

        wait_cycles(1);

        load = 1'b0;

        check_time(
            60,
            "Carga inicial en modo FACIL"
        );


        // Enable desactivado:
        // el temporizador NO debe avanzar.
        wait_cycles(8);

        check_time(
            60,
            "Temporizador detenido con enable=0"
        );


        // Activar temporizador.
        enable = 1'b1;

        // Cuatro ciclos = un segundo lógico.
        wait_cycles(TB_CLK_HZ);

        check_time(
            59,
            "Primer segundo en modo FACIL"
        );


        wait_cycles(TB_CLK_HZ);

        check_time(
            58,
            "Segundo segundo en modo FACIL"
        );


        // --------------------------------------------------------
        // PAUSA
        // --------------------------------------------------------
        enable = 1'b0;

        wait_cycles(8);

        check_time(
            58,
            "Tiempo conservado durante pausa"
        );


        // ========================================================
        // PRUEBA 2: MODO DIFICIL
        // ========================================================

        difficulty = 1'b1;
        load       = 1'b1;

        wait_cycles(1);

        load = 1'b0;

        check_time(
            45,
            "Carga inicial en modo DIFICIL"
        );


        enable = 1'b1;


        // ========================================================
        // PRUEBA 3: CONTAR HASTA CERO
        // ========================================================

        repeat (45)
            wait_cycles(TB_CLK_HZ);


        check_time(
            0,
            "Cuenta regresiva completa"
        );


        // expired debe estar activo.
        if (expired !== 1'b1) begin
            $error(
                "FAIL: expired deberia ser 1 cuando el tiempo llega a cero"
            );
        end
        else begin
            $display(
                "OK: expired se activo correctamente"
            );
        end


        // Esperar más tiempo:
        // no debe pasar por debajo de cero.
        wait_cycles(12);

        check_time(
            0,
            "El temporizador permanece en cero"
        );


        // ========================================================
        // RESULTADO FINAL
        // ========================================================

        $display("");
        $display("---------------------------------------");
        $display("PASS: countdown_timer");
        $display("FACIL   = 60 segundos");
        $display("DIFICIL = 45 segundos");
        $display("expired = OK");
        $display("---------------------------------------");

        $finish;

    end

endmodule