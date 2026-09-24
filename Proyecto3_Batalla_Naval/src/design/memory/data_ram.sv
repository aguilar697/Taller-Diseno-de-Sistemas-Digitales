// RAM de datos: 1024 palabras de 32 bits con lectura sincrona.
module data_ram (
    input  logic        clk_i,
    input  logic        write_enable_i,
    input  logic [9:0]  addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o
);
    logic [31:0] memory [0:1023];

    always_ff @(posedge clk_i) begin
        if (write_enable_i) memory[addr_i] <= wdata_i;
        rdata_o <= memory[addr_i];
    end
endmodule
