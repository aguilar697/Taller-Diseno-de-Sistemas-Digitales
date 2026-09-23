`timescale 1ns/1ps
module register_file_tb;
    logic clk=0,rst=1,we=0;
    logic [4:0] rs1=0,rs2=0,rd=0;
    logic [31:0] wd=0,a,b;
    logic [31:0] expected[0:31];
    integer checks=0;
    always #5 clk=~clk;
    register_file dut(.clk_i(clk),.rst_i(rst),.write_enable_i(we),.rs1_i(rs1),.rs2_i(rs2),
        .rd_i(rd),.wdata_i(wd),.rs1_data_o(a),.rs2_data_o(b));
    task automatic reads;
        for(integer x=0;x<32;x++) begin
            rs1=x;rs2=31-x;#1;
            if(a!==expected[x] || b!==expected[31-x]) $fatal(1,"Banco: lectura incorrecta x%0d",x);
            checks+=2;
        end
    endtask
    task automatic write_reg(input integer regno,input logic[31:0] data,input logic enabled);
        @(negedge clk);rd=regno;wd=data;we=enabled;
        @(posedge clk);#1; if(enabled && regno!=0)expected[regno]=data;
        @(negedge clk);we=0;
    endtask
    initial begin
        for(integer x=0;x<32;x++) expected[x]=0;
        repeat(2)@(negedge clk);rst=0;reads();
        for(integer x=0;x<32;x++)write_reg(x,32'h80000000+x,1);
        reads();write_reg(5,32'hffffffff,0);reads();
        // La lectura del mismo destino cambia solo despues del flanco de escritura.
        @(negedge clk);rs1=5;rs2=5;rd=5;wd=123;we=1;#1;
        if(a!==expected[5])$fatal(1,"Escritura antes del flanco");
        @(posedge clk);#1;if(a!==123 || b!==123)$fatal(1,"Lectura del destino escrito");
        @(negedge clk);rst=1;rd=7;wd=99;we=1;
        @(negedge clk);rst=0;we=0;
        for(integer x=0;x<32;x++)expected[x]=0;
        reads();$display("PASS register_file_tb: %0d lecturas y prioridad de reset",checks);$finish;
    end
    initial begin #10000;$fatal(1,"TIMEOUT register_file_tb");end
endmodule
