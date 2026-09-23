`timescale 1ns/1ps
module alu_tb;
    logic [31:0] a,b,y,expected;
    logic [3:0] op;
    integer checks=0,seed=32'h251103;
    alu dut(.a_i(a),.b_i(b),.op_i(op),.result_o(y));
    task automatic verify(input logic[31:0] x,z, input integer code);
        a=x; b=z; op=code;
        case(code)
            0:expected=x+z; 1:expected=x-z; 2:expected=x&z;
            3:expected=x|z; 4:expected=x^z; 5:expected=x<<(z%32);
            6:expected=x>>(z%32); 7:expected=$signed(x)>>>(z%32);
            8:expected=($signed(x)<$signed(z)); 9:expected=(x<z);
            default:expected=0;
        endcase
        #1;
        if(y!==expected) $fatal(1,"ALU op=%0d a=%h b=%h got=%h expected=%h",code,x,z,y,expected);
        checks++;
    endtask
    initial begin
        for(integer code=0;code<16;code++) begin
            verify(0,0,code); verify(32'hffffffff,1,code);
            verify(32'h80000000,31,code); verify(32'h7fffffff,32'hffffffff,code);
            verify(32'h80000000,32'h7fffffff,code); verify(32'h12345678,32,code);
            for(integer n=0;n<200;n++) verify($random(seed),$random(seed),code);
        end
        $display("PASS alu_tb: %0d comprobaciones",checks); $finish;
    end
    initial begin #100000; $fatal(1,"TIMEOUT alu_tb"); end
endmodule
