// Nucleo multiciclo. La ROM y la plataforma de datos se conectan externamente.
module cpu (
    input logic clk_i, rst_i,
    output logic [31:0] ProgAddress_o,
    input logic [31:0] ProgIn_i,
    output logic [31:0] DataAddress_o, DataOut_o,
    input logic [31:0] DataIn_i,
    output logic we_o
);
    logic [31:0] instruction;
    logic [2:0] kind_d, imm_format_d;
    logic [3:0] alu_op_d;
    logic [1:0] alu_a_sel_d, result_sel_d;
    logic alu_b_sel_d;
    logic legal, pc_valid, execute_valid, fault;
    logic [2:0] kind, imm_format;
    logic [3:0] alu_op;
    logic [1:0] alu_a_sel, result_sel;
    logic alu_b_sel, ir_en, operands_en, execute_en, load_en, pc_en, rf_we, mem_access, store;
    instruction_decoder decoder (
        .instruction_i(instruction), .legal_o(legal), .kind_o(kind_d), .imm_format_o(imm_format_d),
        .alu_op_o(alu_op_d), .alu_a_sel_o(alu_a_sel_d), .result_sel_o(result_sel_d), .alu_b_sel_o(alu_b_sel_d)
    );
    // DECODE conserva los controles junto con los operandos. Asi EXECUTE no
    // concatena la decodificacion completa con la ALU y la validacion de destino.
    // No agrega ciclos ni permite instrucciones simultaneas: no es un pipeline.
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            kind<=0; imm_format<=0; alu_op<=0;
            alu_a_sel<=0; result_sel<=0; alu_b_sel<=0;
        end else if (operands_en) begin
            kind<=kind_d; imm_format<=imm_format_d; alu_op<=alu_op_d;
            alu_a_sel<=alu_a_sel_d; result_sel<=result_sel_d; alu_b_sel<=alu_b_sel_d;
        end
    end
    cpu_control control (
        .clk_i(clk_i), .rst_i(rst_i), .legal_i(legal), .pc_valid_i(pc_valid),
        .execute_valid_i(execute_valid), .kind_i(kind), .ir_en_o(ir_en), .operands_en_o(operands_en),
        .execute_en_o(execute_en), .load_en_o(load_en), .pc_en_o(pc_en), .rf_we_o(rf_we),
        .mem_access_o(mem_access), .store_o(store), .fault_o(fault)
    );
    cpu_datapath datapath (
        .clk_i(clk_i), .rst_i(rst_i), .ProgIn_i(ProgIn_i), .DataIn_i(DataIn_i),
        .kind_i(kind), .imm_format_i(imm_format), .alu_op_i(alu_op), .alu_a_sel_i(alu_a_sel),
        .result_sel_i(result_sel), .alu_b_sel_i(alu_b_sel), .ir_en_i(ir_en), .operands_en_i(operands_en),
        .execute_en_i(execute_en), .load_en_i(load_en), .pc_en_i(pc_en), .rf_we_i(rf_we),
        .mem_access_i(mem_access), .store_i(store), .ProgAddress_o(ProgAddress_o),
        .DataAddress_o(DataAddress_o), .DataOut_o(DataOut_o), .instruction_o(instruction),
        .pc_valid_o(pc_valid), .execute_valid_o(execute_valid)
    );
    assign we_o=store;
endmodule
