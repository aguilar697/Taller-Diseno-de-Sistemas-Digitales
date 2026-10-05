`timescale 1ns/1ps
module led_peripheral_tb;
    logic clk=0,rst=1,write_enable=0;
    logic [1:0] addr=0,led;
    logic [31:0] wdata=0,rdata;
    integer verificaciones=0,errores=0;

    always #5 clk=~clk;

    led_peripheral dut(
        .clk_i(clk),.rst_i(rst),.write_enable_i(write_enable),.addr_i(addr),
        .wdata_i(wdata),.rdata_o(rdata),.led_o(led)
    );

    task automatic verificar_led(input logic [1:0] esperado,input string nombre_prueba);
        if(led!==esperado)begin
            errores++;$error("%s: led=%b esperado=%b",nombre_prueba,led,esperado);
        end else verificaciones++;
    endtask

    task automatic escribir_estado(input logic [1:0] valor);
        @(negedge clk);addr=0;wdata={30'b0,valor};write_enable=1;
        @(posedge clk);#1;
        @(negedge clk);write_enable=0;
    endtask

    task automatic verificar_lectura_sincrona(
        input logic [1:0] direccion,input logic [31:0] valor_anterior,
        input logic [31:0] valor_esperado,input string nombre_prueba
    );
        addr=direccion;#1;
        if(rdata!==valor_anterior)begin
            errores++;$error("%s cambio antes del flanco",nombre_prueba);
        end else verificaciones++;
        @(posedge clk);#1;
        if(rdata!==valor_esperado)begin
            errores++;$error("%s valor despues del flanco",nombre_prueba);
        end else verificaciones++;
    endtask

    initial begin
        repeat(2)@(posedge clk);#1;
        verificar_led(2'b00,"reset LED");
        if(rdata!==0)begin errores++;$error("reset rdata");end else verificaciones++;
        @(negedge clk);rst=0;

        escribir_estado(2'b00);verificar_led(2'b00,"colocacion");
        verificar_lectura_sincrona(2'b00,32'h0,32'h0,"lectura colocacion");
        escribir_estado(2'b01);verificar_led(2'b01,"batalla");
        verificar_lectura_sincrona(2'b00,32'h0,32'h1,"lectura batalla");

        verificar_lectura_sincrona(2'b11,32'h1,32'h0,"direccion reservada");
        verificar_lectura_sincrona(2'b00,32'h0,32'h1,"regreso a estado LED");

        escribir_estado(2'b10);verificar_led(2'b10,"resultado");
        verificar_lectura_sincrona(2'b00,32'h1,32'h2,"lectura resultado");
        escribir_estado(2'b11);verificar_led(2'b11,"reservado");
        verificar_lectura_sincrona(2'b00,32'h2,32'h3,"lectura codigo reservado");

        @(negedge clk);wdata=32'h00000001;write_enable=0;
        @(posedge clk);#1;verificar_led(2'b11,"write_enable cero");
        if(rdata!==32'h3)begin errores++;$error("write_enable cero modifico lectura");end else verificaciones++;

        if(errores==0)$display("led_peripheral_tb: TODAS LAS PRUEBAS PASARON");
        else $fatal(1,"led_peripheral_tb: %0d errores en %0d verificaciones",errores,verificaciones);
        $finish;
    end

    initial begin #1000;$fatal(1,"TIEMPO DE ESPERA AGOTADO led_peripheral_tb");end
endmodule
