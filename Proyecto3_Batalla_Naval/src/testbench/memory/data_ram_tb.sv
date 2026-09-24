`timescale 1ns/1ps
module data_ram_tb;
    logic clk=0,write_enable=0;
    logic [9:0] addr=0;
    logic [31:0] wdata=0,rdata;
    integer checks=0,errors=0;

    always #5 clk=~clk;

    data_ram dut(
        .clk_i(clk),
        .write_enable_i(write_enable),
        .addr_i(addr),
        .wdata_i(wdata),
        .rdata_o(rdata)
    );

    task automatic check_value(input logic [31:0] expected,input string test_name);
        if(rdata!==expected)begin
            errors++;
            $error("%s: addr=%0d got=%h expected=%h",test_name,addr,rdata,expected);
        end else checks++;
    endtask

    task automatic write_word(input logic [9:0] address,input logic [31:0] value);
        @(negedge clk);addr=address;wdata=value;write_enable=1;
        @(posedge clk);#1;
        @(negedge clk);write_enable=0;
    endtask

    task automatic read_word(input logic [9:0] address,input logic [31:0] expected,input string test_name);
        logic [31:0] previous;
        @(negedge clk);previous=rdata;addr=address;write_enable=0;#1;
        if(rdata!==previous)begin
            errors++;
            $error("%s: rdata cambio antes del flanco de reloj",test_name);
        end else checks++;
        @(posedge clk);#1;check_value(expected,test_name);
    endtask

    initial begin
        // Una palabra y varias direcciones internas.
        write_word(10'd10,32'h12345678);
        read_word(10'd10,32'h12345678,"lectura de una palabra");

        write_word(10'd25,32'h11112222);
        write_word(10'd511,32'h33334444);
        write_word(10'd700,32'h55556666);
        read_word(10'd25,32'h11112222,"direccion 25");
        read_word(10'd511,32'h33334444,"direccion 511");
        read_word(10'd700,32'h55556666,"direccion 700");

        // Direcciones minima y maxima.
        write_word(10'd0,32'hA5A50000);
        write_word(10'd1023,32'h5A5AFFFF);
        read_word(10'd0,32'hA5A50000,"direccion minima");
        read_word(10'd1023,32'h5A5AFFFF,"direccion maxima");

        // Una escritura no debe modificar otra direccion.
        write_word(10'd100,32'hAAAA0001);
        write_word(10'd101,32'hBBBB0002);
        write_word(10'd100,32'hCCCC0003);
        read_word(10'd101,32'hBBBB0002,"direccion independiente");
        read_word(10'd100,32'hCCCC0003,"direccion actualizada");

        // write_enable=0 no debe modificar el contenido.
        write_word(10'd300,32'h0BADCAFE);
        @(negedge clk);addr=10'd300;wdata=32'hDEADBEEF;write_enable=0;
        @(posedge clk);#1;check_value(32'h0BADCAFE,"escritura deshabilitada");
        read_word(10'd300,32'h0BADCAFE,"contenido conservado");

        // La salida cambia solamente despues del flanco de lectura.
        write_word(10'd400,32'h40004000);
        write_word(10'd401,32'h40104010);
        read_word(10'd400,32'h40004000,"latencia origen");
        @(negedge clk);addr=10'd401;write_enable=0;#1;
        check_value(32'h40004000,"latencia antes del flanco");
        @(posedge clk);#1;
        check_value(32'h40104010,"latencia despues del flanco");

        if(errors==0)$display("data_ram_tb: ALL TESTS PASSED (%0d checks)",checks);
        else $fatal(1,"data_ram_tb: %0d errores en %0d checks",errors,checks);
        $finish;
    end

    initial begin #5000;$fatal(1,"TIMEOUT data_ram_tb");end
endmodule
