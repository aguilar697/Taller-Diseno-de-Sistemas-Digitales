`timescale 1ns / 1ps
module tb_pwm_core;
    logic clk=0, aresetn=0, enable=0;
    always #5 clk=~clk;
    logic [1:0] frequency=0;
    logic signed [15:0] reference=0;
    logic [31:0] deadtime=100, phi=5000;
    logic running, ah,al,bh,bl,trigger_adc,period_start;
    integer checks=0, cycles=0, phase=-1, last_start=-1;
    integer fall_ah=-100000,fall_al=-100000,fall_bh=-100000,fall_bl=-100000;
    logic previous_ah=0,previous_al=0,previous_bh=0,previous_bl=0,previous_trigger=0;
    pwm_core dut(.clk(clk),.aresetn(aresetn),.enable_i(enable),.freq_sel_i(frequency),
        .reference_i(reference),.deadtime_i(deadtime),.trigger_phase_i(phi),.running_o(running),
        .pwm_ah(ah),.pwm_al(al),.pwm_bh(bh),.pwm_bl(bl),
        .pwm_trigger_o(trigger_adc),.pwm_period_start_o(period_start));

    task automatic check(input logic condition,input string message);
        begin
            if(condition!==1'b1) $fatal(1,"CHECK_FAILED: %s cycle=%0d",message,cycles);
            checks=checks+1;
        end
    endtask
    task automatic tick;
        begin @(posedge clk); #1; end
    endtask

    // Verificación por propiedades externas: período, anchura y separación de flancos.
    always @(posedge clk) begin
        #2;
        cycles=cycles+1;
        if (!aresetn || !enable) begin
            check({ah,al,bh,bl,trigger_adc,period_start}===0,"reset o apagado");
            phase=-1; last_start=-1;
            previous_ah=0;previous_al=0;previous_bh=0;previous_bl=0;previous_trigger=0;
            fall_ah=-100000;fall_al=-100000;fall_bh=-100000;fall_bl=-100000;
        end else begin
            check((^{ah,al,bh,bl,trigger_adc,period_start})!==1'bx,"salidas conocidas");
            check(!(ah&&al) && !(bh&&bl),"ausencia de solapamiento");
            if(period_start) begin
                if(last_start>=0) check(cycles-last_start==(frequency==0?10000:frequency==1?5000:4000),"periodo exacto");
                last_start=cycles; phase=0;
            end else phase=phase+1;
            check(trigger_adc===(phase==phi),"fase del trigger");
            check(!(trigger_adc&&previous_trigger),"trigger dura un ciclo");
            if(previous_ah&&!ah) fall_ah=cycles;
            if(previous_al&&!al) fall_al=cycles;
            if(previous_bh&&!bh) fall_bh=cycles;
            if(previous_bl&&!bl) fall_bl=cycles;
            if(ah&&!previous_ah) check(cycles-fall_al>=deadtime,"tiempo muerto A superior");
            if(al&&!previous_al) check(cycles-fall_ah>=deadtime,"tiempo muerto A inferior");
            if(bh&&!previous_bh) check(cycles-fall_bl>=deadtime,"tiempo muerto B superior");
            if(bl&&!previous_bl) check(cycles-fall_bh>=deadtime,"tiempo muerto B inferior");
            previous_ah=ah; previous_al=al; previous_bh=bh; previous_bl=bl; previous_trigger=trigger_adc;
        end
    end

    task automatic run_case(input integer freq, input integer q, input integer raw_a_count,
                             input integer phase_trigger, input integer d);
        integer p, ca,cb,cla,clb,ct,k;
        begin
            @(negedge clk); enable=0;
            repeat(2) tick();
            @(negedge clk);
            frequency=2'(freq); reference=16'(q); phi=32'(phase_trigger); deadtime=32'(d); enable=1;
            tick(); check(period_start,"arranque desde fase cero");
            check(!ah&&!al&&!bh&&!bl,"arranque sin pulso parcial");
            // Un período completo permite superar la sincronización inicial.
            tick(); while(!period_start) tick();
            p=freq==0?10000:freq==1?5000:4000;
            ca=0;cb=0;cla=0;clb=0;ct=0;
            for(k=0;k<p;k=k+1) begin
                ca=ca+int'(ah);cb=cb+int'(bh);cla=cla+int'(al);clb=clb+int'(bl);ct=ct+int'(trigger_adc);
                tick();
            end
            check(ca==raw_a_count-d,"duracion superior A por periodo");
            check(cb==p-raw_a_count-d,"duracion superior B por periodo");
            check(cla==p-raw_a_count-d,"duracion inferior A por periodo");
            check(clb==raw_a_count-d,"duracion inferior B por periodo");
            check(ct==1,"una adquisicion por periodo");
        end
    endtask

    integer f,p,maximum_a;
    initial begin
        repeat(3) tick(); @(negedge clk); aresetn=1;
        for(f=0;f<3;f=f+1) begin
            p=f==0?10000:f==1?5000:4000;
            maximum_a=f==0?9250:f==1?4626:3700;
            run_case(f,0,p/2,p/2,100);
            run_case(f,16384,3*p/4,0,100);
            run_case(f,-16384,p/4,p-1,100);
            run_case(f,27853,maximum_a,p/2,100);
            run_case(f,-27853,p-maximum_a,p/2,100);
            run_case(f,1,p/2,1,1);
            run_case(f,-1,p/2,p-2,3);
        end
        // Reset asíncrono mientras hay actuación.
        while(!ah && !al) tick();
        @(negedge clk); aresetn=0; #1;
        check({ah,al,bh,bl,trigger_adc,period_start}===0,"apagado asincrono");
        @(negedge clk); enable=0;
        repeat(2) tick();
        $display("TEST PASSED tb_pwm_core checks=%0d",checks);
        $finish;
    end
    initial begin #50000000; $fatal(1,"TEST_TIMEOUT"); end
endmodule
