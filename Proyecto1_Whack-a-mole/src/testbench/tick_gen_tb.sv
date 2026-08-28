`timescale 1ns / 1ps

module tick_gen_tb;

    //---------------------------------------------------------
    // Parámetros de prueba
    //---------------------------------------------------------

    // Conservamos conceptualmente el reloj de 100 MHz,
    // pero hacemos que el tick ocurra cada 10 ciclos
    // para acelerar muchísimo la simulación.

    localparam int CLK_FREQ_TEST = 100_000_000;
    localparam int TICK_HZ_TEST  = 10_000_000;

    localparam int CLKS_PER_TICK =
        CLK_FREQ_TEST / TICK_HZ_TEST;

    localparam time CLK_PERIOD = 10ns;


    //---------------------------------------------------------
    // Señales
    //---------------------------------------------------------

    logic clk;
    logic reset;
    logic tick;


    //---------------------------------------------------------
    // DUT: módulo bajo prueba
    //---------------------------------------------------------

    tick_gen #(
        .CLK_FREQ (CLK_FREQ_TEST),
        .TICK_HZ  (TICK_HZ_TEST)
    ) dut (
        .clk   (clk),
        .reset (reset),
        .tick  (tick)
    );


    //---------------------------------------------------------
    // Reloj de 100 MHz
    //---------------------------------------------------------

    initial begin

        clk = 1'b0;

        forever #(CLK_PERIOD / 2)
            clk = ~clk;

    end


    //---------------------------------------------------------
    // Prueba principal
    //---------------------------------------------------------

    initial begin

        integer i;


        // -------------------------
        // Reset inicial
        // -------------------------

        reset = 1'b1;

        repeat (3)
            @(posedge clk);

        // Lo liberamos en negedge para evitar carreras
        @(negedge clk);
        reset = 1'b0;


        // -------------------------
        // Verificamos primer tick
        // -------------------------

        for (i = 1; i < CLKS_PER_TICK; i = i + 1) begin

            @(posedge clk);
            #1ps;

            if (tick !== 1'b0)
                $error(
                    "ERROR: tick aparecio antes de tiempo, ciclo %0d",
                    i
                );

        end


        // Ciclo número 10
        @(posedge clk);
        #1ps;

        if (tick !== 1'b1)
            $error("ERROR: no aparecio el primer tick");
        else
            $display(
                "PASS: primer tick generado despues de %0d ciclos",
                CLKS_PER_TICK
            );


        // -------------------------
        // Debe durar un solo ciclo
        // -------------------------

        @(posedge clk);
        #1ps;

        if (tick !== 1'b0)
            $error("ERROR: tick duro mas de un ciclo");
        else
            $display("PASS: tick dura exactamente un ciclo");


        // -------------------------
        // Esperamos segundo tick
        // -------------------------

        for (i = 2; i < CLKS_PER_TICK; i = i + 1) begin

            @(posedge clk);
            #1ps;

            if (tick !== 1'b0)
                $error("ERROR: segundo tick aparecio antes de tiempo");

        end


        @(posedge clk);
        #1ps;

        if (tick !== 1'b1)
            $error("ERROR: no aparecio el segundo tick");
        else
            $display("PASS: segundo tick generado correctamente");


        // -------------------------
        // Fin
        // -------------------------

        $display("-------------------------------------");
        $display("TODAS LAS PRUEBAS tick_gen FINALIZARON");
        $display("-------------------------------------");

        #20ns;

        $finish;

    end

endmodule