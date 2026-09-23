// Codificadores del estimulo. No se usan en el hardware sintetizable.
package cpu_tb_pkg;
    function automatic logic [31:0] enc_r(input integer f7,rs2,rs1,f3,rd);
        enc_r={f7[6:0],rs2[4:0],rs1[4:0],f3[2:0],rd[4:0],7'h33};
    endfunction
    function automatic logic [31:0] enc_i(input integer imm,rs1,f3,rd,opcode= 'h13);
        enc_i={imm[11:0],rs1[4:0],f3[2:0],rd[4:0],opcode[6:0]};
    endfunction
    function automatic logic [31:0] enc_s(input integer imm,rs2,rs1);
        enc_s={imm[11:5],rs2[4:0],rs1[4:0],3'b010,imm[4:0],7'h23};
    endfunction
    function automatic logic [31:0] enc_b(input integer imm,rs2,rs1,f3);
        enc_b={imm[12],imm[10:5],rs2[4:0],rs1[4:0],f3[2:0],imm[4:1],imm[11],7'h63};
    endfunction
    function automatic logic [31:0] enc_u(input integer upper,rd,opcode='h37);
        enc_u={upper[19:0],rd[4:0],opcode[6:0]};
    endfunction
    function automatic logic [31:0] enc_j(input integer imm,rd);
        enc_j={imm[20],imm[10:1],imm[11],imm[19:12],rd[4:0],7'h6f};
    endfunction
endpackage
