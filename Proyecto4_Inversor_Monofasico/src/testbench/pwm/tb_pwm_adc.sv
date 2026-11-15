`timescale 1ns / 1ps
// Integración digital PWM + adc_control real. EOC/DRDY son un modelo explícito;
// este TB no instancia el XADC analógico ni ejecuta instrucciones MicroBlaze.
module tb_pwm_adc;
    `include "pwm_axi_tb.svh"
    logic convst,den,dwe,adc_busy,valid_data,new_data,missed,overrun,adc_timeout;
    logic [6:0] address_drp;
    logic [31:0] sample,token,ack_id=0;
    logic ack=0,eoc=0,drdy=0;
    logic [15:0] data_drp=16'h1230;
    integer eoc_delay=-1, drdy_delay=-1, conversions=0, trigger_cycle=0;
    integer clock_count=0, model_publications=0, last_publication=0;

    adc_control adc (
        .clk(clk),.aresetn(aresetn),.pwm_trigger_i(trigger_adc),.start_sw_i(1'b0),
        .ack_sample_i(ack),.ack_id_i(ack_id),.eoc_i(eoc),.drdy_i(drdy),.do_i(data_drp),
        .convst_o(convst),.den_o(den),.daddr_o(address_drp),.dwe_o(dwe),
        .busy_o(adc_busy),.valid_o(valid_data),.new_data_o(new_data),
        .sample_o(sample),.sample_token_o(token),.missed_trigger_o(missed),
        .overrun_o(overrun),.timeout_o(adc_timeout)
    );

    // El modelo da EOC tras 100 ciclos y DRDY siete ciclos después de DEN.
    always @(negedge clk) begin
        if(!aresetn) begin
            eoc=0;drdy=0;eoc_delay=-1;drdy_delay=-1;
        end else begin
            eoc=0;drdy=0;
            if(convst) begin
                eoc_delay=100;
                conversions=conversions+1;
                data_drp=16'((12'h123+conversions-1)<<4);
            end
            if(eoc_delay==0) begin eoc=1;eoc_delay=-1;end
            else if(eoc_delay>0) eoc_delay=eoc_delay-1;
            if(den) drdy_delay=7;
            if(drdy_delay==0) begin drdy=1;drdy_delay=-1;end
            else if(drdy_delay>0) drdy_delay=drdy_delay-1;
        end
    end

    always @(posedge clk) begin
        #3;
        clock_count=clock_count+1;
        if(aresetn) begin
            if(trigger_adc) trigger_cycle=clock_count;
            if(token!=last_publication) begin
                check(token==last_publication+1,"una publicacion por conversion");
                check(clock_count-trigger_cycle<200,"dato disponible mucho antes de la lectura");
                last_publication=int'(token);
                model_publications=model_publications+1;
            end
            check(!missed && !overrun && !adc_timeout,"sin errores ADC durante control periodico");
            check(address_drp==7'h16 && !dwe,"lectura DRP de VAUX6");
        end
    end

    integer k,previous_id=0,old_active;
    initial begin
        reset_dut();
        write_reg(8,100,15,0,0,0,0);
        write_reg(12,5000,15,0,0,0,0);
        write_reg(0,1,15,0,0,0,0);
        // La primera lectura ocurre en el período siguiente al primer disparo.
        while(!period_start) tick();
        for(k=0;k<12;k=k+1) begin
            while(dut.core.phase_q!=100) tick();
            check(valid_data && new_data && !adc_busy,"ultima muestra completa sin esperar");
            check(sample[31:16]==previous_id+1,"ID avanza una muestra por control");
            check(sample[11:0]==12'h123+k,"dato conocido del modelo DRP");
            previous_id=int'(sample[31:16]);
            @(negedge clk); ack_id=token;ack=1;
            tick();@(negedge clk);ack=0;
            check(!new_data,"ACK consume la publicacion leida");
            old_active=$signed(dut.core.active_reference_q);
            write_reg(4,32'(1000*(k+1)),15,0,0,0,0);
            check($signed(dut.core.active_reference_q)==old_active,"orden pendiente hasta el valle");
            tick();while(!period_start) tick();
            check($signed(dut.core.active_reference_q)==1000*(k+1),"orden aplicada en periodo siguiente");
        end
        write_reg(0,0,15,0,0,0,0);
        check(previous_id==12 && conversions==13 && model_publications==13 && new_data,
              "doce muestras consumidas y siguiente disponible, sin perdida");
        check(!trigger_adc,"apagado suprime disparos");
        $display("TEST PASSED tb_pwm_adc checks=%0d",checks);
        $finish;
    end
endmodule
