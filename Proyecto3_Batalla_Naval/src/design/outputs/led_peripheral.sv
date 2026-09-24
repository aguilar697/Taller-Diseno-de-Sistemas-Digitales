// Registro MMIO para la fase actual de la partida.
module led_peripheral (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        write_enable_i,
    input  logic [1:0]  addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,
    output logic [1:0]  led_o
);
    logic [1:0] state_q;

    always_ff @(posedge clk_i) begin
        if(rst_i) state_q<=2'b00;
        else if(write_enable_i && addr_i==2'b00) state_q<=wdata_i[1:0];
    end

    always_ff @(posedge clk_i) begin
        if(rst_i) rdata_o<=32'b0;
        else if(addr_i==2'b00) rdata_o<={30'b0,state_q};
        else rdata_o<=32'b0;
    end

    always_comb begin
        led_o=state_q;
    end
endmodule
