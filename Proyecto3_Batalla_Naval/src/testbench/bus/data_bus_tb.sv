`timescale 1ns/1ps
module data_bus_tb;
    logic clk=0,rst=1,cpu_we=0;
    logic [31:0] cpu_addr=0,cpu_wdata=0,cpu_rdata;
    logic [31:0] ram_rdata=32'hAAAA0001,uart_rdata=32'hBBBB0002;
    logic [31:0] input_rdata=32'hCCCC0003,sevenseg_rdata=32'hDDDD0004;
    logic [31:0] led_rdata=32'hEEEE0005,buzzer_rdata=32'hFFFF0006;
    logic [31:0] vga_rdata=32'h12340007,peripheral_wdata;
    logic [9:0] ram_addr;
    logic [1:0] uart_addr,input_addr,sevenseg_addr,led_addr,buzzer_addr;
    logic [8:0] vga_addr;
    logic ram_we,uart_we,input_we,sevenseg_we,led_we,buzzer_we,vga_we;
    integer verificaciones=0,errores=0;

    always #5 clk=~clk;

    data_bus dut(
        .clk_i(clk),.rst_i(rst),.cpu_addr_i(cpu_addr),.cpu_wdata_i(cpu_wdata),
        .cpu_we_i(cpu_we),.cpu_rdata_o(cpu_rdata),.ram_rdata_i(ram_rdata),
        .uart_rdata_i(uart_rdata),.input_rdata_i(input_rdata),
        .sevenseg_rdata_i(sevenseg_rdata),.led_rdata_i(led_rdata),
        .buzzer_rdata_i(buzzer_rdata),.vga_rdata_i(vga_rdata),
        .peripheral_wdata_o(peripheral_wdata),.ram_addr_o(ram_addr),
        .uart_addr_o(uart_addr),.input_addr_o(input_addr),
        .sevenseg_addr_o(sevenseg_addr),.led_addr_o(led_addr),
        .buzzer_addr_o(buzzer_addr),.vga_addr_o(vga_addr),
        .ram_write_enable_o(ram_we),.uart_write_enable_o(uart_we),
        .input_write_enable_o(input_we),.sevenseg_write_enable_o(sevenseg_we),
        .led_write_enable_o(led_we),.buzzer_write_enable_o(buzzer_we),
        .vga_write_enable_o(vga_we)
    );

    task automatic verificar_habilitaciones(input logic [6:0] esperado,input string nombre_prueba);
        logic [6:0] actual;
        actual={vga_we,buzzer_we,led_we,sevenseg_we,input_we,uart_we,ram_we};
        if(actual!==esperado)begin
            errores++;$error("%s: habilitaciones=%b esperadas=%b",nombre_prueba,actual,esperado);
        end else verificaciones++;
        if(peripheral_wdata!==cpu_wdata)begin
            errores++;$error("%s: peripheral_wdata=%h esperado=%h",nombre_prueba,peripheral_wdata,cpu_wdata);
        end else verificaciones++;
    endtask

    task automatic verificar_escritura(input logic [31:0] direccion,input logic [6:0] esperado,input string nombre_prueba);
        @(negedge clk);cpu_addr=direccion;cpu_wdata=32'h89ABCDEF;cpu_we=1;#1;
        verificar_habilitaciones(esperado,nombre_prueba);
    endtask

    task automatic iniciar_lectura(input logic [31:0] direccion,input logic [31:0] valor_anterior,input string nombre_prueba);
        @(negedge clk);cpu_addr=direccion;cpu_we=0;#1;
        if(cpu_rdata!==valor_anterior)begin
            errores++;$error("%s antes del flanco: obtenido=%h esperado=%h",nombre_prueba,cpu_rdata,valor_anterior);
        end else verificaciones++;
    endtask

    task automatic finalizar_lectura(input logic [31:0] esperado,input string nombre_prueba);
        @(posedge clk);#1;
        if(cpu_rdata!==esperado)begin
            errores++;$error("%s despues del flanco: obtenido=%h esperado=%h",nombre_prueba,cpu_rdata,esperado);
        end else verificaciones++;
    endtask

    initial begin
        @(posedge clk);#1;
        if(cpu_rdata!==0)begin errores++;$error("reset no limpia seleccion de lectura");end
        else verificaciones++;
        @(negedge clk);rst=0;

        verificar_escritura(32'h00002014,7'b0000001,"escritura RAM");
        if(ram_addr!==10'd5)begin errores++;$error("direccion local RAM");end else verificaciones++;
        verificar_escritura(32'h00010044,7'b0000010,"escritura UART");
        if(uart_addr!==2'b01)begin errores++;$error("direccion local UART");end else verificaciones++;
        verificar_escritura(32'h00010120,7'b0000100,"escritura entradas");
        if(input_addr!==0)begin errores++;$error("direccion local entradas");end else verificaciones++;
        verificar_escritura(32'h00010130,7'b0001000,"escritura sevenseg");
        if(sevenseg_addr!==0)begin errores++;$error("direccion local sevenseg");end else verificaciones++;
        verificar_escritura(32'h00010138,7'b0010000,"escritura LED");
        if(led_addr!==0)begin errores++;$error("direccion local LED");end else verificaciones++;
        verificar_escritura(32'h00010140,7'b0100000,"escritura buzzer");
        if(buzzer_addr!==0)begin errores++;$error("direccion local buzzer");end else verificaciones++;
        verificar_escritura(32'h000117FC,7'b1000000,"escritura VGA");
        if(vga_addr!==9'd511)begin errores++;$error("direccion local VGA");end else verificaciones++;

        @(negedge clk);rst=1;cpu_addr=32'h00002000;cpu_we=1;#1;
        verificar_habilitaciones(7'b0000000,"habilitaciones de escritura durante reset");
        @(posedge clk);#1;
        @(negedge clk);rst=0;cpu_we=0;cpu_addr=0;

        // Cada salida aparece despues del flanco que registra el destino.
        iniciar_lectura(32'h00002000,32'h00000000,"lectura RAM");
        finalizar_lectura(32'hAAAA0001,"lectura RAM");
        iniciar_lectura(32'h00010040,32'hAAAA0001,"lectura UART");
        finalizar_lectura(32'hBBBB0002,"lectura UART");
        iniciar_lectura(32'h00010120,32'hBBBB0002,"lectura entradas");
        finalizar_lectura(32'hCCCC0003,"lectura entradas");
        iniciar_lectura(32'h00010130,32'hCCCC0003,"lectura sevenseg");
        finalizar_lectura(32'hDDDD0004,"lectura sevenseg");
        iniciar_lectura(32'h00010138,32'hDDDD0004,"lectura LED");
        finalizar_lectura(32'hEEEE0005,"lectura LED");
        iniciar_lectura(32'h00010140,32'hEEEE0005,"lectura buzzer");
        finalizar_lectura(32'hFFFF0006,"lectura buzzer");
        iniciar_lectura(32'h00011000,32'hFFFF0006,"lectura VGA");
        finalizar_lectura(32'h12340007,"lectura VGA");
        iniciar_lectura(32'hDEADBEEF,32'h12340007,"lectura no mapeada");
        finalizar_lectura(32'h00000000,"lectura no mapeada");

        if(errores==0)$display("data_bus_tb: TODAS LAS PRUEBAS PASARON");
        else $fatal(1,"data_bus_tb: %0d errores en %0d verificaciones",errores,verificaciones);
        $finish;
    end

    initial begin #5000;$fatal(1,"TIEMPO DE ESPERA AGOTADO data_bus_tb");end
endmodule
