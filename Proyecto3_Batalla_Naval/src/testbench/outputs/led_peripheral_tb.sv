`timescale 1ns/1ps
module led_peripheral_tb;
    logic clk=0,rst=1,write_enable=0;
    logic [1:0] addr=0,led;
    logic [31:0] wdata=0,rdata;
    integer checks=0,errors=0;

    always #5 clk=~clk;

    led_peripheral dut(
        .clk_i(clk),.rst_i(rst),.write_enable_i(write_enable),.addr_i(addr),
        .wdata_i(wdata),.rdata_o(rdata),.led_o(led)
    );

    task automatic check_led(input logic [1:0] expected,input string test_name);
        if(led!==expected)begin
            errors++;$error("%s: led=%b expected=%b",test_name,led,expected);
        end else checks++;
    endtask

    task automatic write_state(input logic [1:0] value);
        @(negedge clk);addr=0;wdata={30'b0,value};write_enable=1;
        @(posedge clk);#1;
        @(negedge clk);write_enable=0;
    endtask

    task automatic check_sync_read(
        input logic [1:0] address,input logic [31:0] previous_value,
        input logic [31:0] expected_value,input string test_name
    );
        addr=address;#1;
        if(rdata!==previous_value)begin
            errors++;$error("%s cambio antes del flanco",test_name);
        end else checks++;
        @(posedge clk);#1;
        if(rdata!==expected_value)begin
            errors++;$error("%s valor despues del flanco",test_name);
        end else checks++;
    endtask

    initial begin
        repeat(2)@(posedge clk);#1;
        check_led(2'b00,"reset LED");
        if(rdata!==0)begin errors++;$error("reset rdata");end else checks++;
        @(negedge clk);rst=0;

        write_state(2'b00);check_led(2'b00,"colocacion");
        check_sync_read(2'b00,32'h0,32'h0,"lectura colocacion");
        write_state(2'b01);check_led(2'b01,"batalla");
        check_sync_read(2'b00,32'h0,32'h1,"lectura batalla");

        check_sync_read(2'b11,32'h1,32'h0,"direccion reservada");
        check_sync_read(2'b00,32'h0,32'h1,"regreso a estado LED");

        write_state(2'b10);check_led(2'b10,"resultado");
        check_sync_read(2'b00,32'h1,32'h2,"lectura resultado");
        write_state(2'b11);check_led(2'b11,"reservado");
        check_sync_read(2'b00,32'h2,32'h3,"lectura codigo reservado");

        @(negedge clk);wdata=32'h00000001;write_enable=0;
        @(posedge clk);#1;check_led(2'b11,"write_enable cero");
        if(rdata!==32'h3)begin errors++;$error("write_enable cero modifico lectura");end else checks++;

        if(errors==0)$display("led_peripheral_tb: ALL TESTS PASSED");
        else $fatal(1,"led_peripheral_tb: %0d errores en %0d checks",errors,checks);
        $finish;
    end

    initial begin #1000;$fatal(1,"TIMEOUT led_peripheral_tb");end
endmodule
