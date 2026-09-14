module game_datapath #(
    parameter logic [2:0] MAX_ATTEMPTS = 3'd6,
    parameter logic [6:0] MAX_WINS     = 7'd99
)(
    input  logic        clk_i,
    input  logic        rst_sync,

    // ------------------------------------------------------------
    // Señales de control provenientes de la FSM
    // ------------------------------------------------------------
    input  logic        toggle_difficulty_i,
    input  logic        load_attempts_i,
    input  logic        dec_attempts_i,
    input  logic        inc_wins_i,
    input  logic        capture_letter_i,
    input  logic        capture_word_i,

    // ------------------------------------------------------------
    // Datos provenientes de UART / Word Engine
    // ------------------------------------------------------------
    input  logic [7:0]  rx_letter_i,
    input  logic [3:0]  word_length_i,
    input  logic [95:0] revealed_word_i,

    // ------------------------------------------------------------
    // Registros del juego
    // ------------------------------------------------------------
    output logic        difficulty_o,
    output logic [2:0]  attempts_left_o,
    output logic [6:0]  wins_o,
    output logic [7:0]  letter_ascii_o,
    output logic [3:0]  word_length_o,
    output logic [95:0] revealed_word_o
);

    // ============================================================
    // DIFICULTAD
    // 0 = FACIL
    // 1 = DIFICIL
    // ============================================================
    always_ff @(posedge clk_i or posedge rst_sync) begin
        if (rst_sync) begin
            difficulty_o <= 1'b0;
        end
        else if (toggle_difficulty_i) begin
            difficulty_o <= ~difficulty_o;
        end
    end


    // ============================================================
    // INTENTOS RESTANTES
    // ============================================================
    always_ff @(posedge clk_i or posedge rst_sync) begin
        if (rst_sync) begin
            attempts_left_o <= 3'd0;
        end
        else if (load_attempts_i) begin
            attempts_left_o <= MAX_ATTEMPTS;
        end
        else if (dec_attempts_i) begin
            if (attempts_left_o != 3'd0)
                attempts_left_o <= attempts_left_o - 1'b1;
        end
    end


    // ============================================================
    // CONTADOR ACUMULADO DE VICTORIAS
    // Saturación en 99.
    // ============================================================
    always_ff @(posedge clk_i or posedge rst_sync) begin
        if (rst_sync) begin
            wins_o <= 7'd0;
        end
        else if (inc_wins_i) begin
            if (wins_o < MAX_WINS)
                wins_o <= wins_o + 1'b1;
        end
    end


    // ============================================================
    // REGISTRO DE LETRA ACEPTADA
    // Mantiene estable la letra mientras Word Engine la procesa.
    // ============================================================
    always_ff @(posedge clk_i or posedge rst_sync) begin
        if (rst_sync) begin
            letter_ascii_o <= 8'h00;
        end
        else if (capture_letter_i) begin
            letter_ascii_o <= rx_letter_i;
        end
    end


    // ============================================================
    // INFORMACIÓN DE LA PALABRA
    // Se captura cuando Word Engine indica información válida.
    // ============================================================
    always_ff @(posedge clk_i or posedge rst_sync) begin
        if (rst_sync) begin
            word_length_o   <= 4'd0;
            revealed_word_o <= 96'd0;
        end
        else if (capture_word_i) begin
            word_length_o   <= word_length_i;
            revealed_word_o <= revealed_word_i;
        end
    end

endmodule