`timescale 1ns/1ps
// Logica combinacional. El propietario de todos los registros es word_engine.
// Caracter 0 en [7:0]; posiciones fuera de word_length no participan.
module letter_evaluator (
    input  logic [7:0]  letter_ascii,
    input  logic [95:0] secret_word,
    input  logic [3:0]  word_length,
    input  logic [25:0] used_letters,
    input  logic [95:0] revealed_word,
    output logic        valid_ascii,
    output logic        correct,
    output logic        repeated,
    output logic [25:0] next_used_letters,
    output logic [95:0] next_revealed_word,
    output logic        complete
);
    integer letter_index;
    integer position;

    always_comb begin
        valid_ascii = (letter_ascii >= 8'h41) && (letter_ascii <= 8'h5A);
        letter_index = 0;
        correct = 1'b0;
        repeated = 1'b0;
        next_used_letters = used_letters;
        next_revealed_word = revealed_word;

        if (valid_ascii) begin
            letter_index = int'(letter_ascii) - 65;
            repeated = used_letters[letter_index];
            if (!repeated) begin
                next_used_letters[letter_index] = 1'b1;
                for (position = 0; position < 12; position = position + 1) begin
                    if ((position < word_length) &&
                        (secret_word[8*position +: 8] == letter_ascii)) begin
                        next_revealed_word[8*position +: 8] = letter_ascii;
                        correct = 1'b1;
                    end
                end
            end
        end

        complete = (word_length >= 4) && (word_length <= 12);
        for (position = 0; position < 12; position = position + 1) begin
            if ((position < word_length) &&
                (next_revealed_word[8*position +: 8] != secret_word[8*position +: 8]))
                complete = 1'b0;
        end
    end
endmodule
