// ALU combinacional de 32 bits: resultado depende de a, b y operación actuales.
// No tiene reloj ni conserva resultado; datapath lo captura en EXECUTE.
// No mantiene banderas carry/overflow: resultado aritmético limitado a 32 bits.
module alu (
    input logic [31:0] a_i, b_i,
    input logic [3:0] op_i,
    output logic [31:0] result_o
);
    import cpu_pkg::*;
    logic subtract;
    logic [31:0] sum;
    // SUMADOR COMPARTIDO: a-b = a+(~b)+1 en complemento a dos.
    // {32{subtract}} replica el control: 0 deja b intacto; 1 invierte sus bits.
    // El último término añade el 1 solo para SUB; ADD utiliza a+b.
    assign subtract = (op_i == ALU_SUB);
    assign sum = a_i + (b_i ^ {32{subtract}}) + {31'b0, subtract};
    always_comb begin
        // Valor por defecto y case asignan resultado en todos los caminos: sin latch.
        result_o = 32'b0;
        case (op_i)
            ALU_ADD, ALU_SUB: result_o = sum;
            // Lógica bit a bit, distinta de operadores lógicos && y ||.
            ALU_AND: result_o = a_i & b_i;
            ALU_OR:  result_o = a_i | b_i;
            ALU_XOR: result_o = a_i ^ b_i;
            // Cinco bits inferiores indican desplazamientos 0-31.
            // SLL/SRL rellenan con ceros; SRA conserva el signo de a.
            ALU_SLL: result_o = a_i << b_i[4:0];
            ALU_SRL: result_o = a_i >> b_i[4:0];
            // >>> replica bit 31 porque el operando se interpreta con signo.
            ALU_SRA: result_o = $signed(a_i) >>> b_i[4:0];
            // Comparaciones retornan palabra 0 o 1, no una resta ni banderas.
            // a=0xFFFFFFFF y b=1: SLT(-1,1)=1; SLTU(4294967295,1)=0.
            ALU_SLT: result_o = {31'b0, ($signed(a_i) < $signed(b_i))};
            ALU_SLTU: result_o = {31'b0, (a_i < b_i)};
            default: result_o = 32'b0;
        endcase
    end
endmodule
