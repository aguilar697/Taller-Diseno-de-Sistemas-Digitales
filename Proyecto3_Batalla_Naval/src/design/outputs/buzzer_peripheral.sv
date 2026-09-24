// Registro MMIO y generador de tonos continuos para el buzzer.
module buzzer_peripheral #(
    parameter int unsigned HIT_HALF_PERIOD = 50_000,
    parameter int unsigned MISS_HALF_PERIOD = 125_000,
    parameter int unsigned SUNK_HALF_PERIOD = 71_429,
    parameter int unsigned INVALID_HALF_PERIOD = 200_000,
    parameter int unsigned VICTORY_HALF_PERIOD = 33_333
)(
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        write_enable_i,
    input  logic [1:0]  addr_i,
    input  logic [31:0] wdata_i,
    output logic [31:0] rdata_o,
    output logic        buzzer_o
);
    localparam int unsigned MAX_A=(HIT_HALF_PERIOD>MISS_HALF_PERIOD) ? HIT_HALF_PERIOD : MISS_HALF_PERIOD;
    localparam int unsigned MAX_B=(SUNK_HALF_PERIOD>INVALID_HALF_PERIOD) ? SUNK_HALF_PERIOD : INVALID_HALF_PERIOD;
    localparam int unsigned MAX_C=(MAX_A>MAX_B) ? MAX_A : MAX_B;
    localparam int unsigned MAX_HALF_PERIOD=(MAX_C>VICTORY_HALF_PERIOD) ? MAX_C : VICTORY_HALF_PERIOD;
    localparam int unsigned COUNT_WIDTH=(MAX_HALF_PERIOD<=1) ? 1 : $clog2(MAX_HALF_PERIOD);

    logic [2:0] command_q;
    logic [COUNT_WIDTH-1:0] tone_count;
    logic [COUNT_WIDTH-1:0] half_period;

    always_comb begin
        case(command_q)
            3'd1:half_period=COUNT_WIDTH'(HIT_HALF_PERIOD);
            3'd2:half_period=COUNT_WIDTH'(MISS_HALF_PERIOD);
            3'd3:half_period=COUNT_WIDTH'(SUNK_HALF_PERIOD);
            3'd4:half_period=COUNT_WIDTH'(INVALID_HALF_PERIOD);
            3'd5:half_period=COUNT_WIDTH'(VICTORY_HALF_PERIOD);
            default:half_period='0;
        endcase
    end

    always_ff @(posedge clk_i) begin
        if(rst_i) rdata_o<=32'b0;
        else if(addr_i==2'b00) rdata_o<={29'b0,command_q};
        else rdata_o<=32'b0;
    end

    always_ff @(posedge clk_i) begin
        if(rst_i)begin
            command_q<=3'd0;
            tone_count<='0;
            buzzer_o<=1'b0;
        end else if(write_enable_i && addr_i==2'b00)begin
            command_q<=wdata_i[2:0];
            tone_count<='0;
            buzzer_o<=1'b0;
        end else if(command_q==3'd0 || half_period==0)begin
            tone_count<='0;
            buzzer_o<=1'b0;
        end else if(tone_count>=half_period-1'b1)begin
            tone_count<='0;
            buzzer_o<=~buzzer_o;
        end else tone_count<=tone_count+1'b1;
    end
endmodule
