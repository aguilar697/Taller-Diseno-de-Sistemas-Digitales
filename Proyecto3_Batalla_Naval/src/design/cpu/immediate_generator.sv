// Reconstruye constantes/offsets del IR según el formato seleccionado por decoder.
// Combinacional, sin memoria: I/S/B/J extienden el signo; U coloca los 20 bits
// altos de la instrucción y completa con 12 ceros inferiores.
module immediate_generator (
    input logic [31:0] instruction_i,
    input logic [2:0] format_i,
    output logic [31:0] immediate_o
);
    import cpu_pkg::*;
    always_comb begin
        case (format_i)
            // I: 12 bits [31:20] para ADDI/LW/JALR, entre otros.
            // Replicar bit 31 extiende signo: 0xFFF (-1) -> 0xFFFFFFFF.
            // SLTIU también extiende el signo, luego compara valores sin signo.
            IMM_I: immediate_o = {{20{instruction_i[31]}}, instruction_i[31:20]};
            // S: offset de SW dividido en [31:25] y [11:7]. Estos últimos
            // bits no son un rd: se vuelven a concatenar como inmediato.
            IMM_S: immediate_o = {{20{instruction_i[31]}}, instruction_i[31:25], instruction_i[11:7]};
            // B: recompone imm[12|11|10:5|4:1|0]. El cero inferior implícito
            // da offsets múltiplos de dos bytes; datapath exige además un destino
            // tomado alineado a cuatro, porque no admite instrucciones comprimidas.
            IMM_B: immediate_o = {{19{instruction_i[31]}}, instruction_i[31],
                instruction_i[7], instruction_i[30:25], instruction_i[11:8], 1'b0};
            // U: LUI/AUIPC utilizan imm[31:12]<<12, no constante de 12 bits.
            IMM_U: immediate_o = {instruction_i[31:12], 12'b0};
            // J: reordena imm[20|19:12|11|10:1|0] de JAL y extiende su signo.
            // B/J se suman al PC de la instrucción, no al PC+4.
            IMM_J: immediate_o = {{11{instruction_i[31]}}, instruction_i[31],
                instruction_i[19:12], instruction_i[20], instruction_i[30:21], 1'b0};
            default: immediate_o = 32'b0;
        endcase
    end
endmodule
