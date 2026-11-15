`timescale 1ns / 1ps
// Prueba de puertos externos, utilizable también sobre la netlist con SDF.
module tb_pwm_timing;
    `include "pwm_axi_tb.svh"
    realtime boundary, previous_boundary, last_a_off=0, last_b_off=0;
    integer periods=0;
    bit watch_gaps=0;
`ifdef PWM_TIMING_SDF
    initial begin
        // El ejecutor anota mediante --sdfmax en el ámbito completo del DUT.
        $display("PWM_SDF_MAXIMUM_ENABLED");
    end
`endif

    always @(negedge ah) if (watch_gaps) last_a_off=$realtime;
    always @(negedge al) if (watch_gaps) last_a_off=$realtime;
    always @(negedge bh) if (watch_gaps) last_b_off=$realtime;
    always @(negedge bl) if (watch_gaps) last_b_off=$realtime;
    // Se tolera un ciclo de desfase entre retardos de salida distintos.
    always @(posedge ah or posedge al)
        if (watch_gaps) check($realtime-last_a_off>=990.0,"separacion temporal rama A");
    always @(posedge bh or posedge bl)
        if (watch_gaps) check($realtime-last_b_off>=990.0,"separacion temporal rama B");

    initial begin
        // La simulación de primitivas mantiene GSR durante los primeros 100 ns.
        repeat(30) tick();
        reset_dut();
        read_reg(0,0,0,2);
        write_reg(8,100,15,0,0,2,2);
        write_reg(12,5000,15,0,2,0,1);
        write_reg(4,32'h00007fff,15,0,0,0,0);
        read_reg(4,27853,0,2);
        write_reg(4,0,15,0,0,0,0);
        write_reg(0,1,15,0,0,0,0);
        read_reg(0,9,0,1);
        @(posedge period_start); previous_boundary=$realtime;
        watch_gaps=1;
        repeat(3) begin
            boundary=previous_boundary;
            @(posedge trigger_adc);
            check(($realtime-boundary>49990.0)&&($realtime-boundary<50010.0),
                  "disparo a mitad del periodo");
            @(negedge trigger_adc);
            check(($realtime-boundary>50000.0)&&($realtime-boundary<50020.0),
                  "pulso ADC de un ciclo");
            @(posedge period_start);
            check(($realtime-previous_boundary>99990.0)&&
                  ($realtime-previous_boundary<100010.0),"periodo de 100 us");
            previous_boundary=$realtime; periods=periods+1;
        end
        write_reg(4,16384,15,0,0,0,0);
        repeat(11000) tick();
        write_reg(8,99,15,2,0,0,0);
        write_reg(0,0,15,0,0,0,0);
        repeat(3) tick(); watch_gaps=0;
        check({ah,al,bh,bl,trigger_adc,period_start}===6'b0,"apagado de la netlist");
        read_reg(0,0,0,2);
        reset_dut();
        $display("TEST PASSED tb_pwm_timing checks=%0d periods=%0d",checks,periods);
        $finish;
    end
endmodule
