`timescale 1ns/1ps
// S2: motor del Ahorcado. Interfaz externa acordada por el equipo.
// reset > new_game > seleccion/evaluacion. Reset sincronico activo en alto.
// Una letra A-Z se evalua en el flanco que muestrea letter_valid en ACTIVE.
// Los resultados registrados se leen en el siguiente flanco por S1.
module word_engine (
    input  logic        clk,
    input  logic        reset,
    input  logic        new_game,
    input  logic        difficulty,
    input  logic        letter_valid,
    input  logic [7:0]  letter_ascii,
    output logic        word_ready,
    output logic [3:0]  word_length,
    output logic [95:0] revealed_word,
    output logic        letter_correct,
    output logic        letter_repeated,
    output logic        word_complete
);
    typedef enum logic [1:0] {IDLE, SELECT_WORD, ACTIVE} state_t;
    state_t state;
    logic selected_difficulty;
    logic [95:0] secret_word;
    logic [25:0] used_letters;
    logic [5:0] random_state;
    logic [5:0] candidate_index;
    logic [95:0] candidate_word;
    logic [3:0] candidate_length;
    logic candidate_valid;
    logic valid_ascii, evaluation_correct, evaluation_repeated, evaluation_complete;
    logic [25:0] next_used_letters;
    logic [95:0] next_revealed_word;
    integer position;

    word_lfsr random_source (.clk(clk), .reset(reset), .state(random_state));
    // Estados 1..63 -> candidatos 0..62. ROM rechaza 50..62.
    assign candidate_index = random_state - 6'd1;
    word_rom bank (
        .index(candidate_index), .word_data(candidate_word),
        .word_length(candidate_length), .valid(candidate_valid)
    );
    letter_evaluator evaluator (
        .letter_ascii(letter_ascii), .secret_word(secret_word),
        .word_length(word_length), .used_letters(used_letters),
        .revealed_word(revealed_word), .valid_ascii(valid_ascii),
        .correct(evaluation_correct), .repeated(evaluation_repeated),
        .next_used_letters(next_used_letters), .next_revealed_word(next_revealed_word),
        .complete(evaluation_complete)
    );

    always_ff @(posedge clk) begin
        if (reset) begin
            state <= IDLE;
            selected_difficulty <= 1'b0;
            secret_word <= {12{8'h20}};
            word_length <= 4'd0;
            revealed_word <= {12{8'h20}};
            used_letters <= 26'b0;
            word_ready <= 1'b0;
            letter_correct <= 1'b0;
            letter_repeated <= 1'b0;
            word_complete <= 1'b0;
        end else begin
            word_ready <= 1'b0;
            letter_correct <= 1'b0;
            letter_repeated <= 1'b0;
            if (new_game) begin
                state <= SELECT_WORD;
                selected_difficulty <= difficulty;
                secret_word <= {12{8'h20}};
                word_length <= 4'd0;
                revealed_word <= {12{8'h20}};
                used_letters <= 26'b0;
                word_complete <= 1'b0;
            end else begin
                case (state)
                    IDLE: begin end
                    SELECT_WORD: begin
                        if (candidate_valid &&
                            (!selected_difficulty || candidate_length >= 4'd6)) begin
                            secret_word <= candidate_word;
                            word_length <= candidate_length;
                            for (position = 0; position < 12; position = position + 1)
                                revealed_word[8*position +: 8] <=
                                    (position < candidate_length) ? 8'h5F : 8'h20;
                            used_letters <= 26'b0;
                            word_complete <= 1'b0;
                            word_ready <= 1'b1;
                            state <= ACTIVE;
                        end
                    end
                    ACTIVE: begin
                        if (letter_valid && valid_ascii && !word_complete) begin
                            used_letters <= next_used_letters;
                            revealed_word <= next_revealed_word;
                            letter_correct <= evaluation_correct;
                            letter_repeated <= evaluation_repeated;
                            word_complete <= evaluation_complete;
                        end
                    end
                    default: begin
                        state <= IDLE;
                        word_complete <= 1'b0;
                    end
                endcase
            end
        end
    end
endmodule
