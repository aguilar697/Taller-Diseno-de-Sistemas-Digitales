`timescale 1ns / 1ps

module button_conditioner_tb;

    //---------------------------------------------------------
    // Parámetros de prueba
    //---------------------------------------------------------

    localparam int DEBOUNCE_TICKS_TEST = 3;

    localparam time CLK_PERIOD = 10ns;


    //---------------------------------------------------------
    // Señales
    //---------------------------------------------------------

    logic clk;
    logic reset;

    logic tick_1ms;
    logic button_in;

    logic button_level;
    logic press_pulse;


    //---------------------------------------------------------
    // Contador de pulsos reconocidos
    //---------------------------------------------------------

    integer pulse_count;


    //---------------------------------------------------------
    // DUT
    //---------------------------------------------------------

    button_conditioner #(
        .DEBOUNCE_TICKS(DEBOUNCE_TICKS_TEST)
    ) dut (
        .clk          (clk),
        .reset        (reset),
        .tick_1ms     (tick_1ms),
        .button_in    (button_in),
        .button_level (button_level),
        .press_pulse  (press_pulse)
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
    // Tick acelerado para simulación
    //
    // Produce un tick cada 5 ciclos de clk.
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
    // Cuenta las pulsaciones reconocidas
    //---------------------------------------------------------

    always @(posedge clk) begin

        #1ps;

        if (press_pulse)
            pulse_count = pulse_count + 1;

    end


    //---------------------------------------------------------
    // Tarea: esperar un tick
    //---------------------------------------------------------

    task automatic wait_tick;

        begin

            @(posedge tick_1ms);
            #1ns;

        end

    endtask


    //---------------------------------------------------------
    // Prueba principal
    //---------------------------------------------------------

    initial begin

        //-----------------------------------------------------
        // Inicialización
        //-----------------------------------------------------

        reset       = 1'b1;
        button_in   = 1'b0;
        pulse_count = 0;

        repeat (5)
            @(posedge clk);

        @(negedge clk);
        reset = 1'b0;


        //-----------------------------------------------------
        // PRUEBA 1:
        // Simular rebotes al presionar
        //-----------------------------------------------------

        button_in = 1'b1;
        wait_tick();

        button_in = 1'b0;
        wait_tick();

        button_in = 1'b1;
        wait_tick();

        button_in = 1'b0;
        wait_tick();


        if (pulse_count != 0)
            $error("ERROR: un rebote genero una pulsacion falsa");
        else
            $display("PASS: los rebotes fueron ignorados");


        //-----------------------------------------------------
        // PRUEBA 2:
        // Mantener presionado de forma estable
        //-----------------------------------------------------

        button_in = 1'b1;

        repeat (DEBOUNCE_TICKS_TEST + 1)
            wait_tick();


        if (button_level !== 1'b1)
            $error("ERROR: el boton estable no fue reconocido");


        if (pulse_count != 1)
            $error(
                "ERROR: se esperaba 1 pulso y se obtuvieron %0d",
                pulse_count
            );
        else
            $display("PASS: pulsacion estable reconocida una sola vez");


        //-----------------------------------------------------
        // PRUEBA 3:
        // Mantener botón presionado
        //-----------------------------------------------------

        repeat (5)
            wait_tick();


        if (pulse_count != 1)
            $error("ERROR: mantener el boton genero pulsos adicionales");
        else
            $display("PASS: mantener presionado no repite el golpe");


        //-----------------------------------------------------
        // PRUEBA 4:
        // Liberar el botón
        //-----------------------------------------------------

        button_in = 1'b0;

        repeat (DEBOUNCE_TICKS_TEST + 1)
            wait_tick();


        if (button_level !== 1'b0)
            $error("ERROR: no se reconocio la liberacion del boton");
        else
            $display("PASS: liberacion del boton reconocida");


        //-----------------------------------------------------
        // PRUEBA 5:
        // Segunda pulsación
        //-----------------------------------------------------

        button_in = 1'b1;

        repeat (DEBOUNCE_TICKS_TEST + 1)
            wait_tick();


        if (pulse_count != 2)
            $error(
                "ERROR: segunda pulsacion incorrecta. Pulsos = %0d",
                pulse_count
            );
        else
            $display("PASS: segunda pulsacion reconocida");


        //-----------------------------------------------------
        // Fin
        //-----------------------------------------------------

        $display("-------------------------------------------");
        $display("TODAS LAS PRUEBAS button_conditioner PASARON");
        $display("-------------------------------------------");

        #100ns;

        $finish;

    end

endmodule