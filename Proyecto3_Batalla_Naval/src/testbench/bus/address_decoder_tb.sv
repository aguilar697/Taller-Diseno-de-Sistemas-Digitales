`timescale 1ns/1ps
module address_decoder_tb;
    logic [31:0] addr=0;
    logic ram_sel,uart_sel,input_sel,sevenseg_sel,led_sel,buzzer_sel,vga_sel;
    logic [9:0] ram_addr;
    logic [1:0] uart_addr,input_addr,sevenseg_addr,led_addr,buzzer_addr;
    logic [8:0] vga_addr;
    integer verificaciones=0,errores=0;

    address_decoder dut(
        .addr_i(addr),.ram_sel_o(ram_sel),.uart_sel_o(uart_sel),
        .input_sel_o(input_sel),.sevenseg_sel_o(sevenseg_sel),
        .led_sel_o(led_sel),.buzzer_sel_o(buzzer_sel),.vga_sel_o(vga_sel),
        .ram_addr_o(ram_addr),.uart_addr_o(uart_addr),.input_addr_o(input_addr),
        .sevenseg_addr_o(sevenseg_addr),.led_addr_o(led_addr),
        .buzzer_addr_o(buzzer_addr),.vga_addr_o(vga_addr)
    );

    task automatic verificar_decodificacion(
        input logic [31:0] direccion,
        input logic [6:0] selecciones_esperadas,
        input logic [9:0] direccion_ram_esperada,
        input logic [1:0] direccion_uart_esperada,
        input logic [8:0] direccion_vga_esperada,
        input string nombre_prueba
    );
        logic [6:0] selecciones;
        addr=direccion;#1;
        selecciones={vga_sel,buzzer_sel,led_sel,sevenseg_sel,input_sel,uart_sel,ram_sel};
        if(selecciones!==selecciones_esperadas)begin
            errores++;$error("%s: selecciones=%b esperadas=%b",nombre_prueba,selecciones,selecciones_esperadas);
        end else verificaciones++;
        if(ram_addr!==direccion_ram_esperada)begin
            errores++;$error("%s: ram_addr=%0d esperado=%0d",nombre_prueba,ram_addr,direccion_ram_esperada);
        end else verificaciones++;
        if(uart_addr!==direccion_uart_esperada)begin
            errores++;$error("%s: uart_addr=%b esperado=%b",nombre_prueba,uart_addr,direccion_uart_esperada);
        end else verificaciones++;
        if(vga_addr!==direccion_vga_esperada)begin
            errores++;$error("%s: vga_addr=%0d esperado=%0d",nombre_prueba,vga_addr,direccion_vga_esperada);
        end else verificaciones++;
        if(input_addr!==0 || sevenseg_addr!==0 || led_addr!==0 || buzzer_addr!==0)begin
            errores++;$error("%s: una direccion local fija no es cero",nombre_prueba);
        end else verificaciones++;
    endtask

    initial begin
        verificar_decodificacion(32'h00002000,7'b0000001,10'd0,2'b00,9'd0,"inicio RAM");
        verificar_decodificacion(32'h00002FFF,7'b0000001,10'd1023,2'b00,9'd0,"final RAM");
        verificar_decodificacion(32'h00003000,7'b0000000,10'd0,2'b00,9'd0,"fuera RAM");
        verificar_decodificacion(32'h00010040,7'b0000010,10'd0,2'b00,9'd0,"UART control");
        verificar_decodificacion(32'h00010044,7'b0000010,10'd0,2'b01,9'd0,"UART TX");
        verificar_decodificacion(32'h00010048,7'b0000010,10'd0,2'b10,9'd0,"UART RX");
        verificar_decodificacion(32'h0001004C,7'b0000000,10'd0,2'b00,9'd0,"UART invalida");
        verificar_decodificacion(32'h00010120,7'b0000100,10'd0,2'b00,9'd0,"entradas");
        verificar_decodificacion(32'h00010130,7'b0001000,10'd0,2'b00,9'd0,"sevenseg");
        verificar_decodificacion(32'h00010138,7'b0010000,10'd0,2'b00,9'd0,"LED");
        verificar_decodificacion(32'h00010140,7'b0100000,10'd0,2'b00,9'd0,"buzzer");
        verificar_decodificacion(32'h00011000,7'b1000000,10'd0,2'b00,9'd0,"inicio VGA");
        verificar_decodificacion(32'h000117FC,7'b1000000,10'd0,2'b00,9'd511,"final VGA");
        verificar_decodificacion(32'h00011800,7'b0000000,10'd0,2'b00,9'd0,"fuera VGA");
        verificar_decodificacion(32'h00000000,7'b0000000,10'd0,2'b00,9'd0,"direccion cero");
        verificar_decodificacion(32'hDEADBEEF,7'b0000000,10'd0,2'b00,9'd0,"no mapeada");

        if(errores==0)$display("address_decoder_tb: TODAS LAS PRUEBAS PASARON");
        else $fatal(1,"address_decoder_tb: %0d errores en %0d verificaciones",errores,verificaciones);
        $finish;
    end

    initial begin #1000;$fatal(1,"TIEMPO DE ESPERA AGOTADO address_decoder_tb");end
endmodule
