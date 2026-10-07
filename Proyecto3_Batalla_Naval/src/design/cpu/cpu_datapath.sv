// Camino de datos: conserva una instrucción y sus resultados entre ciclos.
// La FSM habilita capturas; ALU, comparadores y multiplexores calculan los valores.
module cpu_datapath (
    input logic clk_i, rst_i,
    input logic [31:0] ProgIn_i, DataIn_i,
    input logic [2:0] kind_i, imm_format_i,
    input logic [3:0] alu_op_i,
    input logic [1:0] alu_a_sel_i, result_sel_i,
    input logic alu_b_sel_i,
    input logic ir_en_i, operands_en_i, execute_en_i, load_en_i, pc_en_i, rf_we_i,
    input logic mem_access_i, store_i,
    output logic [31:0] ProgAddress_o, DataAddress_o, DataOut_o, instruction_o,
    output logic pc_valid_o, execute_valid_o
);
    import cpu_pkg::*;
    // PC: dirección a buscar. instruction_pc: dirección de la instrucción
    // retenida. IR: palabra que el decoder analiza durante todos sus ciclos.
    logic [31:0] pc_q, instruction_pc_q, ir_q;
    // Valores conservados: rs1/rs2, resultado ALU, dato cargado, próximo PC y
    // enlace PC+4. Los enables de la FSM deciden cuándo se actualiza cada uno.
    logic [31:0] operand_a_q, operand_b_q, alu_result_q, load_data_q, next_pc_q, link_q;
    // Valores combinacionales: no conservan estado por sí solos.
    logic [31:0] rs1_data, rs2_data, immediate, alu_a, alu_b, alu_result, wb_data;
    logic [31:0] next_pc, sequential_pc, relative_target, indirect_target;
    logic branch_taken, changes_flow;
    // BANCO: índices rs1=[19:15], rs2=[24:20] y rd=[11:7] tomados del IR.
    // Lee operandos para DECODE; solo WRITEBACK habilita escribir wb_data en rd.
    register_file registers (
        .clk_i(clk_i), .rst_i(rst_i), .write_enable_i(rf_we_i && !rst_i),
        .rs1_i(ir_q[19:15]), .rs2_i(ir_q[24:20]), .rd_i(ir_q[11:7]),
        .wdata_i(wb_data), .rs1_data_o(rs1_data), .rs2_data_o(rs2_data)
    );
    // INMEDIATO: reconstruye constantes/offsets de los formatos I/S/B/U/J.
    immediate_generator immediates (.instruction_i(ir_q), .format_i(imm_format_i), .immediate_o(immediate));
    // ALU combinacional: también suma base+offset para LW/SW/JALR.
    alu execution_alu (.a_i(alu_a), .b_i(alu_b), .op_i(alu_op_i), .result_o(alu_result));
    always_comb begin
        // MUX A: rs1 para operaciones normales; PC para AUIPC; cero para LUI.
        case (alu_a_sel_i)
            0: alu_a=operand_a_q;
            1: alu_a=instruction_pc_q;
            default: alu_a=0;
        endcase
        // MUX B: inmediato para ADDI/LW/SW, o rs2 para operaciones entre registros.
        alu_b=alu_b_sel_i ? immediate : operand_b_q;
        // MUX DE WRITEBACK: 0=resultado ALU, 1=LW, 2=enlace de JAL/JALR.
        // Selecciona valores registrados, no un cálculo cambiante de otro ciclo.
        case (result_sel_i)
            0: wb_data=alu_result_q;
            1: wb_data=load_data_q;
            2: wb_data=link_q;
            default: wb_data=0;
        endcase
        // CONDICIÓN DE BRANCH según funct3: BEQ/BNE y BLT/BGE con signo.
        // Se comparan operandos originales; un branch no escribe un registro rd.
        case (ir_q[14:12])
            0: branch_taken=(operand_a_q==operand_b_q);
            1: branch_taken=(operand_a_q!=operand_b_q);
            4: branch_taken=($signed(operand_a_q)<$signed(operand_b_q));
            5: branch_taken=($signed(operand_a_q)>=$signed(operand_b_q));
            default: branch_taken=0;
        endcase
    end
    // PRÓXIMO PC: cada instrucción de 32 bits ocupa cuatro bytes.
    // Branch/JAL suman offset al PC de esa instrucción, no a PC+4.
    assign sequential_pc=instruction_pc_q+32'd4;
    assign relative_target=instruction_pc_q+immediate;
    // JALR suma rs1+inmediato en ALU y elimina el bit 0 del destino.
    // El bit 1 aún puede desalinearlo: este núcleo no admite instrucciones comprimidas.
    assign indirect_target=alu_result & 32'hffff_fffe;
    assign changes_flow=(kind_i==K_JAL || kind_i==K_JALR || (kind_i==K_BRANCH && branch_taken));
    always_comb begin
        // Continúa secuencialmente salvo salto/branch tomado. PC+4 se guarda
        // como enlace incluso cuando el próximo PC seleccionado es otro.
        next_pc=sequential_pc;
        if (kind_i==K_JALR) next_pc=indirect_target;
        else if (kind_i==K_JAL || (kind_i==K_BRANCH && branch_taken)) next_pc=relative_target;
        // VALIDACIÓN: LW/SW requieren dirección múltiplo de cuatro.
        // RAM o periférico MMIO se selecciona fuera del CPU, en el bus de datos.
        execute_valid_o=1;
        if ((kind_i==K_LOAD || kind_i==K_STORE) && alu_result[1:0]!=0) execute_valid_o=0;
        // Un destino tomado debe estar alineado y dentro de la ROM de 8 KiB.
        // No valida el destino descartado de un branch no tomado. Un PC+4
        // fuera de ROM se detecta en la siguiente FETCH_REQ.
        if (changes_flow && (next_pc[1:0]!=0 || next_pc[31:13]!=0)) execute_valid_o=0;
    end
    // REGISTROS AL FLANCO: <= captura valores anteriores al mismo flanco.
    // Sin enable, un registro conserva su contenido para el siguiente ciclo.
    always_ff @(posedge clk_i) begin
        // Reset síncrono limpia PC/IR/intermedios. El banco se reinicia en
        // su propio módulo; este bloque no borra la ROM ni la RAM de datos.
        if (rst_i) begin
            pc_q<=0; instruction_pc_q<=0; ir_q<=0; operand_a_q<=0; operand_b_q<=0;
            alu_result_q<=0; load_data_q<=0; next_pc_q<=0; link_q<=0;
        end else begin
            // FETCH_CAPTURE: retiene palabra ROM y dirección para saltos/enlace.
            if (ir_en_i) begin ir_q<=ProgIn_i; instruction_pc_q<=pc_q; end
            // DECODE: captura las dos lecturas del banco antes de ejecutar.
            if (operands_en_i) begin operand_a_q<=rs1_data; operand_b_q<=rs2_data; end
            // EXECUTE: conserva cálculo, destino y retorno para fases posteriores.
            if (execute_en_i) begin
                alu_result_q<=alu_result; next_pc_q<=next_pc; link_q<=sequential_pc;
            end
            // LOAD_CAPTURE: captura la respuesta de memoria, no su dirección.
            if (load_en_i) load_data_q<=DataIn_i;
            // COMMIT: único enable que avanza PC entre instrucciones.
            if (pc_en_i) pc_q<=next_pc_q;
        end
    end
    // INTERFACES: PC sale permanentemente a ROM; decoder recibe IR, no ProgIn.
    assign ProgAddress_o=pc_q;
    assign instruction_o=ir_q;
    // Mismo contrato de rango y alineación que admite la ROM.
    assign pc_valid_o=(pc_q[31:13]==0 && pc_q[1:0]==0);
    // Acceso de datos presenta dirección conservada desde EXECUTE. LOAD_REQ
    // y LOAD_CAPTURE la mantienen; fuera del acceso se entrega cero.
    assign DataAddress_o=(mem_access_i && !rst_i) ? alu_result_q : 32'b0;
    // SW escribe rs2 original, NO el resultado ALU ni el inmediato.
    // Ejemplo SW x3,4(x20): dirección=x20+4; dato=contenido de x3.
    assign DataOut_o=(store_i && !rst_i) ? operand_b_q : 32'b0;
endmodule
