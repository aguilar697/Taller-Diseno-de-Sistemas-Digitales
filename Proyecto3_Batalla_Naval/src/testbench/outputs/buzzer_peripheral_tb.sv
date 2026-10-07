`timescale 1ns/1ps
module buzzer_peripheral_tb;
    logic clk=0,rst=1,write_enable=0;
    logic [1:0] addr=0;
    logic [31:0] wdata=0,rdata;
    logic buzzer;
    logic [31:0] rdata_dur;
    logic buzzer_dur;
    integer verificaciones=0,errores=0;

    always #5 clk=~clk;

    buzzer_peripheral #(
        .HIT_HALF_PERIOD(2),.MISS_HALF_PERIOD(3),.SUNK_HALF_PERIOD(4),
        .INVALID_HALF_PERIOD(5),.VICTORY_HALF_PERIOD(6)
    ) dut(
        .clk_i(clk),.rst_i(rst),.write_enable_i(write_enable),.addr_i(addr),
        .wdata_i(wdata),.rdata_o(rdata),.buzzer_o(buzzer)
    );

    // Segunda instancia con duraciones cortas para probar que cada sonido
    // vuelve solo a apagado. Recibe las mismas escrituras que dut.
    buzzer_peripheral #(
        .HIT_HALF_PERIOD(2),.MISS_HALF_PERIOD(3),.SUNK_HALF_PERIOD(4),
        .INVALID_HALF_PERIOD(5),.VICTORY_HALF_PERIOD(6),
        .HIT_DURATION(10),.MISS_DURATION(12),.SUNK_DURATION(14),
        .INVALID_DURATION(16),.VICTORY_DURATION(18)
    ) dut_dur(
        .clk_i(clk),.rst_i(rst),.write_enable_i(write_enable),.addr_i(addr),
        .wdata_i(wdata),.rdata_o(rdata_dur),.buzzer_o(buzzer_dur)
    );

    task automatic verificar(input logic condicion,input string nombre_prueba);
        if(condicion!==1'b1)begin errores++;$error("%s",nombre_prueba);end else verificaciones++;
    endtask

    task automatic escribir_comando(input logic [2:0] comando);
        @(negedge clk);addr=0;wdata={29'b0,comando};write_enable=1;
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

    task automatic verificar_tono(input logic [2:0] comando,input integer ciclos_esperados);
        integer ciclos;
        logic anterior;
        escribir_comando(comando);
        verificar(buzzer==0,"tono no reinicia en cero");
        anterior=buzzer;ciclos=0;
        while(buzzer==anterior && ciclos<20)begin
            @(posedge clk);#1;ciclos++;
            if(ciclos==1)
                verificar(rdata=={29'b0,comando},"lectura sincronica del comando");
        end
        verificar(ciclos==ciclos_esperados,"primer semiperiodo incorrecto");
        anterior=buzzer;ciclos=0;
        while(buzzer==anterior && ciclos<20)begin
            @(posedge clk);#1;ciclos++;
        end
        verificar(ciclos==ciclos_esperados,"segundo semiperiodo incorrecto");
    endtask

    initial begin
        repeat(2)@(posedge clk);#1;
        verificar(rdata==0 && buzzer==0,"reset");
        @(negedge clk);rst=0;

        escribir_comando(3'd0);
        repeat(3)@(posedge clk);#1;
        verificar(rdata==0 && buzzer==0,"comando apagado");

        escribir_comando(3'd1);
        verificar(rdata==0,"rdata cambio en el flanco de escritura");
        verificar_lectura_sincrona(2'b00,32'h0,32'h1,"lectura comando impacto");
        verificar_lectura_sincrona(2'b11,32'h1,32'h0,"direccion reservada");
        verificar_lectura_sincrona(2'b00,32'h0,32'h1,"regreso a comando buzzer");
        escribir_comando(3'd0);
        verificar_lectura_sincrona(2'b00,32'h1,32'h0,"restablecer buzzer");

        verificar_tono(3'd1,2);
        verificar_tono(3'd2,3);
        verificar_tono(3'd3,4);
        verificar_tono(3'd4,5);
        verificar_tono(3'd5,6);

        escribir_comando(3'd2);
        @(negedge clk);wdata=32'h00000005;write_enable=0;
        @(posedge clk);#1;
        verificar(rdata==32'h00000002,"write_enable cero modifico comando");

        while(buzzer==0)begin @(posedge clk);#1;end
        escribir_comando(3'd0);
        verificar(buzzer==0,"comando cero no apaga inmediatamente");
        verificar_lectura_sincrona(2'b00,32'h00000002,32'h00000000,
                        "lectura despues de apagar buzzer");

        // --- Duracion de cada sonido (dut_dur) ---
        escribir_comando(3'd1);                 // HIT dura 10 ciclos
        repeat(4)@(posedge clk);#1;
        verificar(rdata_dur==32'h1,"el sonido sigue activo antes de su duracion");
        repeat(8)@(posedge clk);#1;
        verificar(rdata_dur==32'h0 && buzzer_dur==0,
                  "al cumplir la duracion el buzzer vuelve solo a apagado");

        escribir_comando(3'd2);                 // MISS dura 12 ciclos
        repeat(8)@(posedge clk);#1;
        escribir_comando(3'd2);                 // la misma orden otra vez
        repeat(8)@(posedge clk);#1;
        verificar(rdata_dur==32'h2,"una orden nueva reinicia la duracion");
        repeat(6)@(posedge clk);#1;
        verificar(rdata_dur==32'h0 && buzzer_dur==0,"la orden repetida tambien termina");

        escribir_comando(3'd5);                 // VICTORY dura 18 ciclos
        repeat(16)@(posedge clk);#1;
        verificar(rdata_dur==32'h5,"la victoria dura mas que el impacto");
        repeat(4)@(posedge clk);#1;
        verificar(rdata_dur==32'h0,"la victoria tambien termina sola");

        if(errores==0)$display("buzzer_peripheral_tb: TODAS LAS PRUEBAS PASARON");
        else $fatal(1,"buzzer_peripheral_tb: %0d errores en %0d verificaciones",errores,verificaciones);
        $finish;
    end

    initial begin #10000;$fatal(1,"TIEMPO DE ESPERA AGOTADO buzzer_peripheral_tb");end
endmodule
