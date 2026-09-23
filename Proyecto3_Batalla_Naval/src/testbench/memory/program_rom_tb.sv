`timescale 1ns/1ps
module program_rom_tb;
    logic clk=0;logic[31:0] addr=0,data;
    integer checks=0;
    always #5 clk=~clk;
    program_rom #(.INIT_FILE("program_rom_tb.hex")) dut(.clk_i(clk),.addr_i(addr),.rdata_o(data));
    task automatic read_word(input logic[31:0] address,expected);
        logic[31:0] previous;
        @(negedge clk);previous=data;addr=address;#1;
        if(data!==previous)$fatal(1,"ROM no respeta salida registrada");
        @(posedge clk);#1;if(data!==expected)$fatal(1,"ROM addr=%h got=%h expected=%h",address,data,expected);
        checks++;
    endtask
    initial begin
        @(posedge clk);#1;
        read_word(0,32'h123450b7);read_word(4,32'hfff08093);
        read_word(8,32'h00000013);read_word(32'h1ffc,32'h0000006f);
        read_word(32'h2000,32'h00000013);read_word(32'h10000,32'h00000013);
        read_word(2,32'h00000013);read_word(32'hfffffffc,32'h00000013);
        read_word(0,32'h123450b7);
        $display("PASS program_rom_tb: %0d comprobaciones",checks);$finish;
    end
    initial begin #1000;$fatal(1,"TIMEOUT program_rom_tb");end
endmodule
