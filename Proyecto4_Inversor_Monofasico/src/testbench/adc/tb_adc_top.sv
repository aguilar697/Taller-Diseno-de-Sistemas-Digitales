
`timescale 1ns / 1ps

// Verifica dos conversiones del XADC real en simulación, sin plataforma de control.
// El reconocimiento acompaña el pulso con el token de la muestra consumida.
module tb_adc_top;

    // ==========================================
    // PARAMETROS DE SIMULACION
    // ==========================================

    // Reloj de 100 MHz: periodo de 10 ns.
    localparam int CLK_PERIOD = 10;

    // Limite de espera por adquisicion.
    // Es un valor de diagnostico, no definitivo.
    localparam int MAX_WAIT_CYCLES = 100000;


    // ==========================================
    // RELOJ Y SENALES DE ENTRADA
    // ==========================================

    logic clk = 1'b0;

    // Genera el reloj del subsistema.
    always #(CLK_PERIOD/2) clk = ~clk;

    // Reset activo en nivel bajo.
    logic aresetn = 1'b0;

    // Solicitudes de adquisicion.
    logic pwm_trigger_i = 1'b0;
    logic start_sw_i    = 1'b0;

    // Reconocimiento de la ultima muestra.
    logic ack_sample_i = 1'b0;
    logic [31:0] ack_id_i = 0;
    logic [31:0] sample_token_o;


    // ==========================================
    // SENALES DE SALIDA
    // ==========================================

    // Muestra digital de 32 bits.
    logic [31:0] sample_o;

    // Indicadores de adquisicion.
    logic busy_o;
    logic valid_o;
    logic new_data_o;

    // Indicadores de diagnostico.
    logic missed_trigger_o;
    logic overrun_o;
    logic timeout_o;

    // Estado ocupado del XADC Wizard.
    logic xadc_busy_o;


    // ==========================================
    // CONTADORES DE EVENTOS
    // ==========================================

    // Permiten comprobar que cada etapa de
    // la secuencia de conversion haya ocurrido.

    integer n_convst = 0;
    integer n_eoc    = 0;
    integer n_den    = 0;
    integer n_drdy   = 0;


    // ==========================================
    // INSTANCIA DEL SUBSISTEMA ADC
    // ==========================================

    // Integra adc_control con xadc_wiz_0.
    //
    // Los puertos analogicos no representan
    // aqui una fuente fisica de corriente.
    // El modelo XADC utiliza su configuracion
    // de estimulos analogicos de simulacion.

    adc_top #(.ADC_TIMEOUT_CYCLES(1024)) dut (
        .clk(clk),
        .aresetn(aresetn),

        .pwm_trigger_i(pwm_trigger_i),
        .start_sw_i(start_sw_i),
        .ack_sample_i(ack_sample_i), .ack_id_i(ack_id_i),

        .vauxp6(1'b0),
        .vauxn6(1'b0),

        .sample_o(sample_o), .sample_token_o(sample_token_o),

        .busy_o(busy_o),
        .valid_o(valid_o),
        .new_data_o(new_data_o),

        .missed_trigger_o(missed_trigger_o),
        .overrun_o(overrun_o),
        .timeout_o(timeout_o),

        .xadc_busy_o(xadc_busy_o)
    );


    // ==========================================
    // REGISTRO DE EVENTOS DEL XADC
    // ==========================================

    // Cuenta las senales internas que aparecen
    // durante el proceso de adquisicion.

    always @(posedge clk) begin
        if (aresetn) begin

            if (dut.convst)
                n_convst <= n_convst + 1;

            if (dut.eoc)
                n_eoc <= n_eoc + 1;

            if (dut.den)
                n_den <= n_den + 1;

            if (dut.drdy)
                n_drdy <= n_drdy + 1;

        end
    end


    // ==========================================
    // MENSAJES DE DIAGNOSTICO
    // ==========================================

    // Indica cuando se solicita una conversion.
    always @(posedge dut.convst) begin
        $display(
            "[%0t] CONVST: conversion solicitada",
            $time
        );
    end

    // Indica cuando el XADC entra en estado ocupado.
    always @(posedge xadc_busy_o) begin
        $display(
            "[%0t] XADC BUSY = 1",
            $time
        );
    end

    // Indica cuando el XADC deja de estar ocupado.
    always @(negedge xadc_busy_o) begin
        $display(
            "[%0t] XADC BUSY = 0",
            $time
        );
    end

    // Fin de conversion analogica.
    always @(posedge dut.eoc) begin
        $display(
            "[%0t] EOC: conversion finalizada",
            $time
        );
    end

    // Solicitud de lectura del registro DRP.
    always @(posedge dut.den) begin
        $display(
            "[%0t] DEN: lectura DRP solicitada",
            $time
        );
    end

    // Dato disponible para captura.
    always @(posedge dut.drdy) begin
        $display(
            "[%0t] DRDY: dato disponible",
            $time
        );
    end

    // Error por tiempo de espera excedido.
    always @(posedge timeout_o) begin
        $display(
            "[%0t] ERROR: timeout del ADC",
            $time
        );
    end


    // ==========================================
    // DISPARO POR SOFTWARE
    // ==========================================

    // Simula una solicitud de conversion
    // realizada por MicroBlaze mediante AXI.

    task automatic pulse_sw;

        @(negedge clk);
        start_sw_i = 1'b1;

        @(negedge clk);
        start_sw_i = 1'b0;

    endtask


    // ==========================================
    // DISPARO POR PWM
    // ==========================================

    // Simula el pulso de adquisicion generado
    // por el modulo PWM de Kevin Aguilar.

    task automatic pulse_pwm;

        @(negedge clk);
        pwm_trigger_i = 1'b1;

        @(negedge clk);
        pwm_trigger_i = 1'b0;

    endtask


    // ==========================================
    // RECONOCIMIENTO DE MUESTRA
    // ==========================================

    // Simula que el procesador reconoce
    // el resultado de conversion.

    task automatic acknowledge;

        @(negedge clk);
        // Identifica la muestra antes de emitir el pulso; no se reconoce el valor futuro.
        ack_id_i = sample_token_o;
        ack_sample_i = 1'b1;

        @(negedge clk);
        ack_sample_i = 1'b0;

    endtask


    // ==========================================
    // RESUMEN DE DIAGNOSTICO
    // ==========================================

    // Muestra los eventos registrados y el
    // estado del subsistema al momento de consulta.

    task automatic show_status;

        $display("--------------------------------");
        $display("Estado actual del subsistema");
        $display("Tiempo:       %0t", $time);
        $display("CONVST:       %0d", n_convst);
        $display("EOC:          %0d", n_eoc);
        $display("DEN:          %0d", n_den);
        $display("DRDY:         %0d", n_drdy);
        $display("XADC BUSY:    %b", xadc_busy_o);
        $display("ADC BUSY:     %b", busy_o);
        $display("VALID:        %b", valid_o);
        $display("NEW DATA:     %b", new_data_o);
        $display("TIMEOUT:      %b", timeout_o);
        $display("SAMPLE:       %h", sample_o);
        $display("CHANNEL:      %h", dut.adc_channel);
        $display("--------------------------------");

    endtask


    // ==========================================
    // VERIFICACION DE CONVERSION
    // ==========================================

    // Espera una muestra con el identificador
    // esperado y comprueba su validez.

    task automatic check_conversion(
        input logic [15:0] expected_id
    );

        integer cycles;

        cycles = 0;

        // Espera hasta recibir la muestra,
        // detectar un timeout o alcanzar
        // el limite de ciclos de simulacion.
        while (
            sample_o[31:16] !== expected_id &&
            cycles < MAX_WAIT_CYCLES &&
            timeout_o !== 1'b1
        ) begin

            @(negedge clk);
            cycles = cycles + 1;

        end

        // Verifica primero si hubo timeout.
        if (timeout_o === 1'b1) begin

            show_status();

            $fatal(
                1,
                "Timeout del controlador ADC"
            );

        end

        // Verifica si se excedio el tiempo
        // permitido por el testbench.
        if (cycles >= MAX_WAIT_CYCLES) begin

            show_status();

            $fatal(
                1,
                "No se recibio muestra del XADC"
            );

        end

        // La muestra debe estar publicada
        // y el controlador debe estar libre.
        if (
            valid_o !== 1'b1 ||
            new_data_o !== 1'b1 ||
            busy_o !== 1'b0
        ) begin

            show_status();

            $fatal(
                1,
                "Estado de muestra incorrecto"
            );

        end

        // Comprueba el formato de 32 bits.
        // Los cuatro bits superiores del campo
        // ADC se reservan como cero.
        if (sample_o[15:12] !== 4'b0000) begin

            $fatal(
                1,
                "Formato de codigo ADC incorrecto"
            );

        end

        // Canal y valor del estímulo analógico; el código no representa corriente calibrada.
        if (dut.adc_channel !== 5'h16)
            $fatal(1, "Canal integrado distinto de VAUX6");
        if ($isunknown(sample_o) || sample_o[11:0] < 12'he62 || sample_o[11:0] > 12'he6a)
            $fatal(1, "Codigo distinto del estimulo analogico esperado de 0.9 V");

        // Muestra el resultado obtenido.
        $display(
            "ID=%0d | Codigo ADC=%0d | SAMPLE=%h",
            sample_o[31:16],
            sample_o[11:0],
            sample_o
        );

        $display(
            "Conversion completada en %0d ciclos",
            cycles
        );

    endtask


    // ==========================================
    // SECUENCIA PRINCIPAL DE PRUEBAS
    // ==========================================

    initial begin

        $display("================================");
        $display("SIMULACION INTEGRADA ADC/XADC");
        $display("================================");

        // Mantiene reset durante 50 ciclos.
        repeat (50) @(negedge clk);

        // Libera el reset.
        aresetn = 1'b1;

        $display(
            "[%0t] Reset liberado",
            $time
        );

        // Permite la inicializacion del modelo
        // XADC antes del primer disparo.
        repeat (5000) @(negedge clk);

        $display(
            "[%0t] Fin de espera de inicializacion",
            $time
        );

        show_status();


        // ======================================
        // PRUEBA 1: CONVERSION POR SOFTWARE
        // ======================================

        $display("Prueba 1: conversion por software");

        pulse_sw();

        // Espera la primera muestra completa.
        check_conversion(16'd1);

        // Verifica que se produjera la secuencia.
        if (
            n_convst < 1 ||
            n_eoc < 1 ||
            n_den < 1 ||
            n_drdy < 1
        ) begin

            show_status();

            $fatal(
                1,
                "Secuencia XADC/DRP incompleta"
            );

        end

        // Reconoce la primera muestra.
        acknowledge();

        if (new_data_o !== 1'b0) begin

            $fatal(
                1,
                "No se reconocio la muestra"
            );

        end


        // ======================================
        // PRUEBA 2: CONVERSION POR PWM
        // ======================================

        $display("Prueba 2: conversion por PWM");

        pulse_pwm();

        // Espera la segunda muestra completa.
        check_conversion(16'd2);

        // Comprueba que existan eventos para
        // las dos conversiones realizadas.
        if (
            n_convst < 2 ||
            n_eoc < 2 ||
            n_den < 2 ||
            n_drdy < 2
        ) begin

            show_status();

            $fatal(
                1,
                "Faltan eventos de adquisicion"
            );

        end


        // ======================================
        // RESULTADO FINAL
        // ======================================

        show_status();

        $display("================================");
        $display("INTEGRACION XADC: TEST PASSED");
        $display("================================");

        $finish;

    end


    // ==========================================
    // PROTECCION GENERAL DE SIMULACION
    // ==========================================

    // Limite global de 2.5 ms.
    // Evita que la simulacion quede bloqueada
    // si el XADC no responde.

    initial begin

        #2500000;

        show_status();

        $fatal(
            1,
            "Timeout general de integracion"
        );

    end

endmodule
