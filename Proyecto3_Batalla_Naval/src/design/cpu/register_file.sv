// Banco RV32I: 32 registros visibles de 32 bits, con x0 constante en cero.
// Dos lecturas combinacionales obtienen rs1 y rs2 simultáneamente;
// una escritura síncrona actualiza rd cuando la FSM habilita WRITEBACK.
module register_file (
    input logic clk_i, rst_i, write_enable_i,
    input logic [4:0] rs1_i, rs2_i, rd_i,
    input logic [31:0] wdata_i,
    output logic [31:0] rs1_data_o, rs2_data_o
);
    // Solo x1-x31 necesitan almacenamiento. Los índices de 5 bits eligen 0-31.
    // x1=ra y x2=sp son convenciones software, sin tratamiento especial aquí.
    logic [31:0] registers [1:31];
    integer index;
    always_ff @(posedge clk_i) begin
        // Reset síncrono tiene prioridad sobre escritura y limpia x1-x31.
        if (rst_i) begin
            for (index=1; index<32; index=index+1) registers[index] <= 32'b0;
        // Descartar rd=0 mantiene x0 inmutable incluso ante ADDI/LW/JAL a x0.
        // Sin enable, los registros conservan su contenido entre ciclos.
        end else if (write_enable_i && rd_i != 0) begin
            registers[rd_i] <= wdata_i;
        end
    end
    // Lecturas sin esperar flanco: al cambiar rs1/rs2 cambia el valor leído.
    // Datapath captura las salidas en DECODE antes de ejecutar la operación.
    assign rs1_data_o = (rs1_i == 0) ? 32'b0 : registers[rs1_i];
    assign rs2_data_o = (rs2_i == 0) ? 32'b0 : registers[rs2_i];
endmodule
