`timescale 1ns / 1ps

//////////////////////////////////////////////////////////////////////////////////
// Testbench de integración - top_whack_a_mole
//
// Esta versión verifica específicamente el problema encontrado en hardware:
//
//   1. La FPGA activa mole_request.
//   2. El circuito discreto responde por UART ANTES de que mole_request baje.
//   3. data_valid ocurre mientras la FSM todavía está en S_REQUEST.
//   4. La FSM debe guardar esa respuesta.
//   5. Al terminar mole_request debe iniciar normalmente S_ACTIVE.
//
// En hardware:
//   mole_request ≈ 5 ms
//   trama UART   ≈ 1.04 ms
//
// En esta simulación se aceleran los tiempos:
//   mole_request = 20 us
//   trama UART   = 10 us
//
// De esta manera mantenemos la misma relación temporal,
// pero la simulación termina mucho más rápido.
//////////////////////////////////////////////////////////////////////////////////

module top_whack_a_mole_tb;


    //--------------------------------------------------------------------------
    // Parámetros de simulación
    //--------------------------------------------------------------------------

    localparam time CLK_PERIOD = 10ns;

    // Tick acelerado:
    // 1 MHz -> un tick cada 1 us.
    localparam int TICK_HZ_TEST = 1_000_000;

    // UART acelerada:
    // 1 Mbaud -> cada bit dura 1 us.
    localparam int BAUD_RATE_TEST = 1_000_000;
    localparam time BIT_PERIOD    = 1us;

    // Debounce reducido para simulación.
    localparam int DEBOUNCE_TICKS_TEST = 3;

    // IMPORTANTE:
    // mole_request dura 20 ticks = 20 us.
    //
    // La trama UART dura aproximadamente 10 us.
    //
    // Por tanto, la UART termina ANTES de que mole_request baje.
    // Esto reproduce el problema observado físicamente.
    localparam int REQUEST_HOLD_MS_TEST = 20;

    // GAME OVER acelerado.
    localparam int GAME_OVER_MS_TEST = 5;


    //--------------------------------------------------------------------------
    // Señales del DUT
    //--------------------------------------------------------------------------

    logic       clk;
    logic       reset_btn;
    logic [7:0] hit_buttons;
    logic       serial_data;

    logic       mole_request;
    logic [6:0] seg;
    logic [3:0] an;
    logic       game_status_led;


    //--------------------------------------------------------------------------
    // DUT
    //--------------------------------------------------------------------------

    top_whack_a_mole #(

        .CLK_FREQ        (100_000_000),
        .BAUD_RATE       (BAUD_RATE_TEST),
        .TICK_HZ         (TICK_HZ_TEST),
        .DEBOUNCE_TICKS  (DEBOUNCE_TICKS_TEST),
        .REQUEST_HOLD_MS (REQUEST_HOLD_MS_TEST),
        .GAME_OVER_MS    (GAME_OVER_MS_TEST)

    ) dut (

        .clk             (clk),
        .reset_btn       (reset_btn),
        .hit_buttons     (hit_buttons),
        .serial_data     (serial_data),

        .mole_request    (mole_request),
        .seg             (seg),
        .an              (an),
        .game_status_led (game_status_led)

    );


    //--------------------------------------------------------------------------
    // Señales internas para verificación
    //--------------------------------------------------------------------------

    wire [6:0] hits_probe =
        dut.hits;

    wire [6:0] misses_probe =
        dut.misses;

    wire [1:0] consecutive_misses_probe =
        dut.consecutive_misses;


    //--------------------------------------------------------------------------
    // Clock de 100 MHz
    //--------------------------------------------------------------------------

    initial begin

        clk = 1'b0;

        forever
            #(CLK_PERIOD / 2)
            clk = ~clk;

    end


    //--------------------------------------------------------------------------
    // Avanzar un ciclo de reloj
    //--------------------------------------------------------------------------

    task automatic step_clk();

        @(posedge clk);
        #1;

    endtask


    //--------------------------------------------------------------------------
    // Enviar un byte UART 8N1
    //--------------------------------------------------------------------------

    task automatic send_uart_byte(
        input logic [7:0] value
    );

        integer i;

        begin

            // START BIT
            serial_data = 1'b0;
            #(BIT_PERIOD);


            // 8 bits de datos.
            // UART transmite LSB primero.
            for (i = 0; i < 8; i = i + 1) begin

                serial_data = value[i];

                #(BIT_PERIOD);

            end


            // STOP BIT
            serial_data = 1'b1;

            #(BIT_PERIOD);

        end

    endtask


    //--------------------------------------------------------------------------
    // Enviar UART MIENTRAS mole_request todavía está alto
    //
    // Esta es la prueba fundamental de la corrección.
    //--------------------------------------------------------------------------

    task automatic send_uart_early(
        input logic [7:0] value
    );

        begin

            //--------------------------------------------------------------
            // Esperamos una solicitud nueva.
            //--------------------------------------------------------------

            if (!mole_request)
                @(posedge mole_request);


            //--------------------------------------------------------------
            // Esperamos solamente 1 us.
            //
            // mole_request dura 20 us, así que seguimos claramente
            // dentro de S_REQUEST.
            //--------------------------------------------------------------

            #1us;


            if (!mole_request) begin

                $error(
                    "FALLO: mole_request bajo antes de iniciar la UART"
                );

            end


            //--------------------------------------------------------------
            // Mandamos la trama completa.
            //
            // Dura aproximadamente 10 us.
            //--------------------------------------------------------------

            send_uart_byte(value);


            //--------------------------------------------------------------
            // La UART ya terminó.
            //
            // mole_request DEBE seguir alto.
            //
            // Si esto se cumple, hemos reproducido exactamente la
            // condición que produjo el fallo en hardware.
            //--------------------------------------------------------------

            if (mole_request) begin

                $display(
                    "PASS: UART 0x%02h termino mientras mole_request seguia ALTO",
                    value
                );

            end
            else begin

                $error(
                    "FALLO: la UART termino despues de mole_request; no se reprodujo la condicion de hardware"
                );

            end

        end

    endtask


    //--------------------------------------------------------------------------
    // Pulsación de botón pasando por el debounce real
    //--------------------------------------------------------------------------

    task automatic press_button(
        input int idx
    );

        integer i;

        begin

            hit_buttons[idx] = 1'b1;


            for (
                i = 0;
                i < DEBOUNCE_TICKS_TEST + 1;
                i = i + 1
            )
                #(
                    1_000_000_000 /
                    TICK_HZ_TEST *
                    1ns
                );


            hit_buttons[idx] = 1'b0;


            for (
                i = 0;
                i < DEBOUNCE_TICKS_TEST + 1;
                i = i + 1
            )
                #(
                    1_000_000_000 /
                    TICK_HZ_TEST *
                    1ns
                );

        end

    endtask


    //--------------------------------------------------------------------------
    // Watchdog
    //--------------------------------------------------------------------------

    initial begin

        #10ms;

        $error(
            "FALLO: watchdog global - la simulacion no termino"
        );

        $finish;

    end


    //--------------------------------------------------------------------------
    // Secuencia principal
    //--------------------------------------------------------------------------

    initial begin


        //----------------------------------------------------------------------
        // Inicialización
        //----------------------------------------------------------------------

        hit_buttons = 8'd0;

        // UART en reposo = HIGH.
        serial_data = 1'b1;


        //----------------------------------------------------------------------
        // Reset
        //----------------------------------------------------------------------

        reset_btn = 1'b1;

        step_clk();
        step_clk();

        reset_btn = 1'b0;

        step_clk();


        $display("");
        $display("==================================================");
        $display("INICIO TEST DE INTEGRACION - UART TEMPRANA");
        $display("==================================================");


        //----------------------------------------------------------------------
        // TEST 1
        //
        // Primera posición:
        //
        // mole_request sube.
        // El circuito responde inmediatamente.
        // UART termina cuando mole_request todavía está alto.
        //
        // Posición enviada = 3.
        //----------------------------------------------------------------------

        send_uart_early(8'd3);


        //----------------------------------------------------------------------
        // Esperamos que terminen los 20 us de mole_request.
        //----------------------------------------------------------------------

        @(negedge mole_request);

        #1us;


        //----------------------------------------------------------------------
        // Ahora la posición 3 debería haber sido recuperada desde
        // pending_position por la nueva FSM.
        //----------------------------------------------------------------------

        if (dut.mole_position == 3'd3) begin

            $display(
                "PASS: posicion UART temprana almacenada correctamente (mole_position = 3)"
            );

        end
        else begin

            $error(
                "FALLO: mole_position=%0d, se esperaba 3",
                dut.mole_position
            );

        end


        //----------------------------------------------------------------------
        // Si la FSM pasó correctamente a S_ACTIVE,
        // presionar el botón 3 debe producir un HIT.
        //----------------------------------------------------------------------

        #1us;

        press_button(3);

        #2us;


        if (
            hits_probe == 7'd1 &&
            misses_probe == 7'd0
        ) begin

            $display(
                "PASS: HIT despues de UART temprana reconocido correctamente"
            );

        end
        else begin

            $error(
                "FALLO: despues del primer HIT, hits=%0d misses=%0d",
                hits_probe,
                misses_probe
            );

        end


        //----------------------------------------------------------------------
        // TEST 2
        //
        // Esta es la condición que más nos interesa porque corresponde
        // al segundo mole_request que fallaba físicamente.
        //
        // Enviamos posición 5 DURANTE mole_request.
        //----------------------------------------------------------------------

        send_uart_early(8'd5);


        @(negedge mole_request);

        #1us;


        if (dut.mole_position == 3'd5) begin

            $display(
                "PASS: SEGUNDA respuesta UART temprana aceptada correctamente (posicion 5)"
            );

        end
        else begin

            $error(
                "FALLO: segunda posicion no capturada, mole_position=%0d",
                dut.mole_position
            );

        end


        //----------------------------------------------------------------------
        // Presionamos el botón correcto de la segunda posición.
        //
        // Esto comprueba que la FPGA NO se quedó en WAIT_UART.
        //----------------------------------------------------------------------

        #1us;

        press_button(5);

        #2us;


        if (
            hits_probe == 7'd2 &&
            misses_probe == 7'd0
        ) begin

            $display(
                "PASS: segundo turno activo; boton 5 genero HIT correctamente"
            );

        end
        else begin

            $error(
                "FALLO: segundo turno no funciono, hits=%0d misses=%0d",
                hits_probe,
                misses_probe
            );

        end


        //----------------------------------------------------------------------
        // TEST 3
        //
        // Posición 2, pero presionamos botón incorrecto 7.
        // Debe producir un fallo.
        //----------------------------------------------------------------------

        send_uart_early(8'd2);

        @(negedge mole_request);

        #1us;


        if (dut.mole_position == 3'd2) begin

            $display(
                "PASS: tercera posicion temprana capturada correctamente"
            );

        end
        else begin

            $error(
                "FALLO: tercera posicion no capturada"
            );

        end


        press_button(7);

        #2us;


        if (
            misses_probe == 7'd1 &&
            consecutive_misses_probe == 2'd1
        ) begin

            $display(
                "PASS: WRONG_HIT incrementa misses despues de UART temprana"
            );

        end
        else begin

            $error(
                "FALLO: misses=%0d consecutive_misses=%0d",
                misses_probe,
                consecutive_misses_probe
            );

        end


        //----------------------------------------------------------------------
        // TEST 4
        //
        // Verificamos que después del fallo vuelve a pedir otra posición
        // y que también acepta una nueva UART temprana.
        //----------------------------------------------------------------------

        send_uart_early(8'd6);

        @(negedge mole_request);

        #1us;


        if (dut.mole_position == 3'd6) begin

            $display(
                "PASS: sistema continua normalmente despues del primer fallo"
            );

        end
        else begin

            $error(
                "FALLO: sistema quedo atascado despues del primer fallo"
            );

        end


        //----------------------------------------------------------------------
        // Resultado final
        //----------------------------------------------------------------------

        $display("");
        $display("==================================================");
        $display("TODAS LAS PRUEBAS DE UART TEMPRANA FINALIZARON");
        $display("==================================================");
        $display("");

        #10us;

        $finish;

    end


endmodule