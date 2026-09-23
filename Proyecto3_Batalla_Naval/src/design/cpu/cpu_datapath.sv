// Registros de la instruccion en curso, rutas combinacionales y acceso de datos.
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
    logic [31:0] pc_q, instruction_pc_q, ir_q;
    logic [31:0] operand_a_q, operand_b_q, alu_result_q, load_data_q, next_pc_q, link_q;
    logic [31:0] rs1_data, rs2_data, immediate, alu_a, alu_b, alu_result, wb_data;
    logic [31:0] next_pc, sequential_pc, relative_target, indirect_target;
    logic branch_taken, changes_flow;
    register_file registers (
        .clk_i(clk_i), .rst_i(rst_i), .write_enable_i(rf_we_i && !rst_i),
        .rs1_i(ir_q[19:15]), .rs2_i(ir_q[24:20]), .rd_i(ir_q[11:7]),
        .wdata_i(wb_data), .rs1_data_o(rs1_data), .rs2_data_o(rs2_data)
    );
    immediate_generator immediates (.instruction_i(ir_q), .format_i(imm_format_i), .immediate_o(immediate));
    alu execution_alu (.a_i(alu_a), .b_i(alu_b), .op_i(alu_op_i), .result_o(alu_result));
    always_comb begin
        case (alu_a_sel_i)
            0: alu_a=operand_a_q;
            1: alu_a=instruction_pc_q;
            default: alu_a=0;
        endcase
        alu_b=alu_b_sel_i ? immediate : operand_b_q;
        case (result_sel_i)
            0: wb_data=alu_result_q;
            1: wb_data=load_data_q;
            2: wb_data=link_q;
            default: wb_data=0;
        endcase
        case (ir_q[14:12])
            0: branch_taken=(operand_a_q==operand_b_q);
            1: branch_taken=(operand_a_q!=operand_b_q);
            4: branch_taken=($signed(operand_a_q)<$signed(operand_b_q));
            5: branch_taken=($signed(operand_a_q)>=$signed(operand_b_q));
            default: branch_taken=0;
        endcase
    end
    assign sequential_pc=instruction_pc_q+32'd4;
    assign relative_target=instruction_pc_q+immediate;
    assign indirect_target=alu_result & 32'hffff_fffe;
    assign changes_flow=(kind_i==K_JAL || kind_i==K_JALR || (kind_i==K_BRANCH && branch_taken));
    always_comb begin
        next_pc=sequential_pc;
        if (kind_i==K_JALR) next_pc=indirect_target;
        else if (kind_i==K_JAL || (kind_i==K_BRANCH && branch_taken)) next_pc=relative_target;
        execute_valid_o=1;
        if ((kind_i==K_LOAD || kind_i==K_STORE) && alu_result[1:0]!=0) execute_valid_o=0;
        // Solo se comprueba el destino si realmente cambia el flujo de ejecucion.
        if (changes_flow && (next_pc[1:0]!=0 || next_pc[31:13]!=0)) execute_valid_o=0;
    end
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            pc_q<=0; instruction_pc_q<=0; ir_q<=0; operand_a_q<=0; operand_b_q<=0;
            alu_result_q<=0; load_data_q<=0; next_pc_q<=0; link_q<=0;
        end else begin
            if (ir_en_i) begin ir_q<=ProgIn_i; instruction_pc_q<=pc_q; end
            if (operands_en_i) begin operand_a_q<=rs1_data; operand_b_q<=rs2_data; end
            if (execute_en_i) begin
                alu_result_q<=alu_result; next_pc_q<=next_pc; link_q<=sequential_pc;
            end
            if (load_en_i) load_data_q<=DataIn_i;
            if (pc_en_i) pc_q<=next_pc_q;
        end
    end
    assign ProgAddress_o=pc_q;
    assign instruction_o=ir_q;
    assign pc_valid_o=(pc_q[31:13]==0 && pc_q[1:0]==0);
    assign DataAddress_o=(mem_access_i && !rst_i) ? alu_result_q : 32'b0;
    // Conserva rs2 para STORE aunque la ALU haya sumado un inmediato.
    assign DataOut_o=(store_i && !rst_i) ? operand_b_q : 32'b0;
endmodule
