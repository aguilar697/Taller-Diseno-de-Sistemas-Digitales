`timescale 1ns/1ps
module uart_tx_tb;
    localparam int CLK_FREQ_HZ = 100_000_000;
    localparam int BAUD_RATE   = 115_200;
    localparam int CLKS_PER_BIT = (CLK_FREQ_HZ + BAUD_RATE/2)/BAUD_RATE;
    localparam time CLK_PERIOD = 10ns;
    localparam time BIT_PERIOD = CLKS_PER_BIT * CLK_PERIOD;

    logic clk=0,rst=1,start=0;
    logic [7:0] data=0;
    logic tx,ready;
    integer errores=0;

    always #(CLK_PERIOD/2) clk=~clk;

    uart_tx dut(
        .clk_i(clk),.rst_i(rst),.start_i(start),.data_i(data),
        .tx_o(tx),.ready_o(ready)
    );

    task automatic verificar(input logic condicion,input string mensaje);
        if(condicion!==1'b1)begin errores++;$error("%s",mensaje);end
    endtask

    task automatic verificar_byte(input logic [7:0] valor);
        integer indice;
        wait(ready);
        @(negedge clk);data=valor;start=1;
        @(posedge clk);#1;
        verificar(!ready,"ready no baja al iniciar");
        fork
            begin @(negedge clk);start=0;end
        join_none

        #(BIT_PERIOD/2-1ns);
        verificar(tx===1'b0,"bit de inicio incorrecto");
        for(indice=0;indice<8;indice++)begin
            #BIT_PERIOD;
            verificar(tx===valor[indice],$sformatf("dato bit %0d incorrecto",indice));
            verificar(!ready,"ready se activo durante los datos");
        end
        #BIT_PERIOD;
        verificar(tx===1'b1,"bit de parada incorrecto");
        #(BIT_PERIOD/2+2ns);
        wait(ready);
        verificar(tx===1'b1,"TX no vuelve a reposo");
    endtask

    initial begin
        repeat(3)@(posedge clk);#1;
        verificar(tx===1'b1 && ready===1'b1,"salidas durante reset");
        @(negedge clk);rst=0;
        @(posedge clk);#1;
        verificar(tx===1'b1 && ready===1'b1,"reposo despues de reset");

        verificar_byte(8'h55);
        verificar_byte(8'hA5);
        verificar_byte(8'h00);
        verificar_byte(8'hFF);

        if(errores==0)$display("uart_tx_tb: TODAS LAS PRUEBAS PASARON");
        else $fatal(1,"uart_tx_tb: %0d errores",errores);
        $finish;
    end

    initial begin #1ms;$fatal(1,"TIEMPO DE ESPERA AGOTADO uart_tx_tb");end
endmodule
