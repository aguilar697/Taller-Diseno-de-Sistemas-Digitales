// Registro MMIO de victorias y driver de cuatro digitos.
module sevenseg_peripheral #(
    parameter int unsigned CLK_FREQ_HZ = 100_000_000,
    parameter int unsigned FRAME_REFRESH_HZ = 1_000
)(
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        write_enable_i,
    input  logic [1:0]  addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,
    output logic [6:0]  seg_o,
    output logic [3:0]  an_o
);
    logic [7:0] j1_wins_q,j2_wins_q;

    always_ff @(posedge clk_i) begin
        if(rst_i)begin
            j1_wins_q<=8'd0;
            j2_wins_q<=8'd0;
        end else if(write_enable_i && addr_i==2'b00)begin
            j1_wins_q<=wdata_i[7:0];
            j2_wins_q<=wdata_i[15:8];
        end
    end

    always_ff @(posedge clk_i) begin
        if(rst_i) rdata_o<=32'b0;
        else if(addr_i==2'b00)
            rdata_o<={16'b0,j2_wins_q,j1_wins_q};
        else rdata_o<=32'b0;
    end

    sevenseg_driver #(
        .CLK_FREQ_HZ(CLK_FREQ_HZ),
        .FRAME_REFRESH_HZ(FRAME_REFRESH_HZ)
    ) driver(
        .clk_i(clk_i),.rst_i(rst_i),.j1_wins_i(j1_wins_q),
        .j2_wins_i(j2_wins_q),.seg_o(seg_o),.an_o(an_o)
    );
endmodule
