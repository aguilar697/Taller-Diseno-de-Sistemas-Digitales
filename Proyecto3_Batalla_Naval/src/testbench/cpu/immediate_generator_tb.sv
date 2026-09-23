`timescale 1ns/1ps
module immediate_generator_tb;
    import cpu_tb_pkg::*;
    logic [31:0] instruction,imm;
    logic [2:0] format;
    integer checks=0, seed=51,v;
    immediate_generator dut(.instruction_i(instruction),.format_i(format),.immediate_o(imm));
    task automatic verify(input integer typ,value);
        format=typ;
        case(typ)
            0:instruction=enc_i(value,3,0,4);
            1:instruction=enc_s(value,4,3);
            2:instruction=enc_b(value,4,3,0);
            3:instruction=enc_u(value>>>12,4);
            4:instruction=enc_j(value,4);
            default:instruction=32'hffffffff;
        endcase
        #1;
        if(imm !== ((typ<5)?value:32'b0)) $fatal(1,"Inmediato tipo=%0d valor=%h obtenido=%h",typ,value,imm);
        checks++;
    endtask
    initial begin
        for(integer n=-2048;n<=2047;n++) begin verify(0,n); verify(1,n); end
        for(integer n=-4096;n<=4094;n+=2) verify(2,n);
        verify(4,-1048576); verify(4,1048574); verify(4,-2); verify(4,0);
        verify(3,32'h80000000); verify(3,32'hfffff000); verify(3,0);
        for(integer n=0;n<1000;n++) begin
            v=$random(seed); verify(3,(v>>>12)<<12); verify(4,(v>>>12)<<1);
        end
        verify(5,0); verify(6,0); verify(7,0);
        $display("PASS immediate_generator_tb: %0d comprobaciones",checks); $finish;
    end
    initial begin #100000; $fatal(1,"TIMEOUT immediate_generator_tb"); end
endmodule
