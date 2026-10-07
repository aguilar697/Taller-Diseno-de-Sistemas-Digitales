// Registro MMIO y generador de tonos para el buzzer.
// Cada sonido tiene frecuencia y duracion definidas (nivel 4, seccion 6): al
// cumplirse la duracion el buzzer vuelve solo a apagado, sin que el programa
// tenga que escribir OFF ni medir tiempo.
module buzzer_peripheral #(
    parameter int unsigned HIT_HALF_PERIOD = 50_000,
    parameter int unsigned MISS_HALF_PERIOD = 125_000,
    parameter int unsigned SUNK_HALF_PERIOD = 71_429,
    parameter int unsigned INVALID_HALF_PERIOD = 200_000,
    parameter int unsigned VICTORY_HALF_PERIOD = 33_333,
    // Duraciones en ciclos de reloj (100 MHz): 150, 250, 400, 300 y 800 ms.
    parameter int unsigned HIT_DURATION = 15_000_000,
    parameter int unsigned MISS_DURATION = 25_000_000,
    parameter int unsigned SUNK_DURATION = 40_000_000,
    parameter int unsigned INVALID_DURATION = 30_000_000,
    parameter int unsigned VICTORY_DURATION = 80_000_000
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

    localparam int unsigned DUR_A=(HIT_DURATION>MISS_DURATION) ? HIT_DURATION : MISS_DURATION;
    localparam int unsigned DUR_B=(SUNK_DURATION>INVALID_DURATION) ? SUNK_DURATION : INVALID_DURATION;
    localparam int unsigned DUR_C=(DUR_A>DUR_B) ? DUR_A : DUR_B;
    localparam int unsigned MAX_DURATION=(DUR_C>VICTORY_DURATION) ? DUR_C : VICTORY_DURATION;
    localparam int unsigned DURATION_WIDTH=(MAX_DURATION<=1) ? 1 : $clog2(MAX_DURATION);

    logic [2:0] command_q;
    logic [COUNT_WIDTH-1:0] tone_count;
    logic [COUNT_WIDTH-1:0] half_period;
    logic [DURATION_WIDTH-1:0] duration_count;
    logic [DURATION_WIDTH-1:0] duration;

    always_comb begin
        case(command_q)
            3'd1:begin half_period=COUNT_WIDTH'(HIT_HALF_PERIOD);     duration=DURATION_WIDTH'(HIT_DURATION);     end
            3'd2:begin half_period=COUNT_WIDTH'(MISS_HALF_PERIOD);    duration=DURATION_WIDTH'(MISS_DURATION);    end
            3'd3:begin half_period=COUNT_WIDTH'(SUNK_HALF_PERIOD);    duration=DURATION_WIDTH'(SUNK_DURATION);    end
            3'd4:begin half_period=COUNT_WIDTH'(INVALID_HALF_PERIOD); duration=DURATION_WIDTH'(INVALID_DURATION); end
            3'd5:begin half_period=COUNT_WIDTH'(VICTORY_HALF_PERIOD); duration=DURATION_WIDTH'(VICTORY_DURATION); end
            default:begin half_period='0; duration='0; end
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
            duration_count<='0;
            buzzer_o<=1'b0;
        end else if(write_enable_i && addr_i==2'b00)begin
            // Toda escritura es una orden nueva: reinicia tono y duracion.
            command_q<=wdata_i[2:0];
            tone_count<='0;
            duration_count<='0;
            buzzer_o<=1'b0;
        end else if(command_q==3'd0 || half_period==0)begin
            tone_count<='0;
            duration_count<='0;
            buzzer_o<=1'b0;
        end else if(duration_count>=duration-1'b1)begin
            // Termino el sonido: el buzzer vuelve solo a apagado.
            command_q<=3'd0;
            tone_count<='0;
            duration_count<='0;
            buzzer_o<=1'b0;
        end else begin
            duration_count<=duration_count+1'b1;
            if(tone_count>=half_period-1'b1)begin
                tone_count<='0;
                buzzer_o<=~buzzer_o;
            end else tone_count<=tone_count+1'b1;
        end
    end
endmodule
