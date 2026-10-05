`timescale 1ns/1ps
module data_ram_tb;
    logic clk=0,write_enable=0;
    logic [9:0] addr=0;
    logic [31:0] wdata=0,rdata;
    integer verificaciones=0,errores=0;

    always #5 clk=~clk;

    data_ram dut(
        .clk_i(clk),
        .write_enable_i(write_enable),
        .addr_i(addr),
        .wdata_i(wdata),
        .rdata_o(rdata)
    );

    task automatic verificar_valor(input logic [31:0] esperado,input string nombre_prueba);
        if(rdata!==esperado)begin
            errores++;
            $error("%s: addr=%0d obtenido=%h esperado=%h",nombre_prueba,addr,rdata,esperado);
        end else verificaciones++;
    endtask

    task automatic escribir_palabra(input logic [9:0] direccion,input logic [31:0] valor);
        @(negedge clk);addr=direccion;wdata=valor;write_enable=1;
        @(posedge clk);#1;
        @(negedge clk);write_enable=0;
    endtask

    task automatic leer_palabra(input logic [9:0] direccion,input logic [31:0] esperado,input string nombre_prueba);
        logic [31:0] anterior;
        @(negedge clk);anterior=rdata;addr=direccion;write_enable=0;#1;
        if(rdata!==anterior)begin
            errores++;
            $error("%s: rdata cambio antes del flanco de reloj",nombre_prueba);
        end else verificaciones++;
        @(posedge clk);#1;verificar_valor(esperado,nombre_prueba);
    endtask

    initial begin
        // Una palabra y varias direcciones internas.
        escribir_palabra(10'd10,32'h12345678);
        leer_palabra(10'd10,32'h12345678,"lectura de una palabra");

        escribir_palabra(10'd25,32'h11112222);
        escribir_palabra(10'd511,32'h33334444);
        escribir_palabra(10'd700,32'h55556666);
        leer_palabra(10'd25,32'h11112222,"direccion 25");
        leer_palabra(10'd511,32'h33334444,"direccion 511");
        leer_palabra(10'd700,32'h55556666,"direccion 700");

        // Direcciones minima y maxima.
        escribir_palabra(10'd0,32'hA5A50000);
        escribir_palabra(10'd1023,32'h5A5AFFFF);
        leer_palabra(10'd0,32'hA5A50000,"direccion minima");
        leer_palabra(10'd1023,32'h5A5AFFFF,"direccion maxima");

        // Una escritura no debe modificar otra direccion.
        escribir_palabra(10'd100,32'hAAAA0001);
        escribir_palabra(10'd101,32'hBBBB0002);
        escribir_palabra(10'd100,32'hCCCC0003);
        leer_palabra(10'd101,32'hBBBB0002,"direccion independiente");
        leer_palabra(10'd100,32'hCCCC0003,"direccion actualizada");

        // write_enable=0 no debe modificar el contenido.
        escribir_palabra(10'd300,32'h0BADCAFE);
        @(negedge clk);addr=10'd300;wdata=32'hDEADBEEF;write_enable=0;
        @(posedge clk);#1;verificar_valor(32'h0BADCAFE,"escritura deshabilitada");
        leer_palabra(10'd300,32'h0BADCAFE,"contenido conservado");

        // La salida cambia solamente despues del flanco de lectura.
        escribir_palabra(10'd400,32'h40004000);
        escribir_palabra(10'd401,32'h40104010);
        leer_palabra(10'd400,32'h40004000,"latencia origen");
        @(negedge clk);addr=10'd401;write_enable=0;#1;
        verificar_valor(32'h40004000,"latencia antes del flanco");
        @(posedge clk);#1;
        verificar_valor(32'h40104010,"latencia despues del flanco");

        if(errores==0)$display("data_ram_tb: TODAS LAS PRUEBAS PASARON (%0d verificaciones)",verificaciones);
        else $fatal(1,"data_ram_tb: %0d errores en %0d verificaciones",errores,verificaciones);
        $finish;
    end

    initial begin #5000;$fatal(1,"TIEMPO DE ESPERA AGOTADO data_ram_tb");end
endmodule
