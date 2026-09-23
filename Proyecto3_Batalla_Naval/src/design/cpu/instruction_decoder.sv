// Subconjunto RV32I del proyecto, mas LUI/AUIPC. No decodifica pseudoinstrucciones.
module instruction_decoder (
    input logic [31:0] instruction_i,
    output logic legal_o,
    output logic [2:0] kind_o, imm_format_o,
    output logic [3:0] alu_op_o,
    output logic [1:0] alu_a_sel_o, result_sel_o,
    output logic alu_b_sel_o
);
    import cpu_pkg::*;
    logic [6:0] opcode, funct7;
    logic [2:0] funct3;
    assign opcode = instruction_i[6:0];
    assign funct3 = instruction_i[14:12];
    assign funct7 = instruction_i[31:25];
    always_comb begin
        legal_o=0; kind_o=K_ALU; imm_format_o=IMM_I;
        alu_op_o=ALU_ADD; alu_a_sel_o=0; alu_b_sel_o=0; result_sel_o=0;
        case (opcode)
            7'h33: begin
                case (funct3)
                    3'b000: begin
                        legal_o=(funct7==7'h00 || funct7==7'h20);
                        alu_op_o=(funct7==7'h20) ? ALU_SUB : ALU_ADD;
                    end
                    3'b001: begin legal_o=(funct7==0); alu_op_o=ALU_SLL; end
                    3'b010: begin legal_o=(funct7==0); alu_op_o=ALU_SLT; end
                    3'b011: begin legal_o=(funct7==0); alu_op_o=ALU_SLTU; end
                    3'b100: begin legal_o=(funct7==0); alu_op_o=ALU_XOR; end
                    3'b101: begin
                        legal_o=(funct7==7'h00 || funct7==7'h20);
                        alu_op_o=(funct7==7'h20) ? ALU_SRA : ALU_SRL;
                    end
                    3'b110: begin legal_o=(funct7==0); alu_op_o=ALU_OR; end
                    3'b111: begin legal_o=(funct7==0); alu_op_o=ALU_AND; end
                endcase
            end
            7'h13: begin
                legal_o=1; alu_b_sel_o=1;
                case (funct3)
                    0: alu_op_o=ALU_ADD;
                    1: begin alu_op_o=ALU_SLL; legal_o=(funct7==0); end
                    2: alu_op_o=ALU_SLT;
                    3: alu_op_o=ALU_SLTU;
                    4: alu_op_o=ALU_XOR;
                    5: begin
                        legal_o=(funct7==0 || funct7==7'h20);
                        alu_op_o=(funct7==7'h20) ? ALU_SRA : ALU_SRL;
                    end
                    6: alu_op_o=ALU_OR;
                    7: alu_op_o=ALU_AND;
                endcase
            end
            7'h03: begin legal_o=(funct3==2); kind_o=K_LOAD; alu_b_sel_o=1; result_sel_o=1; end
            7'h23: begin legal_o=(funct3==2); kind_o=K_STORE; alu_b_sel_o=1; imm_format_o=IMM_S; end
            7'h63: begin
                legal_o=(funct3==0 || funct3==1 || funct3==4 || funct3==5);
                kind_o=K_BRANCH; imm_format_o=IMM_B;
            end
            7'h6f: begin legal_o=1; kind_o=K_JAL; imm_format_o=IMM_J; result_sel_o=2; end
            7'h67: begin legal_o=(funct3==0); kind_o=K_JALR; alu_b_sel_o=1; result_sel_o=2; end
            7'h37: begin legal_o=1; imm_format_o=IMM_U; alu_a_sel_o=2; alu_b_sel_o=1; end
            7'h17: begin legal_o=1; imm_format_o=IMM_U; alu_a_sel_o=1; alu_b_sel_o=1; end
            default: legal_o=0;
        endcase
        // Una codificacion ilegal deja tambien las selecciones en valores seguros.
        if (!legal_o) begin
            kind_o=K_ALU; imm_format_o=IMM_I; alu_op_o=ALU_ADD;
            alu_a_sel_o=0; alu_b_sel_o=0; result_sel_o=0;
        end
    end
endmodule
