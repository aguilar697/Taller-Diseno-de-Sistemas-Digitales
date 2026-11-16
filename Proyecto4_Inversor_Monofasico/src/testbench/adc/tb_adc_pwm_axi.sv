`timescale 1ns / 1ps
// Verifica el ADC como periférico AXI, disparado por el PWM y con XADC de Vivado.
// El maestro de prueba selecciona dos buses AXI completos y registra sus resultados.
module tb_adc_pwm_axi;
    `include "adc_axi_tb_tasks.svh"

    logic select_pwm = 0;
    logic adc_awready, adc_wready, adc_bvalid, adc_arready, adc_rvalid;
    logic pwm_awready, pwm_wready, pwm_bvalid, pwm_arready, pwm_rvalid;
    logic [1:0] adc_bresp, adc_rresp, pwm_bresp, pwm_rresp;
    logic [31:0] adc_rdata, pwm_rdata;
    logic ah, al, bh, bl, pwm_trigger, pwm_period_start;
    logic monitor_enable = 0;
    logic previous_trigger = 0, previous_period = 0;
    logic previous_convst = 0, previous_den = 0;
    logic [31:0] previous_token = 0;
    integer cycle_count = 0, period_cycle = 0, trigger_cycle = 0, convst_cycle = 0;
    integer periods = 0, triggers = 0, conversions = 0, publications = 0;
    integer off_a = 0, off_b = 0, cases_passed = 0;
    integer min_off_a = 2147483647, min_off_b = 2147483647;
    integer max_latency_cycles = 0, trace_file;
    logic [31:0] status_word, sample_word, saved_word, saved_token, token_word;

    // La selección pertenece al maestro del TB y solo cambia con ambos buses vacíos.
    // Cada esclavo conserva su propia interfaz; no se modelan SmartConnect ni CPU.
    assign awready = select_pwm ? pwm_awready : adc_awready;
    assign wready = select_pwm ? pwm_wready : adc_wready;
    assign bvalid = select_pwm ? pwm_bvalid : adc_bvalid;
    assign bresp = select_pwm ? pwm_bresp : adc_bresp;
    assign arready = select_pwm ? pwm_arready : adc_arready;
    assign rvalid = select_pwm ? pwm_rvalid : adc_rvalid;
    assign rresp = select_pwm ? pwm_rresp : adc_rresp;
    assign rdata = select_pwm ? pwm_rdata : adc_rdata;

    adc_system_axi dut_adc (
        .s_axi_aclk(clk), .s_axi_aresetn(resetn),
        .s_axi_awaddr(awaddr), .s_axi_awprot(awprot),
        .s_axi_awvalid(awvalid && !select_pwm), .s_axi_awready(adc_awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb),
        .s_axi_wvalid(wvalid && !select_pwm), .s_axi_wready(adc_wready),
        .s_axi_bresp(adc_bresp), .s_axi_bvalid(adc_bvalid),
        .s_axi_bready(bready && !select_pwm),
        .s_axi_araddr(araddr), .s_axi_arprot(arprot),
        .s_axi_arvalid(arvalid && !select_pwm), .s_axi_arready(adc_arready),
        .s_axi_rdata(adc_rdata), .s_axi_rresp(adc_rresp), .s_axi_rvalid(adc_rvalid),
        .s_axi_rready(rready && !select_pwm),
        .pwm_trigger_i(pwm_trigger), .vauxp6(1'b0), .vauxn6(1'b0)
    );

    pwm_system_axi dut_pwm (
        .s_axi_aclk(clk), .s_axi_aresetn(resetn),
        .s_axi_awaddr(awaddr), .s_axi_awprot(awprot),
        .s_axi_awvalid(awvalid && select_pwm), .s_axi_awready(pwm_awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb),
        .s_axi_wvalid(wvalid && select_pwm), .s_axi_wready(pwm_wready),
        .s_axi_bresp(pwm_bresp), .s_axi_bvalid(pwm_bvalid),
        .s_axi_bready(bready && select_pwm),
        .s_axi_araddr(araddr), .s_axi_arprot(arprot),
        .s_axi_arvalid(arvalid && select_pwm), .s_axi_arready(pwm_arready),
        .s_axi_rdata(pwm_rdata), .s_axi_rresp(pwm_rresp), .s_axi_rvalid(pwm_rvalid),
        .s_axi_rready(rready && select_pwm),
        .pwm_ah(ah), .pwm_al(al), .pwm_bh(bh), .pwm_bl(bl),
        .pwm_trigger_o(pwm_trigger), .pwm_period_start_o(pwm_period_start)
    );

    assign start_observed = dut_adc.start_sw;
    assign ack_observed = dut_adc.ack_sample;
    assign ack_id_observed = dut_adc.ack_id;

    task automatic check(input logic condition, input string description);
        if (condition !== 1'b1) $fatal(1,"ADC_PERIPHERAL_FAILED: %s",description);
    endtask

    task automatic record_transfer(input string event_name,
        input logic [15:0] event_id, input logic [31:0] event_token);
        $fdisplay(trace_file,"%0d,%s,%0d,%08h,%0d,%08h,%0b",$time,event_name,
            event_id,event_token,dut_adc.sample[31:16],dut_adc.sample_token,dut_adc.new_data);
    endtask

    task automatic record_event(input string event_name);
        record_transfer(event_name,dut_adc.sample[31:16],dut_adc.sample_token);
    endtask

    task automatic passed(input string description);
        cases_passed++;
        $display("CASO PERIFERICO %0d: %s PASS",cases_passed,description);
    endtask

    task automatic select_target(input logic target_pwm);
        @(negedge clk);
        check(!awvalid && !wvalid && !arvalid && !adc_bvalid && !adc_rvalid &&
            !pwm_bvalid && !pwm_rvalid,"seleccion con transaccion pendiente");
        select_pwm = target_pwm;
    endtask

    task automatic wait_read_phase(input logic [15:0] expected_id);
        // Representa una lectura periódica elegida por el TB; no simula AXI Timer.
        while (dut_pwm.core.phase_q != 100 || dut_adc.sample[31:16] != expected_id)
            @(negedge clk);
    endtask

    task automatic check_sample(input logic [31:0] word, input logic [15:0] id);
        check(!$isunknown(word) && word[31:16] == id && word[15:12] == 0,
            "ID y formato de SAMPLE");
        check(word[11:0] >= 12'he62 && word[11:0] <= 12'he6a,
            "codigo XADC del estimulo de 0,9 V");
        $display("PERIFERICO_SAMPLE: id=%0d palabra=%08h",id,word);
        record_transfer("READ_SAMPLE",word[31:16],dut_adc.u_axi.read_sample_token);
    endtask

    task automatic check_pending(input logic expected);
        read_tx(4,0,0,status_word);
        check(status_word[1] == expected,"new_data despues del reconocimiento");
    endtask

    // Observación pasiva de reloj, conversión y PWM; no se fuerza ninguna señal del DUT.
    always @(posedge clk) begin
        #1;
        cycle_count++;
        if (monitor_enable && resetn) begin
            check(!$isunknown({ah,al,bh,bl,pwm_trigger,pwm_period_start}),
                "salidas PWM conocidas");
            check(!(ah && al) && !(bh && bl),"ausencia de solapamiento logico");
            if (!ah && !al) off_a++;
            else begin
                if (off_a > 0) begin
                    check(off_a >= 100,"tiempo muerto de rama A");
                    if (off_a < min_off_a) min_off_a = off_a;
                end
                off_a = 0;
            end
            if (!bh && !bl) off_b++;
            else begin
                if (off_b > 0) begin
                    check(off_b >= 100,"tiempo muerto de rama B");
                    if (off_b < min_off_b) min_off_b = off_b;
                end
                off_b = 0;
            end
            check(!(pwm_trigger && previous_trigger),"disparo de un ciclo");
            check(!(pwm_period_start && previous_period),"marca de periodo de un ciclo");
            check(!(dut_adc.u_adc.convst && previous_convst),"CONVST de un ciclo");
            check(!(dut_adc.u_adc.den && previous_den),"DEN de un ciclo");
            check(!dut_adc.missed_trigger && !dut_adc.timeout,"sin disparos perdidos ni timeout");
            if (pwm_period_start) begin
                if (periods > 0) check(cycle_count-period_cycle == 10000,"PWM de 10 kHz");
                period_cycle = cycle_count;
                periods++;
                record_event("PERIOD");
            end
            if (pwm_trigger) begin
                check(cycle_count-period_cycle == 5000,"TRIGGER_PHASE igual a 5000");
                trigger_cycle = cycle_count;
                triggers++;
                record_event("TRIGGER");
            end
            if (dut_adc.u_adc.convst) begin
                check(cycle_count-trigger_cycle == 1,"captura sincrona del disparo PWM");
                convst_cycle = cycle_count;
                conversions++;
                record_event("CONVST");
            end
            if (dut_adc.u_adc.eoc)
                check(dut_adc.u_adc.adc_channel == 5'h16,"canal VAUX6");
            if (dut_adc.u_adc.den) begin
                check(dut_adc.u_adc.daddr == 7'h16 && !dut_adc.u_adc.dwe,
                    "direccion y lectura DRP");
                record_event("DEN");
            end
            if (dut_adc.sample_token != previous_token) begin
                check(dut_adc.sample_token == previous_token+1,"una publicacion por conversion");
                check(cycle_count-trigger_cycle < 5000,"publicacion antes del siguiente periodo");
                if (cycle_count-convst_cycle > max_latency_cycles)
                    max_latency_cycles = cycle_count-convst_cycle;
                publications++;
                $display("PERIFERICO_LATENCIA: id=%0d convst_sample=%0d ciclos trigger_sample=%0d ciclos",
                    dut_adc.sample[31:16],cycle_count-convst_cycle,cycle_count-trigger_cycle);
                record_event("PUBLISH");
            end
            if (ack_observed) record_transfer("ACK_CMD",ack_id_observed[15:0],ack_id_observed);
            previous_token = dut_adc.sample_token;
            previous_trigger = pwm_trigger;
            previous_period = pwm_period_start;
            previous_convst = dut_adc.u_adc.convst;
            previous_den = dut_adc.u_adc.den;
        end
    end

    initial begin
        trace_file = $fopen("adc_peripheral_trace.csv","w");
        check(trace_file != 0,"archivo de evidencia");
        $fdisplay(trace_file,"time_ns,event,event_id,event_token,live_id,live_token,new_data");

        // Caso 1: reset, mapa y respuesta de un offset ADC no implementado.
        reset_bus();
        repeat (5000) @(negedge clk);
        read_tx(4,0,0,status_word); check(status_word == 0,"STATUS inicial");
        read_tx(8,0,0,sample_word); check(sample_word == 0,"SAMPLE inicial");
        read_tx(16,0,0,token_word); check(token_word == 0,"ACK_ID inicial");
        read_tx(20,2,0,status_word); check(status_word == 0,"offset ADC invalido");
        passed("reset y registros del periferico ADC");

        // Caso 2: configurar el PWM mediante sus canales AXI reales, con AW/W separados.
        select_target(1);
        write_tx(8,100,15,0,3,2,0);
        write_tx(12,5000,15,3,0,2,0);
        write_tx(4,0,15,0,0,0,0);
        read_tx(8,0,2,status_word); check(status_word == 100,"DEADTIME configurado");
        read_tx(12,0,2,status_word); check(status_word == 5000,"fase configurada");
        monitor_enable = 1;
        write_tx(0,1,15,0,0,0,0);
        read_tx(0,0,0,status_word); check(status_word == 9,"PWM habilitado a 10 kHz");
        select_target(0);
        passed("PWM AXI con 100 MHz, D100 y fase 5000");

        // Caso 3: cuatro adquisiciones XADC, lectura coherente y actualización PWM diferida.
        for (integer id=1; id<=4; id++) begin
            wait_read_phase(16'(id));
            read_tx(4,0,0,status_word); check(status_word == 3,"muestra lista en fase de lectura");
            read_tx(8,0,3,sample_word); check_sample(sample_word,16'(id));
            read_tx(16,0,2,token_word); check(token_word == id,"token de la muestra leida");
            write_tx(16,token_word,15,0,3,2,0);
            check_pending(0);
            read_tx(12,0,0,status_word); check(status_word == 0,"adquisicion nominal sin errores");
            select_target(1);
            write_tx(4,32'(id*1000),15,2,0,2,0);
            check($signed(dut_pwm.core.active_reference_q) == (id-1)*1000,
                "referencia pendiente hasta el siguiente periodo");
            while (!pwm_period_start) @(negedge clk);
            check($signed(dut_pwm.core.active_reference_q) == id*1000,
                "referencia aplicada en limite de periodo");
            select_target(0);
        end
        passed("cuatro muestras por AXI y referencia aplicada en el periodo siguiente");

        // Caso 4: otra conversion completa entre SAMPLE5 y ACK_ID debe conservar token5.
        wait_read_phase(5);
        read_tx(8,0,0,saved_word); check_sample(saved_word,5);
        wait (dut_adc.sample[31:16] == 6);
        read_tx(16,0,0,saved_token); check(saved_token == 5,"snapshot no sigue a la muestra viva");
        write_tx(16,saved_token,15,0,2,2,0);
        check_pending(1);
        read_tx(12,0,0,status_word); check(status_word == 2,"sobrescritura diagnosticada");
        passed("ACK5 atrasado conserva new_data de la muestra6");

        // Caso 5: retener R de SAMPLE6 mientras PWM y XADC publican la muestra7.
        begin_read(8); saved_word = rdata;
        wait (dut_adc.sample[31:16] == 7);
        @(negedge clk);
        check(rvalid && rdata == saved_word && rresp == 0,"respuesta estable durante conversion");
        check_sample(saved_word,6);
        rready = 1;
        @(negedge clk); rready = 0;
        read_tx(16,0,0,saved_token); check(saved_token == 6,"token del SAMPLE retenido");
        write_tx(16,saved_token,15,0,0,0,0); check_pending(1);
        passed("RREADY detenido durante una publicacion XADC");

        // Caso 6: ACK valido, duplicado viejo y rechazo del mecanismo CONTROL.bit1.
        read_tx(8,0,0,sample_word); check_sample(sample_word,7);
        read_tx(16,0,0,token_word); check(token_word == 7,"token7 vigente");
        write_tx(16,token_word,15,0,0,0,0); check_pending(0);
        wait (dut_adc.sample[31:16] == 8);
        write_tx(16,token_word,15,0,0,0,0); check_pending(1);
        write_tx(0,2,1,0,0,0,2); check_pending(1);
        read_tx(8,0,0,sample_word); check_sample(sample_word,8);
        read_tx(16,0,0,token_word); check(token_word == 8,"token8 vigente");
        write_tx(16,token_word,15,0,0,0,0);
        write_tx(16,token_word,15,0,0,0,0); check_pending(0);
        passed("ACK valido y duplicado sin consumir publicaciones ajenas");

        // Caso 7: apagar por AXI debe detener nuevos disparos y publicaciones.
        select_target(1);
        write_tx(0,0,15,0,0,0,0);
        repeat (10050) @(negedge clk);
        check({ah,al,bh,bl,pwm_trigger,pwm_period_start} == 0,"PWM apagado");
        check(triggers == 8 && conversions == 8 && publications == 8,
            "ocho disparos, conversiones y publicaciones sin duplicaciones");
        check(dut_adc.sample[31:16] == 8,"sin publicaciones despues del apagado");
        check(min_off_a == 100 && min_off_b == 100,"separacion minima medida de 1 us");
        passed("apagado PWM sin conversiones adicionales");

        // Caso 8: reset comun invalida muestra, snapshot y errores persistentes.
        monitor_enable = 0;
        select_target(0);
        reset_bus();
        read_tx(4,0,0,status_word); check((status_word & 32'h77) == 0,"estado digital tras reset");
        read_tx(8,0,0,sample_word); check(sample_word == 0,"muestra invalidada por reset");
        read_tx(16,0,0,token_word); check(token_word == 0,"snapshot invalidado por reset");
        read_tx(12,0,0,status_word); check(status_word == 0,"errores borrados por reset");
        check(start_count == 0,"adquisicion iniciada exclusivamente por PWM");
        passed("reset del periferico y cancelacion del snapshot");

        check(cases_passed == 8,"casos completos");
        $display("PERIFERICO_RESUMEN: casos=%0d periodos=%0d disparos=%0d conversiones=%0d publicaciones=%0d latencia_max=%0d ciclos",
            cases_passed,periods,triggers,conversions,publications,max_latency_cycles);
        $display("PERIFERICO_TIEMPO_MUERTO: rama_a=%0d ciclos rama_b=%0d ciclos",min_off_a,min_off_b);
        $display("ADC PWM AXI + XADC: 8/8 CASOS; TEST PASSED");
        $fclose(trace_file);
        $finish;
    end
endmodule
