`timescale 1ns/1ps
module buzzer_peripheral_tb;
    logic clk=0,rst=1,write_enable=0;
    logic [1:0] addr=0;
    logic [31:0] wdata=0,rdata;
    logic buzzer;
    integer checks=0,errors=0;

    always #5 clk=~clk;

    buzzer_peripheral #(
        .HIT_HALF_PERIOD(2),.MISS_HALF_PERIOD(3),.SUNK_HALF_PERIOD(4),
        .INVALID_HALF_PERIOD(5),.VICTORY_HALF_PERIOD(6)
    ) dut(
        .clk_i(clk),.rst_i(rst),.write_enable_i(write_enable),.addr_i(addr),
        .wdata_i(wdata),.rdata_o(rdata),.buzzer_o(buzzer)
    );

    task automatic check(input logic condition,input string test_name);
        if(!condition)begin errors++;$error("%s",test_name);end else checks++;
    endtask

    task automatic write_command(input logic [2:0] command);
        @(negedge clk);addr=0;wdata={29'b0,command};write_enable=1;
        @(posedge clk);#1;
        @(negedge clk);write_enable=0;
    endtask

    task automatic check_sync_read(
        input logic [1:0] address,input logic [31:0] previous_value,
        input logic [31:0] expected_value,input string test_name
    );
        addr=address;#1;
        check(rdata===previous_value,{test_name," cambio antes del flanco"});
        @(posedge clk);#1;
        check(rdata===expected_value,{test_name," valor despues del flanco"});
    endtask

    task automatic check_tone(input logic [2:0] command,input integer expected_cycles);
        integer cycles;
        logic previous;
        write_command(command);
        check(buzzer==0,"tono no reinicia en cero");
        previous=buzzer;cycles=0;
        while(buzzer==previous && cycles<20)begin
            @(posedge clk);#1;cycles++;
            if(cycles==1)
                check(rdata=={29'b0,command},"lectura sincronica del comando");
        end
        check(cycles==expected_cycles,"primer semiperiodo incorrecto");
        previous=buzzer;cycles=0;
        while(buzzer==previous && cycles<20)begin
            @(posedge clk);#1;cycles++;
        end
        check(cycles==expected_cycles,"segundo semiperiodo incorrecto");
    endtask

    initial begin
        repeat(2)@(posedge clk);#1;
        check(rdata==0 && buzzer==0,"reset");
        @(negedge clk);rst=0;

        write_command(3'd0);
        repeat(3)@(posedge clk);#1;
        check(rdata==0 && buzzer==0,"comando apagado");

        write_command(3'd1);
        check(rdata==0,"rdata cambio en el flanco de escritura");
        check_sync_read(2'b00,32'h0,32'h1,"lectura comando hit");
        check_sync_read(2'b11,32'h1,32'h0,"direccion reservada");
        check_sync_read(2'b00,32'h0,32'h1,"regreso a comando buzzer");
        write_command(3'd0);
        check_sync_read(2'b00,32'h1,32'h0,"restablecer buzzer");

        check_tone(3'd1,2);
        check_tone(3'd2,3);
        check_tone(3'd3,4);
        check_tone(3'd4,5);
        check_tone(3'd5,6);

        write_command(3'd2);
        @(negedge clk);wdata=32'h00000005;write_enable=0;
        @(posedge clk);#1;
        check(rdata==32'h00000002,"write_enable cero modifico comando");

        while(buzzer==0)begin @(posedge clk);#1;end
        write_command(3'd0);
        check(buzzer==0,"comando cero no apaga inmediatamente");
        check_sync_read(2'b00,32'h00000002,32'h00000000,
                        "lectura despues de apagar buzzer");

        if(errors==0)$display("buzzer_peripheral_tb: ALL TESTS PASSED");
        else $fatal(1,"buzzer_peripheral_tb: %0d errores en %0d checks",errors,checks);
        $finish;
    end

    initial begin #10000;$fatal(1,"TIMEOUT buzzer_peripheral_tb");end
endmodule
