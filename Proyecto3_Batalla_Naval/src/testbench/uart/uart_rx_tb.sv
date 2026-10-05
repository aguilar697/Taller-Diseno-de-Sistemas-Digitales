`timescale 1ns/1ps
module uart_rx_tb;
    localparam int CLK_FREQ_HZ = 100_000_000;
    localparam int BAUD_RATE   = 115_200;
    localparam int CLKS_PER_BIT = (CLK_FREQ_HZ + BAUD_RATE/2)/BAUD_RATE;
    localparam time CLK_PERIOD = 10ns;
    localparam time BIT_PERIOD = CLKS_PER_BIT * CLK_PERIOD;

    logic clk=0,rst=1,rx=1;
    logic [7:0] data;
    logic valid;
    integer errores=0,conteo_valid=0;

    always #(CLK_PERIOD/2) clk=~clk;

    uart_rx dut(
        .clk_i(clk),.rst_i(rst),.rx_i(rx),.data_o(data),.valid_o(valid)
    );

    always @(posedge clk) begin
        if(!rst && valid)conteo_valid++;
    end

    task automatic verificar(input logic condicion,input string mensaje);
        if(condicion!==1'b1)begin errores++;$error("%s",mensaje);end
    endtask

    task automatic enviar_byte(input logic [7:0] valor);
        integer indice;
        rx=0;#BIT_PERIOD;
        for(indice=0;indice<8;indice++)begin
            rx=valor[indice];#BIT_PERIOD;
        end
        rx=1;#BIT_PERIOD;
    endtask

    task automatic enviar_y_verificar(input logic [7:0] valor);
        integer conteo_anterior;
        conteo_anterior=conteo_valid;
        fork
            enviar_byte(valor);
            begin
                wait(valid);
                #1;
                verificar(data===valor,$sformatf("byte recibido incorrecto: %h",valor));
                @(posedge clk);#1;
                verificar(!valid,"valid debe durar un ciclo");
            end
        join
        verificar(conteo_valid==conteo_anterior+1,"cantidad de pulsos valid incorrecta");
        #BIT_PERIOD;
    endtask

    initial begin
        repeat(3)@(posedge clk);#1;
        verificar(data===8'h00 && valid===1'b0,"reset incorrecto");
        @(negedge clk);rst=0;
        #BIT_PERIOD;

        enviar_y_verificar(8'h55);
        enviar_y_verificar(8'hA5);
        enviar_y_verificar(8'h00);
        enviar_y_verificar(8'hFF);

        if(errores==0)$display("uart_rx_tb: TODAS LAS PRUEBAS PASARON");
        else $fatal(1,"uart_rx_tb: %0d errores",errores);
        $finish;
    end

    initial begin #1ms;$fatal(1,"TIEMPO DE ESPERA AGOTADO uart_rx_tb");end
endmodule
