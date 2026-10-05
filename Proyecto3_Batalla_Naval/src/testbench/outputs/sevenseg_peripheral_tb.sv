`timescale 1ns/1ps
module sevenseg_peripheral_tb;
    logic clk=0,rst=1,write_enable=0;
    logic [1:0] addr=0;
    logic [31:0] wdata=0,rdata;
    logic [6:0] seg;
    logic [3:0] an;
    integer verificaciones=0,errores=0;

    always #5 clk=~clk;

    sevenseg_peripheral #(.CLK_FREQ_HZ(40),.FRAME_REFRESH_HZ(10)) dut(
        .clk_i(clk),.rst_i(rst),.write_enable_i(write_enable),.addr_i(addr),
        .wdata_i(wdata),.rdata_o(rdata),.seg_o(seg),.an_o(an)
    );

    function automatic logic [6:0] segmentos_esperados(input logic [3:0] digito);
        case(digito)
            0:segmentos_esperados=7'b1000000;1:segmentos_esperados=7'b1111001;
            2:segmentos_esperados=7'b0100100;3:segmentos_esperados=7'b0110000;
            4:segmentos_esperados=7'b0011001;5:segmentos_esperados=7'b0010010;
            6:segmentos_esperados=7'b0000010;7:segmentos_esperados=7'b1111000;
            8:segmentos_esperados=7'b0000000;9:segmentos_esperados=7'b0010000;
            default:segmentos_esperados=7'b1111111;
        endcase
    endfunction

    task automatic verificar(input logic condicion,input string nombre_prueba);
        if(condicion!==1'b1)begin errores++;$error("%s",nombre_prueba);end else verificaciones++;
    endtask

    task automatic escribir_marcador(input logic [7:0] j1,input logic [7:0] j2);
        @(negedge clk);addr=0;wdata={16'b0,j2,j1};write_enable=1;
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

    task automatic verificar_barrido(
        input logic [3:0] decenas_j1,input logic [3:0] unidades_j1,
        input logic [3:0] decenas_j2,input logic [3:0] unidades_j2
    );
        logic [3:0] vistos;
        logic [3:0] digito_esperado;
        vistos=0;
        repeat(8)begin
            @(posedge clk);#1;
            case(an)
                4'b1110:begin vistos[0]=1;digito_esperado=unidades_j2;end
                4'b1101:begin vistos[1]=1;digito_esperado=decenas_j2;end
                4'b1011:begin vistos[2]=1;digito_esperado=unidades_j1;end
                4'b0111:begin vistos[3]=1;digito_esperado=decenas_j1;end
                default:begin digito_esperado=4'hF;errores++;$error("anodo invalido %b",an);end
            endcase
            verificar(seg===segmentos_esperados(digito_esperado),"patron de segmentos incorrecto");
        end
        verificar(vistos==4'b1111,"no se multiplexaron los cuatro digitos");
    endtask

    initial begin
        repeat(2)@(posedge clk);#1;
        verificar(rdata===32'h00000000,"reset no limpia marcador");
        @(negedge clk);rst=0;

        escribir_marcador(8'd12,8'd34);
        verificar_lectura_sincrona(2'b00,32'h00000000,32'h0000220C,"lectura MMIO 12 34");
        verificar_barrido(4'd1,4'd2,4'd3,4'd4);

        verificar_lectura_sincrona(2'b11,32'h0000220C,32'h00000000,"direccion reservada");
        verificar_lectura_sincrona(2'b00,32'h00000000,32'h0000220C,"regreso a marcador");

        @(negedge clk);wdata=32'h00005678;write_enable=0;
        @(posedge clk);#1;
        verificar(rdata===32'h0000220C,"write_enable cero modifico marcador");

        escribir_marcador(8'd5,8'd6);
        verificar_lectura_sincrona(2'b00,32'h0000220C,32'h00000605,"nueva escritura");

        escribir_marcador(8'd99,8'd99);
        verificar_lectura_sincrona(2'b00,32'h00000605,32'h00006363,"lectura MMIO 99 99");
        verificar_barrido(4'd9,4'd9,4'd9,4'd9);

        escribir_marcador(8'd100,8'd255);
        verificar_lectura_sincrona(2'b00,32'h00006363,32'h0000FF64,
                        "lectura conserva valores mayores que 99");
        verificar_barrido(4'd9,4'd9,4'd9,4'd9);

        if(errores==0)$display("sevenseg_peripheral_tb: TODAS LAS PRUEBAS PASARON");
        else $fatal(1,"sevenseg_peripheral_tb: %0d errores en %0d verificaciones",errores,verificaciones);
        $finish;
    end

    initial begin #5000;$fatal(1,"TIEMPO DE ESPERA AGOTADO sevenseg_peripheral_tb");end
endmodule
