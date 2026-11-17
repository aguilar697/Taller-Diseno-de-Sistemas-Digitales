`timescale 1ns/1ps
// Verifica el permiso fisico del top con la plataforma sustituida por un modelo.
module tb_permiso_basys3;
  reg clk=0, rst=1, permiso=0;
  always #5 clk=~clk;
  wire ah,al,bh,bl,periodo;
  inversor_basys3 dut(.clk_i(clk),.reset_i(rst),.botones(3'b0),.amplitud(2'b0),
    .permiso_pwm(permiso),.uart_rx(1'b1),.vauxp6(1'b0),.vauxn6(1'b0),
    .pwm_ah(ah),.pwm_al(al),.pwm_bh(bh),.pwm_bl(bl),.pwm_period_start_o(periodo));
  task comprobar(input bit condicion, input string texto);
    if (!condicion) $fatal(1,"%s",texto);
  endtask
  initial begin
    #12; rst=0;
    repeat(5) @(negedge clk);
    comprobar({ah,al,bh,bl}==0,"SW15 bajo debe bloquear las cuatro salidas");
    permiso=1;
    repeat(3) @(negedge clk);
    comprobar({ah,al,bh,bl}==0,"Esperar frontera aunque el permiso este sincronizado");
    dut.plataforma.pulso=1;
    @(negedge clk); dut.plataforma.pulso=0;
    comprobar({ah,al,bh,bl}==4'b1001,"Habilitar en frontera de periodo");
    #2; permiso=0; #1;
    comprobar({ah,al,bh,bl}==0,"Deshabilitar sin esperar otro flanco");
    permiso=1; repeat(3) @(negedge clk);
    comprobar({ah,al,bh,bl}==0,"No rearmar con rebote sin otra frontera");
    dut.plataforma.pulso=1; @(negedge clk); dut.plataforma.pulso=0;
    rst=1; #1;
    comprobar({ah,al,bh,bl}==0,"Reset bloquea inmediatamente");
    $display("PERMISO_BASYS3_PASS: bloqueo, sincronizacion, frontera y reset");
    $finish;
  end
  initial begin #2000; $fatal(1,"timeout"); end
endmodule

module platform_microblaze_wrapper(
 input clk_i,reset_i,input [2:0] BUTTONS_tri_i,input [1:0] SWITCHES_tri_i,
 output [3:0] LEDS_tri_o,output ISR_DIAG_tri_o,input UART_0_rxd,output UART_0_txd,
 input vauxp6,vauxn6,output axi_clk_o,output pwm_ah,pwm_al,pwm_bh,pwm_bl,pwm_period_start_o);
 assign axi_clk_o=clk_i;
 reg pulso=0;
 assign {pwm_ah,pwm_al,pwm_bh,pwm_bl}=4'b1001;
 assign pwm_period_start_o=pulso;
 assign LEDS_tri_o=0; assign ISR_DIAG_tri_o=0; assign UART_0_txd=1;
endmodule
