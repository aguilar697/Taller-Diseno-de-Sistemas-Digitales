`timescale 1ns/1ps
module uart_peripheral_tb;
    localparam int CLK_FREQ_HZ = 100_000_000;
    localparam int BAUD_RATE   = 115_200;
    localparam int CLKS_PER_BIT = (CLK_FREQ_HZ + BAUD_RATE/2)/BAUD_RATE;
    localparam time CLK_PERIOD = 10ns;
    localparam time BIT_PERIOD = CLKS_PER_BIT * CLK_PERIOD;

    logic clk=0,rst=1,write_enable=0;
    logic [1:0] addr=0;
    logic [31:0] wdata=0,rdata;
    logic uart_rx=1,uart_tx;
    integer errores=0;

    always #(CLK_PERIOD/2) clk=~clk;

    uart_peripheral dut(
        .clk_i(clk),.rst_i(rst),.write_enable_i(write_enable),
        .addr_i(addr),.wdata_i(wdata),.rdata_o(rdata),
        .uart_rx_i(uart_rx),.uart_tx_o(uart_tx)
    );

    task automatic verificar(input logic condicion,input string mensaje);
        if(condicion!==1'b1)begin errores++;$error("%s",mensaje);end
    endtask

    task automatic escritura_mmio(input logic [1:0] direccion,input logic [31:0] valor);
        @(negedge clk);addr=direccion;wdata=valor;write_enable=1;
        @(posedge clk);#1;
        @(negedge clk);write_enable=0;
    endtask

    task automatic verificar_lectura_sincrona(
        input logic [1:0] direccion,input logic [31:0] valor_anterior,
        input logic [31:0] valor_esperado,input string nombre_prueba
    );
        addr=direccion;#1;
        verificar(rdata===valor_anterior,{nombre_prueba," cambio antes del flanco"});
        @(posedge clk);#1;
        verificar(rdata===valor_esperado,{nombre_prueba," valor despues del flanco"});
    endtask

    task automatic enviar_byte_rx(input logic [7:0] valor);
        integer indice;
        uart_rx=0;#BIT_PERIOD;
        for(indice=0;indice<8;indice++)begin
            uart_rx=valor[indice];#BIT_PERIOD;
        end
        uart_rx=1;#BIT_PERIOD;
    endtask

    task automatic verificar_byte_tx(input logic [7:0] valor);
        integer indice;
        wait(uart_tx==0);
        #(BIT_PERIOD/2);
        verificar(uart_tx===1'b0,"TX start incorrecto");
        for(indice=0;indice<8;indice++)begin
            #BIT_PERIOD;
            verificar(uart_tx===valor[indice],$sformatf("TX bit %0d incorrecto",indice));
        end
        #BIT_PERIOD;
        verificar(uart_tx===1'b1,"TX stop incorrecto");
    endtask

    initial begin
        repeat(3)@(posedge clk);#1;
        verificar(rdata===32'b0,"rdata durante reset");
        verificar(uart_tx===1'b1,"TX no esta en reposo durante reset");
        @(negedge clk);rst=0;
        verificar_lectura_sincrona(2'b00,32'h00000000,32'h00000001,
                        "CONTROL despues de reset");

        fork
            verificar_byte_tx(8'h55);
            begin
                escritura_mmio(2'b01,32'h00000055);
                verificar_lectura_sincrona(2'b00,32'h00000000,32'h00000000,
                                "CONTROL durante TX");
                wait(rdata[0]===1'b1);
            end
        join

        fork
            verificar_byte_tx(8'hA5);
            begin
                escritura_mmio(2'b01,32'h000000A5);
                verificar_lectura_sincrona(2'b00,32'h00000055,32'h00000000,
                                "CONTROL segunda TX");
                escritura_mmio(2'b01,32'h000000FF);
                addr=2'b00;
                wait(rdata[0]===1'b1);
                #BIT_PERIOD;
                verificar(uart_tx===1'b1,"escritura con TX ocupado inicio otra trama");
            end
        join

        enviar_byte_rx(8'h3C);
        addr=2'b00;
        wait(rdata[1]===1'b1);
        // Cambiar direccion fuera del flanco de lectura evita carreras del TB.
        @(negedge clk);
        verificar_lectura_sincrona(2'b10,32'h00000003,32'h0000003C,
                        "CONTROL a RX_DATA");
        verificar_lectura_sincrona(2'b00,32'h0000003C,32'h00000003,
                        "RX_DATA a CONTROL");

        escritura_mmio(2'b10,32'h00000099);
        verificar_lectura_sincrona(2'b10,32'h0000003C,32'h0000003C,
                        "escritura ignorada en RX_DATA");

        verificar_lectura_sincrona(2'b00,32'h0000003C,32'h00000003,
                        "lectura RX_DATA no limpia rx_valid");
        escritura_mmio(2'b00,32'h00000002);
        verificar_lectura_sincrona(2'b00,32'h00000003,32'h00000001,
                        "W1C limpia rx_valid");

        escritura_mmio(2'b11,32'hFFFFFFFF);
        verificar(rdata===32'h00000000,"direccion reservada no devuelve cero");
        verificar_lectura_sincrona(2'b00,32'h00000000,32'h00000001,
                        "escritura reservada no modifica status");

        if(errores==0)$display("uart_peripheral_tb: TODAS LAS PRUEBAS PASARON");
        else $fatal(1,"uart_peripheral_tb: %0d errores",errores);
        $finish;
    end

    initial begin #2ms;$fatal(1,"TIEMPO DE ESPERA AGOTADO uart_peripheral_tb");end
endmodule
