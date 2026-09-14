module game_fsm (
    input  logic       clk_i,
    input  logic       rst_sync,

    // Botones acondicionados
    input  logic       btn_sel_pulse_i,
    input  logic       btn_ok_pulse_i,

    // UART
    input  logic       rx_letter_valid_i,
    input  logic [7:0] rx_letter_i,

    // Word Engine
    input  logic       word_ready_i,
    input  logic       letter_correct_i,
    input  logic       letter_repeated_i,
    input  logic       word_complete_i,

    // Datapath / temporizadores
    input  logic [2:0] attempts_left_i,
    input  logic       time_expired_i,
    input  logic       result_hold_done_i,

    // Control hacia datapath
    output logic       toggle_difficulty_o,
    output logic       load_attempts_o,
    output logic       dec_attempts_o,
    output logic       inc_wins_o,
    output logic       capture_letter_o,
    output logic       capture_word_o,

    // Control hacia countdown_timer
    output logic       timer_load_o,
    output logic       timer_enable_o,

    // Control hacia result_hold_timer
    output logic       result_timer_start_o,

    // Control hacia Word Engine
    output logic       new_game_o,
    output logic       letter_valid_o,

    // Estado/eventos públicos
    output logic [2:0] game_state_o,
    output logic       correct_pulse_o,
    output logic       wrong_pulse_o,
    output logic       game_over_pulse_o,
    output logic       game_won_o
);

    // ============================================================
    // ESTADOS PÚBLICOS
    // ============================================================
    localparam logic [2:0] GS_MODE_SELECT       = 3'd0;
    localparam logic [2:0] GS_STARTING          = 3'd1;
    localparam logic [2:0] GS_ACTIVE            = 3'd2;
    localparam logic [2:0] GS_WIN               = 3'd3;
    localparam logic [2:0] GS_LOSE_ATTEMPTS     = 3'd4;
    localparam logic [2:0] GS_LOSE_TIME         = 3'd5;

    // ============================================================
    // ESTADOS INTERNOS DE LA FSM
    // ============================================================
    typedef enum logic [3:0] {
        MODE_SELECT,
        REQUEST_WORD,
        WAIT_WORD,
        INIT_GAME,
        WAIT_LETTER,
        ISSUE_LETTER,
        CHECK_LETTER,
        RESULT_WIN,
        RESULT_LOSE_ATTEMPTS,
        RESULT_LOSE_TIME
    } state_t;

    state_t state_q;
    state_t state_d;


    // ============================================================
    // VALIDACIÓN ASCII
    // Solo se aceptan letras 'A' ... 'Z'
    // ============================================================
    function automatic logic is_valid_letter(
        input logic [7:0] ascii
    );
        begin
            is_valid_letter =
                (ascii >= 8'h41) &&
                (ascii <= 8'h5A);
        end
    endfunction


    // ============================================================
    // REGISTRO DE ESTADO
    // ============================================================
    always_ff @(posedge clk_i or posedge rst_sync) begin
        if (rst_sync)
            state_q <= MODE_SELECT;
        else
            state_q <= state_d;
    end


    // ============================================================
    // LÓGICA DE PRÓXIMO ESTADO Y SALIDAS
    // ============================================================
    always_comb begin

        // --------------------------------------------------------
        // Valores por defecto
        // --------------------------------------------------------
        state_d = state_q;

        toggle_difficulty_o = 1'b0;
        load_attempts_o     = 1'b0;
        dec_attempts_o      = 1'b0;
        inc_wins_o          = 1'b0;
        capture_letter_o    = 1'b0;
        capture_word_o      = 1'b0;

        timer_load_o         = 1'b0;
        timer_enable_o       = 1'b0;

        result_timer_start_o = 1'b0;

        new_game_o           = 1'b0;
        letter_valid_o       = 1'b0;

        correct_pulse_o      = 1'b0;
        wrong_pulse_o        = 1'b0;
        game_over_pulse_o    = 1'b0;
        game_won_o           = 1'b0;

        game_state_o         = GS_MODE_SELECT;


        case (state_q)

            // ====================================================
            // SELECCIÓN DE MODO
            // ====================================================
            MODE_SELECT: begin

                game_state_o = GS_MODE_SELECT;

                if (btn_sel_pulse_i)
                    toggle_difficulty_o = 1'b1;

                if (btn_ok_pulse_i)
                    state_d = REQUEST_WORD;
            end


            // ====================================================
            // SOLICITUD DE NUEVA PALABRA
            // ====================================================
            REQUEST_WORD: begin

                game_state_o = GS_STARTING;

                new_game_o = 1'b1;

                state_d = WAIT_WORD;
            end


            // ====================================================
            // ESPERA A WORD ENGINE
            // ====================================================
            WAIT_WORD: begin

                game_state_o = GS_STARTING;

                if (word_ready_i) begin
                    capture_word_o = 1'b1;
                    state_d        = INIT_GAME;
                end
            end


            // ====================================================
            // INICIALIZACIÓN DE PARTIDA
            // ====================================================
            INIT_GAME: begin

                game_state_o = GS_STARTING;

                load_attempts_o = 1'b1;
                timer_load_o    = 1'b1;

                state_d = WAIT_LETTER;
            end


            // ====================================================
            // ESPERA DE LETRA DESDE UART
            // ====================================================
            WAIT_LETTER: begin

                game_state_o   = GS_ACTIVE;
                timer_enable_o = 1'b1;

                // Tiempo tiene prioridad sobre una letra nueva.
                if (time_expired_i) begin

                    result_timer_start_o = 1'b1;
                    game_over_pulse_o    = 1'b1;

                    state_d = RESULT_LOSE_TIME;
                end

                else if (
                    rx_letter_valid_i &&
                    is_valid_letter(rx_letter_i)
                ) begin

                    capture_letter_o = 1'b1;

                    state_d = ISSUE_LETTER;
                end
            end


            // ====================================================
            // ENVÍO DE LETRA AL WORD ENGINE
            // ====================================================
            ISSUE_LETTER: begin

                game_state_o   = GS_ACTIVE;
                timer_enable_o = 1'b1;

                // Pulso de exactamente un ciclo.
                letter_valid_o = 1'b1;

                state_d = CHECK_LETTER;
            end


            // ====================================================
            // EVALUACIÓN DE RESPUESTA DEL WORD ENGINE
            // ====================================================
            CHECK_LETTER: begin

                game_state_o   = GS_ACTIVE;
                timer_enable_o = 1'b1;

                // Actualizar representación de la palabra.
                capture_word_o = 1'b1;


                // ------------------------------------------------
                // PRIORIDAD 1: VICTORIA
                // ------------------------------------------------
                if (word_complete_i) begin

                    if (!letter_repeated_i)
                        correct_pulse_o = 1'b1;

                    inc_wins_o          = 1'b1;
                    result_timer_start_o = 1'b1;
                    game_over_pulse_o    = 1'b1;

                    state_d = RESULT_WIN;
                end


                // ------------------------------------------------
                // PRIORIDAD 2: LETRA INCORRECTA
                // ------------------------------------------------
                else if (
                    !letter_correct_i &&
                    !letter_repeated_i
                ) begin

                    wrong_pulse_o   = 1'b1;
                    dec_attempts_o  = 1'b1;

                    // Último intento disponible.
                    if (attempts_left_i == 3'd1) begin

                        result_timer_start_o = 1'b1;
                        game_over_pulse_o    = 1'b1;

                        state_d = RESULT_LOSE_ATTEMPTS;
                    end

                    // El tiempo puede vencer simultáneamente.
                    else if (time_expired_i) begin

                        result_timer_start_o = 1'b1;
                        game_over_pulse_o    = 1'b1;

                        state_d = RESULT_LOSE_TIME;
                    end

                    else begin
                        state_d = WAIT_LETTER;
                    end
                end


                // ------------------------------------------------
                // PRIORIDAD 3: LETRA CORRECTA
                // ------------------------------------------------
                else if (
                    letter_correct_i &&
                    !letter_repeated_i
                ) begin

                    correct_pulse_o = 1'b1;

                    if (time_expired_i) begin

                        result_timer_start_o = 1'b1;
                        game_over_pulse_o    = 1'b1;

                        state_d = RESULT_LOSE_TIME;
                    end
                    else begin
                        state_d = WAIT_LETTER;
                    end
                end


                // ------------------------------------------------
                // LETRA REPETIDA
                // No consume intento.
                // ------------------------------------------------
                else begin

                    if (time_expired_i) begin

                        result_timer_start_o = 1'b1;
                        game_over_pulse_o    = 1'b1;

                        state_d = RESULT_LOSE_TIME;
                    end
                    else begin
                        state_d = WAIT_LETTER;
                    end
                end
            end


            // ====================================================
            // RESULTADO: VICTORIA
            // ====================================================
            RESULT_WIN: begin

                game_state_o = GS_WIN;
                game_won_o   = 1'b1;

                if (result_hold_done_i)
                    state_d = MODE_SELECT;
            end


            // ====================================================
            // RESULTADO: SIN INTENTOS
            // ====================================================
            RESULT_LOSE_ATTEMPTS: begin

                game_state_o = GS_LOSE_ATTEMPTS;

                if (result_hold_done_i)
                    state_d = MODE_SELECT;
            end


            // ====================================================
            // RESULTADO: SIN TIEMPO
            // ====================================================
            RESULT_LOSE_TIME: begin

                game_state_o = GS_LOSE_TIME;

                if (result_hold_done_i)
                    state_d = MODE_SELECT;
            end


            // ====================================================
            // PROTECCIÓN
            // ====================================================
            default: begin
                state_d = MODE_SELECT;
            end

        endcase
    end

endmodule