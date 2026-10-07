// Núcleo de 32 bits con un subconjunto RV32I, multiciclo y sin pipeline.
// Mantiene una sola instrucción activa: control secuencia los ciclos y datapath
// conserva operandos/resultados. Las reglas del juego pertenecen al programa.
// La separación de buses de instrucciones y datos es una organización Harvard.
module cpu (
    input logic clk_i, rst_i,
    // Bus de instrucciones: PC en bytes hacia ROM y palabra leída desde ROM.
    output logic [31:0] ProgAddress_o,
    input logic [31:0] ProgIn_i,
    // Bus de datos: dirección, dato de escritura y respuesta de RAM/periféricos.
    // El destino se decide fuera del CPU mediante el decodificador MMIO.
    output logic [31:0] DataAddress_o, DataOut_o,
    input logic [31:0] DataIn_i,
    output logic we_o
);
    // instruction procede del IR del datapath; permanece estable al ejecutarla.
    logic [31:0] instruction;
    // Sufijo _d: controles combinacionales que propone el decoder.
    logic [2:0] kind_d, imm_format_d;
    logic [3:0] alu_op_d;
    logic [1:0] alu_a_sel_d, result_sel_d;
    logic alu_b_sel_d;
    // legal: codificación admitida; pc_valid: búsqueda dentro de ROM y alineada;
    // execute_valid: dirección de datos/destino de salto válido al ejecutar.
    // fault es interno: detiene el núcleo y puede observarse en simulación.
    logic legal, pc_valid, execute_valid, fault;
    // Controles registrados en DECODE: se utilizan durante la ejecución.
    logic [2:0] kind, imm_format;
    logic [3:0] alu_op;
    logic [1:0] alu_a_sel, result_sel;
    logic alu_b_sel, ir_en, operands_en, execute_en, load_en, pc_en, rf_we, mem_access, store;
    // DECODIFICACIÓN: transforma los campos binarios del IR en selecciones.
    // No ejecuta operaciones ni escribe registros; informa si son legales.
    instruction_decoder decoder (
        .instruction_i(instruction), .legal_o(legal), .kind_o(kind_d), .imm_format_o(imm_format_d),
        .alu_op_o(alu_op_d), .alu_a_sel_o(alu_a_sel_d), .result_sel_o(result_sel_d), .alu_b_sel_o(alu_b_sel_d)
    );
    // REGISTRO DE CONTROL: operands_en se activa únicamente en DECODE legal.
    // El mismo flanco captura controles aquí y operandos dentro del datapath.
    // Separar decoder de EXECUTE reduce la lógica combinacional de esa ruta.
    // Estos registros no forman un pipeline: no superponen instrucciones.
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            kind<=0; imm_format<=0; alu_op<=0;
            alu_a_sel<=0; result_sel<=0; alu_b_sel<=0;
        end else if (operands_en) begin
            kind<=kind_d; imm_format<=imm_format_d; alu_op<=alu_op_d;
            alu_a_sel<=alu_a_sel_d; result_sel<=result_sel_d; alu_b_sel<=alu_b_sel_d;
        end
    end
    // CONTROL: FSM que habilita IR, operandos, ejecución, carga, banco y PC.
    // Decide cuándo ocurre cada efecto; recibe las validaciones del datapath.
    cpu_control control (
        .clk_i(clk_i), .rst_i(rst_i), .legal_i(legal), .pc_valid_i(pc_valid),
        .execute_valid_i(execute_valid), .kind_i(kind), .ir_en_o(ir_en), .operands_en_o(operands_en),
        .execute_en_o(execute_en), .load_en_o(load_en), .pc_en_o(pc_en), .rf_we_o(rf_we),
        .mem_access_o(mem_access), .store_o(store), .fault_o(fault)
    );
    // DATAPATH: contiene PC/IR, banco, inmediatos, ALU y registros intermedios.
    // Decide qué valor circula por cada ruta según los controles recibidos.
    cpu_datapath datapath (
        .clk_i(clk_i), .rst_i(rst_i), .ProgIn_i(ProgIn_i), .DataIn_i(DataIn_i),
        .kind_i(kind), .imm_format_i(imm_format), .alu_op_i(alu_op), .alu_a_sel_i(alu_a_sel),
        .result_sel_i(result_sel), .alu_b_sel_i(alu_b_sel), .ir_en_i(ir_en), .operands_en_i(operands_en),
        .execute_en_i(execute_en), .load_en_i(load_en), .pc_en_i(pc_en), .rf_we_i(rf_we),
        .mem_access_i(mem_access), .store_i(store), .ProgAddress_o(ProgAddress_o),
        .DataAddress_o(DataAddress_o), .DataOut_o(DataOut_o), .instruction_o(instruction),
        .pc_valid_o(pc_valid), .execute_valid_o(execute_valid)
    );
    // Únicamente STORE escribe en el bus externo. Reset/FAULT inhiben store
    // desde la FSM; las instrucciones ALU y LW nunca activan esta escritura.
    assign we_o=store;
endmodule
