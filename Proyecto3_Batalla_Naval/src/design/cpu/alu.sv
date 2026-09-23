// ALU combinacional de 32 bits. No mantiene banderas ni estado entre operaciones.
module alu (
    input logic [31:0] a_i, b_i,
    input logic [3:0] op_i,
    output logic [31:0] result_o
);
    import cpu_pkg::*;
    logic subtract;
    logic [31:0] sum;
    assign subtract = (op_i == ALU_SUB);
    assign sum = a_i + (b_i ^ {32{subtract}}) + {31'b0, subtract};
    always_comb begin
        result_o = 32'b0;
        case (op_i)
            ALU_ADD, ALU_SUB: result_o = sum;
            ALU_AND: result_o = a_i & b_i;
            ALU_OR:  result_o = a_i | b_i;
            ALU_XOR: result_o = a_i ^ b_i;
            ALU_SLL: result_o = a_i << b_i[4:0];
            ALU_SRL: result_o = a_i >> b_i[4:0];
            // El cast con signo permite replicar el bit 31 en el desplazamiento.
            ALU_SRA: result_o = $signed(a_i) >>> b_i[4:0];
            ALU_SLT: result_o = {31'b0, ($signed(a_i) < $signed(b_i))};
            ALU_SLTU: result_o = {31'b0, (a_i < b_i)};
            default: result_o = 32'b0;
        endcase
    end
endmodule
