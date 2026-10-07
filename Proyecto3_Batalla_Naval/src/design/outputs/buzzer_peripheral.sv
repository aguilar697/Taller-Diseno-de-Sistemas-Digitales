// Registro MMIO y generador de tonos para el buzzer.
// Cada sonido tiene frecuencia y duracion definidas (nivel 4, seccion 6): al
// cumplirse la duracion el buzzer vuelve solo a apagado, sin que el programa
// tenga que escribir OFF ni medir tiempo.
// La victoria es una secuencia de cuatro notas ascendentes (Do5, Mi5, Sol5,
// Do6), cada una con duracion VICTORY_DURATION.
module buzzer_peripheral #(
    parameter int unsigned HIT_HALF_PERIOD = 50_000,
    parameter int unsigned MISS_HALF_PERIOD = 125_000,
    parameter int unsigned SUNK_HALF_PERIOD = 71_429,
    parameter int unsigned INVALID_HALF_PERIOD = 200_000,
    parameter int unsigned VICTORY_HALF_PERIOD = 95_602,     // Do5  523 Hz
    parameter int unsigned VICTORY_HALF_PERIOD_2 = 75_873,   // Mi5  659 Hz
    parameter int unsigned VICTORY_HALF_PERIOD_3 = 63_776,   // Sol5 784 Hz
    parameter int unsigned VICTORY_HALF_PERIOD_4 = 47_801,   // Do6 1047 Hz
    // Duraciones en ciclos de reloj (100 MHz): 150, 250, 400 y 300 ms; la
    // victoria dura 200 ms por nota (800 ms en total).
    parameter int unsigned HIT_DURATION = 15_000_000,
    parameter int unsigned MISS_DURATION = 25_000_000,
    parameter int unsigned SUNK_DURATION = 40_000_000,
    parameter int unsigned INVALID_DURATION = 30_000_000,
    parameter int unsigned VICTORY_DURATION = 20_000_000
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
    localparam int unsigned VIC_A=(VICTORY_HALF_PERIOD>VICTORY_HALF_PERIOD_2) ? VICTORY_HALF_PERIOD : VICTORY_HALF_PERIOD_2;
    localparam int unsigned VIC_B=(VICTORY_HALF_PERIOD_3>VICTORY_HALF_PERIOD_4) ? VICTORY_HALF_PERIOD_3 : VICTORY_HALF_PERIOD_4;
    localparam int unsigned VIC_MAX=(VIC_A>VIC_B) ? VIC_A : VIC_B;
    localparam int unsigned MAX_HALF_PERIOD=(MAX_C>VIC_MAX) ? MAX_C : VIC_MAX;
    localparam int unsigned COUNT_WIDTH=(MAX_HALF_PERIOD<=1) ? 1 : $clog2(MAX_HALF_PERIOD+1);

    localparam int unsigned DUR_A=(HIT_DURATION>MISS_DURATION) ? HIT_DURATION : MISS_DURATION;
    localparam int unsigned DUR_B=(SUNK_DURATION>INVALID_DURATION) ? SUNK_DURATION : INVALID_DURATION;
    localparam int unsigned DUR_C=(DUR_A>DUR_B) ? DUR_A : DUR_B;
    localparam int unsigned MAX_DURATION=(DUR_C>VICTORY_DURATION) ? DUR_C : VICTORY_DURATION;
    localparam int unsigned DURATION_WIDTH=(MAX_DURATION<=1) ? 1 : $clog2(MAX_DURATION+1);

    logic [2:0] command_q;
    logic [COUNT_WIDTH-1:0] tone_count;
    logic [COUNT_WIDTH-1:0] half_period;
    logic [DURATION_WIDTH-1:0] duration_count;
    logic [DURATION_WIDTH-1:0] duration;
    logic [1:0] note_q;              // nota actual de la secuencia de victoria
    logic [COUNT_WIDTH-1:0] victory_half_period;

    always_comb begin
        case(note_q)
            2'd0:    victory_half_period=COUNT_WIDTH'(VICTORY_HALF_PERIOD);
            2'd1:    victory_half_period=COUNT_WIDTH'(VICTORY_HALF_PERIOD_2);
            2'd2:    victory_half_period=COUNT_WIDTH'(VICTORY_HALF_PERIOD_3);
            default: victory_half_period=COUNT_WIDTH'(VICTORY_HALF_PERIOD_4);
        endcase
    end

    always_comb begin
        case(command_q)
            3'd1:begin half_period=COUNT_WIDTH'(HIT_HALF_PERIOD);     duration=DURATION_WIDTH'(HIT_DURATION);     end
            3'd2:begin half_period=COUNT_WIDTH'(MISS_HALF_PERIOD);    duration=DURATION_WIDTH'(MISS_DURATION);    end
            3'd3:begin half_period=COUNT_WIDTH'(SUNK_HALF_PERIOD);    duration=DURATION_WIDTH'(SUNK_DURATION);    end
            3'd4:begin half_period=COUNT_WIDTH'(INVALID_HALF_PERIOD); duration=DURATION_WIDTH'(INVALID_DURATION); end
            3'd5:begin half_period=victory_half_period;               duration=DURATION_WIDTH'(VICTORY_DURATION); end
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
            note_q<=2'd0;
            tone_count<='0;
            duration_count<='0;
            buzzer_o<=1'b0;
        end else if(write_enable_i && addr_i==2'b00)begin
            // Toda escritura es una orden nueva: reinicia tono, duracion y nota.
            command_q<=wdata_i[2:0];
            note_q<=2'd0;
            tone_count<='0;
            duration_count<='0;
            buzzer_o<=1'b0;
        end else if(command_q==3'd0 || half_period==0)begin
            note_q<=2'd0;
            tone_count<='0;
            duration_count<='0;
            buzzer_o<=1'b0;
        end else if(duration_count>=duration-1'b1)begin
            tone_count<='0;
            duration_count<='0;
            buzzer_o<=1'b0;
            if(command_q==3'd5 && note_q!=2'd3)begin
                // Victoria: pasa a la siguiente nota de la secuencia.
                note_q<=note_q+1'b1;
            end else begin
                // Termino el sonido: el buzzer vuelve solo a apagado.
                command_q<=3'd0;
                note_q<=2'd0;
            end
        end else begin
            duration_count<=duration_count+1'b1;
            if(tone_count>=half_period-1'b1)begin
                tone_count<='0;
                buzzer_o<=~buzzer_o;
            end else tone_count<=tone_count+1'b1;
        end
    end
endmodule
