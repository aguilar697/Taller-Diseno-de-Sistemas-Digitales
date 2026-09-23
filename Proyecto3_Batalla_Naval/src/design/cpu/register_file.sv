// Dos puertos de lectura combinacional y uno de escritura sincrona.
module register_file (
    input logic clk_i, rst_i, write_enable_i,
    input logic [4:0] rs1_i, rs2_i, rd_i,
    input logic [31:0] wdata_i,
    output logic [31:0] rs1_data_o, rs2_data_o
);
    logic [31:0] registers [1:31];
    integer index;
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            for (index=1; index<32; index=index+1) registers[index] <= 32'b0;
        end else if (write_enable_i && rd_i != 0) begin
            registers[rd_i] <= wdata_i;
        end
    end
    // x0 no requiere almacenamiento y nunca puede modificarse.
    assign rs1_data_o = (rs1_i == 0) ? 32'b0 : registers[rs1_i];
    assign rs2_data_o = (rs2_i == 0) ? 32'b0 : registers[rs2_i];
endmodule
