`timescale 1ns / 1ps

module buttons_frontend_tb;

    //---------------------------------------------------------
    // Parámetros
    //---------------------------------------------------------

    localparam int DEBOUNCE_TICKS_TEST = 3;
    localparam time CLK_PERIOD = 10ns;


    //---------------------------------------------------------
    // Señales
    //---------------------------------------------------------

    logic clk;
    logic reset;
    logic tick_1ms;

    logic [7:0] buttons_in;
    logic [7:0] buttons_level;
    logic [7:0] press_pulse;


    //---------------------------------------------------------
    // Contadores de pulsaciones reconocidas
    //---------------------------------------------------------

    integer pulse_count [0:7];

    integer k;


    //---------------------------------------------------------
    // DUT
    //---------------------------------------------------------

    buttons_frontend #(
        .DEBOUNCE_TICKS(DEBOUNCE_TICKS_TEST)
    ) dut (
        .clk           (clk),
        .reset         (reset),
        .tick_1ms      (tick_1ms),
        .buttons_in    (buttons_in),
        .buttons_level (buttons_level),
        .press_pulse   (press_pulse)
    );


    //---------------------------------------------------------
    // Clock 100 MHz
    //---------------------------------------------------------

    initial begin
        clk = 1'b0;

        forever #(CLK_PERIOD / 2)
            clk = ~clk;
    end


    //---------------------------------------------------------
    // Tick acelerado
    //---------------------------------------------------------

    integer tick_counter;

    always_ff @(posedge clk) begin

        if (reset) begin

            tick_counter <= 0;
            tick_1ms     <= 1'b0;

        end
        else begin

            if (tick_counter == 4) begin

                tick_counter <= 0;
                tick_1ms     <= 1'b1;

            end
            else begin

                tick_counter <= tick_counter + 1;
                tick_1ms     <= 1'b0;

            end

        end

    end


    //---------------------------------------------------------
    // Contar pulsaciones
    //---------------------------------------------------------

    always @(posedge clk) begin

        #1ps;

        for (k = 0; k < 8; k = k + 1) begin

            if (press_pulse[k])
                pulse_count[k] = pulse_count[k] + 1;

        end

    end


    //---------------------------------------------------------
    // Esperar un tick
    //---------------------------------------------------------

    task automatic wait_tick;

        begin
            @(posedge tick_1ms);
            #1ns;
        end

    endtask


    //---------------------------------------------------------
    // Prueba
    //---------------------------------------------------------

    initial begin

        //-----------------------------------------------------
        // Inicialización
        //-----------------------------------------------------

        reset      = 1'b1;
        buttons_in = 8'b00000000;

        for (k = 0; k < 8; k = k + 1)
            pulse_count[k] = 0;

        repeat (5)
            @(posedge clk);

        @(negedge clk);
        reset = 1'b0;


        //-----------------------------------------------------
        // PRUEBA 1: botón 2
        //-----------------------------------------------------

        buttons_in[2] = 1'b1;

        repeat (DEBOUNCE_TICKS_TEST + 1)
            wait_tick();


        if (pulse_count[2] != 1)
            $error(
                "ERROR: boton 2 genero %0d pulsos",
                pulse_count[2]
            );
        else
            $display("PASS: boton 2 reconocido correctamente");


        //-----------------------------------------------------
        // Ningún otro botón debe haberse activado
        //-----------------------------------------------------

        for (k = 0; k < 8; k = k + 1) begin

            if ((k != 2) && (pulse_count[k] != 0))
                $error(
                    "ERROR: boton %0d genero un pulso inesperado",
                    k
                );

        end

        $display("PASS: canales independientes");


        //-----------------------------------------------------
        // Liberamos botón 2
        //-----------------------------------------------------

        buttons_in[2] = 1'b0;

        repeat (DEBOUNCE_TICKS_TEST + 1)
            wait_tick();


        //-----------------------------------------------------
        // PRUEBA 2: botón 5
        //-----------------------------------------------------

        buttons_in[5] = 1'b1;

        repeat (DEBOUNCE_TICKS_TEST + 1)
            wait_tick();


        if (pulse_count[5] != 1)
            $error(
                "ERROR: boton 5 genero %0d pulsos",
                pulse_count[5]
            );
        else
            $display("PASS: boton 5 reconocido correctamente");


        //-----------------------------------------------------
        // Comprobar resultados
        //-----------------------------------------------------

        if ((pulse_count[2] == 1) &&
            (pulse_count[5] == 1)) begin

            $display("--------------------------------------");
            $display("TODAS LAS PRUEBAS buttons_frontend PASARON");
            $display("--------------------------------------");

        end
        else begin

            $error("ERROR GENERAL EN buttons_frontend");

        end


        #100ns;

        $finish;

    end

endmodule