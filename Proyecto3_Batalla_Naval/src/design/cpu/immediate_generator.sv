// Reconstruccion de inmediatos desde el registro de instruccion.
module immediate_generator (
    input logic [31:0] instruction_i,
    input logic [2:0] format_i,
    output logic [31:0] immediate_o
);
    import cpu_pkg::*;
    always_comb begin
        case (format_i)
            IMM_I: immediate_o = {{20{instruction_i[31]}}, instruction_i[31:20]};
            IMM_S: immediate_o = {{20{instruction_i[31]}}, instruction_i[31:25], instruction_i[11:7]};
            // B y J incluyen el cero inferior: los offsets se expresan en bytes.
            IMM_B: immediate_o = {{19{instruction_i[31]}}, instruction_i[31],
                instruction_i[7], instruction_i[30:25], instruction_i[11:8], 1'b0};
            IMM_U: immediate_o = {instruction_i[31:12], 12'b0};
            IMM_J: immediate_o = {{11{instruction_i[31]}}, instruction_i[31],
                instruction_i[19:12], instruction_i[20], instruction_i[30:21], 1'b0};
            default: immediate_o = 32'b0;
        endcase
    end
endmodule
