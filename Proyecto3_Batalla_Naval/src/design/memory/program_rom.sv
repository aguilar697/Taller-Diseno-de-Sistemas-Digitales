// ROM de instrucciones: 8 KiB, lectura sincrona y sin borrado por reset.
module program_rom #(
    parameter INIT_FILE = ""
)(
    input logic clk_i,
    input logic [31:0] addr_i,
    output logic [31:0] rdata_o
);
    localparam logic [31:0] NOP=32'h00000013;
    logic [31:0] memory [0:2047];
    integer index;
    initial begin
        for (index=0; index<2048; index=index+1) memory[index]=NOP;
        // Cadena vacia: ROM de NOP para pruebas; integracion selecciona program.hex.
        if (INIT_FILE != "") $readmemh(INIT_FILE, memory);
    end
    always_ff @(posedge clk_i) begin
        if (addr_i[31:13]==0 && addr_i[1:0]==0) rdata_o<=memory[addr_i[12:2]];
        else rdata_o<=NOP;
    end
endmodule
