`timescale 1ns / 1ps
// PWM y ADC superiores reales, maestro AXI de prueba y XADC digital modelado.
// No hay CPU, PR ejecutandose, SmartConnect ni medicion analogica en este TB.
module tb_pwm_adc_axi;
    logic clk=0, resetn=0;
    always #5 clk=~clk;
    logic [11:0] awaddr[2], araddr[2];
    logic [31:0] wdata[2], rdata[2];
    logic [3:0] wstrb[2];
    logic [1:0] awvalid=0,awready,wvalid=0,wready,bvalid,bready=0;
    logic [1:0] arvalid=0,arready,rvalid,rready=0;
    logic [1:0] bresp[2], rresp[2];
    logic ah,al,bh,bl,trigger_adc,period_start;
    integer verificaciones=0, periodos=0, disparos=0, publicaciones=0;
    integer ciclo=0, inicio=-1, disparo=-1, convst=-1;
    integer ultimo_a=-10000, ultimo_b=-10000;
    integer activaciones_a=0, activaciones_b=0;
    logic ant_ah=0,ant_al=0,ant_bh=0,ant_bl=0,ant_inicio=0,ant_disparo=0;
    logic [31:0] token_anterior=0;
    logic observar_referencia=0, referencia_comprobada=0;

`define PUERTOS_AXI(N) \
    .s_axi_aclk(clk),.s_axi_aresetn(resetn), \
    .s_axi_awaddr(awaddr[N]),.s_axi_awprot(3'b0), \
    .s_axi_awvalid(awvalid[N]),.s_axi_awready(awready[N]), \
    .s_axi_wdata(wdata[N]),.s_axi_wstrb(wstrb[N]), \
    .s_axi_wvalid(wvalid[N]),.s_axi_wready(wready[N]), \
    .s_axi_bresp(bresp[N]),.s_axi_bvalid(bvalid[N]),.s_axi_bready(bready[N]), \
    .s_axi_araddr(araddr[N]),.s_axi_arprot(3'b0), \
    .s_axi_arvalid(arvalid[N]),.s_axi_arready(arready[N]), \
    .s_axi_rdata(rdata[N]),.s_axi_rresp(rresp[N]), \
    .s_axi_rvalid(rvalid[N]),.s_axi_rready(rready[N])
    pwm_system_axi #(.ADDR_WIDTH(12),.MIN_ON_CYCLES(100)) pwm (
        `PUERTOS_AXI(0), .pwm_ah(ah),.pwm_al(al),.pwm_bh(bh),.pwm_bl(bl),
        .pwm_trigger_o(trigger_adc),.pwm_period_start_o(period_start)
    );
    adc_system_axi #(.ADDR_WIDTH(12),.ADC_TIMEOUT_CYCLES(1024)) adc (
        `PUERTOS_AXI(1), .pwm_trigger_i(trigger_adc),.vauxp6(1'b0),.vauxn6(1'b0)
    );
`undef PUERTOS_AXI
    task automatic verificar(input logic condicion,input string mensaje);
        if(condicion!==1'b1) $fatal(1,"FALLO: %s",mensaje);
        verificaciones++;
    endtask
    task automatic tick;
        @(posedge clk); #2;
    endtask
    // AW/W independientes, estimulos lejos del flanco de muestreo.
    task automatic escribir(input integer destino,input logic[11:0] direccion,
                             input logic[31:0] dato);
        fork
            begin
                @(negedge clk); awaddr[destino]=direccion; awvalid[destino]=1;
                @(posedge clk); while(!awready[destino]) @(posedge clk);
                @(negedge clk); awvalid[destino]=0;
            end
            begin
                @(negedge clk); wdata[destino]=dato;wstrb[destino]=15;wvalid[destino]=1;
                @(posedge clk); while(!wready[destino]) @(posedge clk);
                @(negedge clk); wvalid[destino]=0;
            end
        join
        while(!bvalid[destino]) tick();
        verificar(bresp[destino]===0,"respuesta AXI de escritura OKAY");
        @(negedge clk); bready[destino]=1;
        @(posedge clk); @(negedge clk); bready[destino]=0;
    endtask
    task automatic leer(input integer destino,input logic[11:0] direccion,
                        output logic[31:0] dato);
        @(negedge clk); araddr[destino]=direccion;arvalid[destino]=1;
        @(posedge clk); while(!arready[destino]) @(posedge clk);
        @(negedge clk); arvalid[destino]=0;
        while(!rvalid[destino]) tick();
        verificar(rresp[destino]===0,"respuesta AXI de lectura OKAY");
        dato=rdata[destino];
        @(negedge clk); rready[destino]=1;
        @(posedge clk); @(negedge clk); rready[destino]=0;
    endtask

    // Observacion interna sin force/release: mide las fronteras de publicacion.
    always @(posedge clk) begin
        #1; ciclo++;
        if(resetn) begin
            verificar(!$isunknown({ah,al,bh,bl,trigger_adc,period_start}),"salidas conocidas");
            verificar(!(ah&&al) && !(bh&&bl),"sin conduccion simultanea");
            verificar(adc.pwm_trigger_i===trigger_adc,"conexion directa de trigger");
            if(observar_referencia && !referencia_comprobada) begin
                if(period_start) begin
                    verificar(pwm.core.active_reference_q==1000,"REFERENCE cambia exactamente en period_start");
                    referencia_comprobada=1;
                    $display("EVENTO REFERENCE_captura ciclo=%0d",ciclo);
                end else verificar(pwm.core.active_reference_q==0,"REFERENCE no cambia antes del periodo");
            end
            if(period_start) begin
                verificar(!ant_inicio,"period_start de un ciclo");
                if(inicio>=0) verificar(ciclo-inicio==10000,"10 kHz: periodo de 10000 ciclos");
                inicio=ciclo;periodos++;
                $display("EVENTO periodo ciclo=%0d tiempo=%0t",ciclo,$time);
            end
            if(trigger_adc) begin
                verificar(!ant_disparo,"trigger de un ciclo");
                verificar(ciclo-inicio==5000,"TRIGGER_PHASE=5000");
                disparo=ciclo;disparos++;
                $display("EVENTO trigger ciclo=%0d fase=%0d",ciclo,ciclo-inicio);
            end
            if(adc.u_adc.convst) begin
                convst=ciclo;
                verificar(ciclo-disparo==1,"ADC acepta trigger en siguiente flanco");
            end
            if(adc.sample_token!=token_anterior) begin
                verificar(adc.sample_token==token_anterior+1,"una publicacion por conversion");
                verificar(ciclo-convst==110,"latencia digital CONVST a SAMPLE: 110 ciclos");
                $display("MEDICION trigger_SAMPLE=%0d ciclos CONVST_SAMPLE=%0d ciclos",
                         ciclo-disparo,ciclo-convst);
                token_anterior=adc.sample_token;publicaciones++;
            end
            if((ant_ah&&!ah)||(ant_al&&!al)) ultimo_a=ciclo;
            if((ant_bh&&!bh)||(ant_bl&&!bl)) ultimo_b=ciclo;
            if((!ant_ah&&ah)||(!ant_al&&al)) begin
                if(activaciones_a>0) verificar(ciclo-ultimo_a==100,"tiempo muerto rama A: 100 ciclos");
                activaciones_a++;
            end
            if((!ant_bh&&bh)||(!ant_bl&&bl)) begin
                if(activaciones_b>0) verificar(ciclo-ultimo_b==100,"tiempo muerto rama B: 100 ciclos");
                activaciones_b++;
            end
            verificar(!adc.missed_trigger&&!adc.overrun&&!adc.timeout,"ADC sin errores nominales");
        end
        {ant_ah,ant_al,ant_bh,ant_bl}={ah,al,bh,bl};
        ant_inicio=period_start;ant_disparo=trigger_adc;
    end
    logic [31:0] dato,muestra,token;
    initial begin
        foreach(awaddr[i]) begin awaddr[i]=0;araddr[i]=0;wdata[i]=0;wstrb[i]=0;end
        repeat(4) tick();
        verificar({ah,al,bh,bl,trigger_adc,period_start}===0,"reset bajo de PWM");
        verificar(adc.sample===0 && adc.sample_token===0,"reset bajo de ADC");
        @(negedge clk);resetn=1;
        leer(0,0,dato);verificar(dato==0,"PWM deshabilitado al salir de reset");
        leer(1,4,dato);verificar(dato==0,"STATUS ADC inicial");
        escribir(0,8,100);escribir(0,12,5000);escribir(0,4,0);
        escribir(0,0,1);
        leer(0,0,dato);verificar(dato==9,"PWM enable y running");
        wait(publicaciones==1);tick();
        leer(1,4,dato);verificar(dato==3,"STATUS valid y new_data");
        leer(1,8,muestra);verificar(muestra==32'h00010123,"SAMPLE conocido del modelo digital");
        leer(1,16,token);verificar(token==1,"token snapshot inicial");
        escribir(1,16,token^32'h00010000);
        leer(1,4,dato);verificar(dato==3,"ACK con mismos 16 bits bajos y generacion distinta no consume");
        escribir(1,16,token);
        leer(1,4,dato);verificar(dato==1,"ACK completo limpia solo new_data");
        observar_referencia=1;
        escribir(0,4,1000);
        $display("EVENTO escritura_REFERENCE_fin ciclo=%0d fase=%0d",ciclo,ciclo-inicio);
        verificar(pwm.core.active_reference_q==0,"REFERENCE pendiente durante periodo actual");
        wait(periodos==2);tick();
        verificar(pwm.core.active_reference_q==1000,"REFERENCE aplicada en siguiente periodo");
        verificar(referencia_comprobada,"monitor comprobo frontera exacta de REFERENCE");
        $display("EVENTO REFERENCE_aplicada ciclo=%0d periodo_inicio=%0d",ciclo,inicio);
        wait(publicaciones==2);tick();
        escribir(1,16,token);
        leer(1,4,dato);verificar(dato==3,"ACK anterior no consume nueva muestra");
        leer(1,8,muestra);verificar(muestra==32'h00020124,"segunda muestra correcta");
        leer(1,16,token);verificar(token==2,"segundo token completo");
        escribir(1,16,token);
        leer(1,4,dato);verificar(dato==1,"segundo ACK correcto");
        leer(1,12,dato);verificar(dato==0,"ERROR nominal en cero");
        verificar(periodos==2 && disparos==2 && publicaciones==2,"conteos de eventos sin perdida");
        verificar(activaciones_a>2 && activaciones_b>2,"ambas ramas ejercitadas");
        escribir(0,0,0);repeat(3) tick();
        verificar({ah,al,bh,bl,trigger_adc,period_start}===0,"apagado seguro digital");
        // Para comprobar el autoverificador: +INJECT_ERROR cambia solo el esperado.
        if($test$plusargs("INJECT_ERROR")) verificar(muestra==0,"ERROR_INYECTADO_DETECTADO");
        $display("TEST PASSED tb_pwm_adc_axi verificaciones=%0d",verificaciones);
        $finish;
    end
    initial begin #2000000; $fatal(1,"Watchdog PWM-ADC AXI"); end
endmodule
