
`timescale 1ns / 1ps

// Verifica la secuencia digital y los seis casos base con respuestas XADC modeladas.
// El reconocimiento acompaña el pulso con el token de la muestra consumida.
module tb_adc_control;

    // ==========================================
    // PARAMETROS DE LA SIMULACION
    // ==========================================

    // Direccion DRP del canal VAUX6.
    localparam logic [6:0] ADC_ADDR = 7'h16;

    // Tiempo de espera reducido solo para pruebas.
    localparam int TIMEOUT_CYCLES = 20;


    // ==========================================
    // RELOJ Y ENTRADAS
    // ==========================================

    // Reloj de 100 MHz: periodo de 10 ns.
    logic clk = 1'b0;
    always #5 clk = ~clk;

    // Reset activo en nivel bajo.
    logic aresetn = 1'b0;

    // Disparos provenientes del PWM y software.
    logic pwm_trigger_i = 1'b0;
    logic start_sw_i    = 1'b0;

    // Reconocimiento de una muestra publicada.
    logic ack_sample_i = 1'b0;
    logic [31:0] ack_id_i = 0;
    logic [31:0] sample_token_o;

    // Respuestas simuladas del XADC.
    logic        eoc_i  = 1'b0;
    logic        drdy_i = 1'b0;
    logic [15:0] do_i   = 16'h0000;


    // ==========================================
    // SALIDAS DEL CONTROLADOR
    // ==========================================

    logic        convst_o;
    logic        den_o;
    logic [6:0]  daddr_o;
    logic        dwe_o;

    logic        busy_o;
    logic        valid_o;
    logic        new_data_o;
    logic [31:0] sample_o;

    logic missed_trigger_o;
    logic overrun_o;
    logic timeout_o;


    // ==========================================
    // MODULO BAJO PRUEBA
    // ==========================================

    // Instancia del controlador ADC.
    // Utiliza la direccion VAUX6 y un timeout
    // reducido para facilitar las simulaciones.

    adc_control #(
        .ADC_ADDR(ADC_ADDR),
        .TIMEOUT_CYCLES(TIMEOUT_CYCLES)
    ) dut (
        .clk(clk),
        .aresetn(aresetn),

        .pwm_trigger_i(pwm_trigger_i),
        .start_sw_i(start_sw_i),
        .ack_sample_i(ack_sample_i), .ack_id_i(ack_id_i),

        .eoc_i(eoc_i),
        .drdy_i(drdy_i),
        .do_i(do_i),

        .convst_o(convst_o),
        .den_o(den_o),
        .daddr_o(daddr_o),
        .dwe_o(dwe_o),

        .busy_o(busy_o),
        .valid_o(valid_o),
        .new_data_o(new_data_o),
        .sample_o(sample_o), .sample_token_o(sample_token_o),

        .missed_trigger_o(missed_trigger_o),
        .overrun_o(overrun_o),
        .timeout_o(timeout_o)
    );


    // ==========================================
    // GENERACION DE DISPARO PWM
    // ==========================================

    // Representa el pulso de sincronizacion
    // generado por el periferico PWM.
    // Su duracion es de un ciclo de reloj.

    task automatic pulse_pwm;
        @(negedge clk);
        pwm_trigger_i = 1'b1;

        @(negedge clk);
        pwm_trigger_i = 1'b0;
    endtask


    // ==========================================
    // GENERACION DE DISPARO POR SOFTWARE
    // ==========================================

    // Representa una solicitud de conversion
    // originada desde MicroBlaze mediante AXI.

    task automatic pulse_sw;
        @(negedge clk);
        start_sw_i = 1'b1;

        @(negedge clk);
        start_sw_i = 1'b0;
    endtask


    // ==========================================
    // RECONOCIMIENTO DE MUESTRA
    // ==========================================

    // Simula el reconocimiento de una muestra
    // despues de su lectura por el procesador.

    task automatic acknowledge;
        @(negedge clk);
        // Identifica la muestra antes de emitir el pulso; no se reconoce el valor futuro.
        ack_id_i = sample_token_o;
        ack_sample_i = 1'b1;

        @(negedge clk);
        ack_sample_i = 1'b0;
    endtask


    // ==========================================
    // MODELO SIMPLIFICADO DEL XADC
    // ==========================================

    // Simula la respuesta del XADC a una
    // conversion previamente solicitada.
    //
    // Primero genera EOC, despues espera DEN
    // y finalmente entrega DO junto con DRDY.

    task automatic complete_conversion(
        input logic [15:0] raw_data
    );

        // Indica el final de la conversion.
        @(negedge clk);
        eoc_i = 1'b1;

        @(negedge clk);
        eoc_i = 1'b0;

        // Espera la solicitud de lectura DRP.
        wait (den_o === 1'b1);

        // Verifica que se solicite VAUX6
        // y que DWE indique una lectura.
        if (daddr_o !== ADC_ADDR)
            $fatal(1,
                "Direccion DRP incorrecta: %h",
                daddr_o
            );

        if (dwe_o !== 1'b0)
            $fatal(1, "DWE debe permanecer en cero");

        // Entrega el resultado de conversion.
        @(negedge clk);
        do_i   = raw_data;
        drdy_i = 1'b1;

        // Finaliza la respuesta de lectura.
        @(negedge clk);
        drdy_i = 1'b0;

    endtask


    // ==========================================
    // VERIFICACION DE UNA MUESTRA
    // ==========================================

    // Compara la palabra almacenada con el
    // identificador y codigo ADC esperados.

    task automatic check_sample(
        input logic [31:0] expected
    );

        if (sample_o !== expected)
            $fatal(1,
                "Muestra incorrecta. Esperado: %h, recibido: %h",
                expected, sample_o
            );

        $display("Muestra correcta: %h", sample_o);

    endtask


    // ==========================================
    // LIMITE GENERAL DE SIMULACION
    // ==========================================

    // Termina con error si alguna prueba
    // queda esperando una senal indefinidamente.

    initial begin
        #20000;
        $fatal(1, "Timeout general del testbench");
    end


    // ==========================================
    // SECUENCIA PRINCIPAL DE PRUEBAS
    // ==========================================

    initial begin

        // Mantiene el reset durante cuatro ciclos.
        repeat (4) @(negedge clk);
        aresetn = 1'b1;

        // Comprueba los valores iniciales.
        if (busy_o !== 1'b0 ||
            valid_o !== 1'b0 ||
            new_data_o !== 1'b0)
            $fatal(1, "Error en estado inicial");


        // ======================================
        // PRUEBA 1: ADQUISICION POR PWM
        // ======================================

        $display("Prueba 1: adquisicion PWM");

        // Inicia la conversion por PWM.
        pulse_pwm();

        // Verifica el inicio de adquisicion.
        if (busy_o !== 1'b1 ||
            convst_o !== 1'b1)
            $fatal(1, "No inicio la conversion");

        // Intenta una solicitud adicional
        // mientras el ADC esta ocupado.
        pulse_sw();

        if (missed_trigger_o !== 1'b1)
            $fatal(1, "No detecto disparo ocupado");

        // El modelo XADC entrega 0x8000.
        complete_conversion(16'h8000);

        // Comprueba que se publico el dato.
        if (valid_o !== 1'b1 ||
            new_data_o !== 1'b1 ||
            busy_o !== 1'b0)
            $fatal(1, "Error en publicacion");

        // ID = 1, codigo ADC = 0x0800.
        check_sample(32'h0001_0800);


        // ======================================
        // PRUEBA 2: RECONOCIMIENTO
        // ======================================

        $display("Prueba 2: reconocimiento");

        // Simula que el procesador ha
        // reconocido la muestra anterior.
        acknowledge();

        if (new_data_o !== 1'b0)
            $fatal(1, "No reconocio la muestra");

        // Reconocer no debe borrar el dato.
        check_sample(32'h0001_0800);


        // ======================================
        // PRUEBA 3: SEGUNDA CONVERSION
        // ======================================

        $display("Prueba 3: segunda muestra");

        // Inicia por solicitud de software.
        pulse_sw();

        // Entrega una nueva palabra DRP.
        complete_conversion(16'hA000);

        // ID = 2, codigo ADC = 0x0A00.
        check_sample(32'h0002_0A00);

        if (valid_o !== 1'b1 ||
            new_data_o !== 1'b1)
            $fatal(1, "Segunda muestra no valida");


        // ======================================
        // PRUEBA 4: SOBRESCRITURA
        // ======================================

        $display("Prueba 4: sobrescritura");

        // La segunda muestra no se reconoce.
        // Se publica una tercera adquisicion.
        pulse_pwm();
        complete_conversion(16'h4000);

        // ID = 3, codigo ADC = 0x0400.
        check_sample(32'h0003_0400);

        // Debe detectar la sustitucion de
        // una muestra pendiente de reconocer.
        if (overrun_o !== 1'b1)
            $fatal(1, "No detecto sobrescritura");


        // ======================================
        // PRUEBA 5: TIMEOUT DE EOC
        // ======================================

        $display("Prueba 5: timeout de EOC");

        // Reinicia el controlador.
        @(negedge clk);
        aresetn = 1'b0;

        repeat (3) @(negedge clk);
        aresetn = 1'b1;

        // Solicita una conversion, pero el
        // XADC simulado nunca activa EOC.
        pulse_pwm();

        repeat (25) @(negedge clk);

        // Comprueba que se detecto el fallo.
        if (timeout_o !== 1'b1 ||
            busy_o !== 1'b0 ||
            valid_o !== 1'b0)
            $fatal(1, "Error en timeout de EOC");

        // Ninguna conversion incompleta
        // debe producir una muestra.
        if (sample_o !== 32'h0000_0000)
            $fatal(1, "Muestra modificada tras timeout");


        // ======================================
        // PRUEBA 6: TIMEOUT DE DRDY
        // ======================================

        $display("Prueba 6: timeout de DRDY");

        // Reinicia para una prueba independiente.
        @(negedge clk);
        aresetn = 1'b0;

        repeat (3) @(negedge clk);
        aresetn = 1'b1;

        // Solicita una conversion.
        pulse_sw();

        // Informa que termino la conversion.
        @(negedge clk);
        eoc_i = 1'b1;

        @(negedge clk);
        eoc_i = 1'b0;

        // Espera la lectura DRP.
        wait (den_o === 1'b1);

        // Verifica nuevamente el canal VAUX6.
        if (daddr_o !== ADC_ADDR ||
            dwe_o !== 1'b0)
            $fatal(1, "Error en lectura DRP");

        // No genera DRDY: simula ausencia
        // de respuesta en el registro.
        repeat (25) @(negedge clk);

        if (timeout_o !== 1'b1 ||
            busy_o !== 1'b0 ||
            valid_o !== 1'b0)
            $fatal(1, "Error en timeout de DRDY");


        // ======================================
        // RESULTADO FINAL
        // ======================================

        $display("--------------------------------");
        $display("RESULTADO: TEST PASSED");
        $display("--------------------------------");

        $finish;

    end

endmodule
