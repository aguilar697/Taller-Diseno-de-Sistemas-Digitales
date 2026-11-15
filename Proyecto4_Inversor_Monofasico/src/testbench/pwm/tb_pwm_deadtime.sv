`timescale 1ns / 1ps
module tb_pwm_deadtime;
    logic clk=0,aresetn=0,enable=0,raw=0;
    always #5 clk=~clk;
    logic high_out,low_out;
    logic [31:0] delay_cycles=3;
    integer checks=0,j;
    pwm_deadtime dut(.clk(clk),.aresetn(aresetn),.enable_i(enable),.raw_high_i(raw),
        .deadtime_i(delay_cycles),.high_o(high_out),.low_o(low_out));
    task automatic tick; begin @(posedge clk); #1; end endtask
    task automatic check(input logic condition,input string message);
        begin if(condition!==1'b1) $fatal(1,"CHECK_FAILED: %s",message); checks=checks+1; end
    endtask
    initial begin
        repeat(2) tick(); @(negedge clk); aresetn=1;enable=1;raw=1;
        repeat(8) begin tick();check(!high_out&&!low_out,"esperar primer borde");end
        @(negedge clk); raw=0;
        tick();check(!high_out&&!low_out,"inicio espera");
        repeat(2) begin tick();check(!high_out&&!low_out,"tres ciclos sin conducir");end
        tick();check(low_out&&!high_out,"primera activacion inferior");
        @(negedge clk);raw=1;
        tick();check(!high_out&&!low_out,"apagar antes de cambiar");
        tick();
        @(negedge clk);raw=0; // Cancelar un objetivo durante la espera.
        tick();check(!high_out&&!low_out,"reiniciar espera con nuevo objetivo");
        repeat(2) begin tick();check(!high_out&&!low_out,"espera reiniciada");end
        tick();check(low_out&&!high_out,"no emitir orden descartada");
        @(negedge clk);raw=1; tick();
        @(negedge clk);enable=0;tick();
        check(!high_out&&!low_out,"disable durante espera");
        // Estado no reconocido: salida segura en el siguiente flanco.
        @(negedge clk); enable=1;
        force dut.state_q=3'b111;
        tick();check(!high_out&&!low_out,"estado invalido seguro");
        release dut.state_q;
        @(negedge clk); aresetn=0; #1;
        check(!high_out&&!low_out,"reset sin esperar reloj");
        $display("TEST PASSED tb_pwm_deadtime checks=%0d",checks);
        $finish;
    end
    initial begin #100000; $fatal(1,"TEST_TIMEOUT"); end
endmodule
