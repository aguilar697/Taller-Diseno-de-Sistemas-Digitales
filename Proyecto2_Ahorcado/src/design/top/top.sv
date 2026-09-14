`timescale 1ns/1ps

module top (
    input  logic        clk_i,          // Reloj principal del sistema (100 MHz)
    input  logic        btn_rst_i,      // Botón de reset
    input  logic        btn_sel_i,      // Botón de selección de dificultad / modo
    input  logic        btn_ok_i,       // Botón OK / confirmar

    // Interfaz UART Física
    input  logic        uart_rx_i,      // Línea de recepción UART
    output logic        uart_tx_o,      // Línea de transmisión UART

    // Interfaz LCD
    output logic [7:0]  lcd_db_o,       // Data bus del LCD
    output logic        lcd_rs_o,       // Register Select
    output logic        lcd_rw_o,       // Read/Write
    output logic        lcd_e_o,        // Enable

    // Display de 7 Segmentos
    output logic [6:0]  seg_o,          // Segmentos (a-g)
    output logic [3:0]  an_o,           // Ánodos

    // LEDs de Estado
    output logic [1:0]  led_estado_o,   // LEDs indicadores de estado

    // Zumbador (Buzzer)
    output logic        buzzer_o        // Salida de audio/pulso
);

    // =========================================================================
    // PARÁMETROS GLOBALES
    // =========================================================================
    parameter int unsigned CLK_HZ              = 100_000_000;
    parameter int unsigned DEBOUNCE_CYCLES     = 2_000_000;
    parameter int unsigned EASY_SECONDS        = 60;
    parameter int unsigned HARD_SECONDS        = 45;
    parameter int unsigned RESULT_HOLD_SECONDS = 3;

   
 
    localparam logic [2:0] EVENT_START         = 3'd0;
    localparam logic [2:0] EVENT_HIT           = 3'd1;
    localparam logic [2:0] EVENT_MISS          = 3'd2;
    
    localparam logic [2:0] EVENT_WIN           = 3'd4;
    localparam logic [2:0] EVENT_LOSE_ATTEMPTS = 3'd5;
    localparam logic [2:0] EVENT_LOSE_TIME     = 3'd6;

   
    localparam logic [2:0] GS_STARTING      = 3'd1;
    localparam logic [2:0] GS_ACTIVE        = 3'd2;
    localparam logic [2:0] GS_WIN           = 3'd3;
    localparam logic [2:0] GS_LOSE_ATTEMPTS = 3'd4;
    localparam logic [2:0] GS_LOSE_TIME     = 3'd5;

    logic rst_sync_top;

    reset_sync u_reset_sync_top (
        .clk_i     (clk_i),
        .btn_rst_i (btn_rst_i),
        .rst_sync  (rst_sync_top)
    );

    // =========================================================================
    // SEÑALES DE INTERCONEXIÓN ENTRE SUBSISTEMAS
    // =========================================================================

    // UART y Protocolo -> Control
    logic        rx_letter_valid_s;
    logic [7:0]  rx_letter_s;

    // Control -> Word Engine
    logic        new_game_s;
    logic        difficulty_s;
    logic        letter_valid_s;
    logic [7:0]  letter_ascii_s;

    // Word Engine -> Control (palabra "cruda" que entrega el motor;

    logic        word_ready_s;
    logic [3:0]  word_length_from_engine_s;
    logic [95:0] revealed_word_from_engine_s;
    logic        letter_correct_s;
    logic        letter_repeated_s;
    logic        word_complete_s;

    // Control -> Interfaz Local / UART TX (copia pública que
    // game_control_top reexporta de su propio datapath interno)
    logic [2:0]  game_state_s;
    logic [95:0] revealed_word_s;
    logic [3:0]  word_length_s;
    logic [2:0]  attempts_left_s;
    logic [6:0]  time_remaining_s;
    logic [6:0]  wins_s;
    logic        correct_pulse_s;
    logic        wrong_pulse_s;
    logic        game_over_pulse_s;
    logic        game_won_s;

   
    logic        lcd_ready_s;
    logic        lcd_busy_s;
    logic        screen_done_s;
    logic        buzzer_busy_s;


    logic        event_valid_s;
    logic [2:0]  event_type_s;
    logic        event_ready_s;

    logic        event_difficulty_s;
    logic [3:0]  event_word_length_s;
    logic [2:0]  event_attempts_left_s;
    logic [95:0] event_revealed_word_s;
    logic [95:0] event_final_word_s;

    // =========================================================================
    // 1. SUBSISTEMA DE COMUNICACIÓN UART Y PROTOCOLO
    // =========================================================================
    uart_protocol_top u_uart_protocol_top (
        .clk_i           (clk_i),
        .rst_i           (rst_sync_top),

        // Letra recibida -> Control
        .letter_o        (rx_letter_s),
        .letter_valid_o  (rx_letter_valid_s),

        // Eventos de juego -> UART TX 
        .event_valid_i   (event_valid_s),
        .event_type_i    (event_type_s),
        .difficulty_i    (event_difficulty_s),
        .word_length_i   (event_word_length_s),
        .attempts_left_i (event_attempts_left_s),
        .revealed_word_i (event_revealed_word_s),
        .final_word_i    (event_final_word_s),
        .event_ready_o   (event_ready_s),

        // Líneas físicas UART
        .rx_i            (uart_rx_i),
        .tx_o            (uart_tx_o)
    );

    // =========================================================================
    // 2. SUBSISTEMA DE CONTROL DEL JUEGO (GAME CONTROL TOP)
    // =========================================================================
    game_control_top #(
        .CLK_HZ              (CLK_HZ),
        .EASY_SECONDS        (EASY_SECONDS),
        .HARD_SECONDS        (HARD_SECONDS),
        .RESULT_HOLD_SECONDS (RESULT_HOLD_SECONDS),
        .DEBOUNCE_CYCLES     (DEBOUNCE_CYCLES)
    ) u_game_control_top (
        .clk_i               (clk_i),
        .btn_sel_i           (btn_sel_i),
        .btn_ok_i            (btn_ok_i),
        .btn_rst_i           (btn_rst_i),

        // UART RX entrante
        .rx_letter_valid_i   (rx_letter_valid_s),
        .rx_letter_i         (rx_letter_s),

        // Interacción con Word Engine (palabra cruda del motor)
        .word_ready_i        (word_ready_s),
        .word_length_i       (word_length_from_engine_s),
        .revealed_word_i     (revealed_word_from_engine_s),
        .letter_correct_i    (letter_correct_s),
        .letter_repeated_i   (letter_repeated_s),
        .word_complete_i     (word_complete_s),

        .new_game_o          (new_game_s),
        .difficulty_o        (difficulty_s),
        .letter_valid_o      (letter_valid_s),
        .letter_ascii_o      (letter_ascii_s),

        // Salidas de estado e indicadores públicos (copia reexportada)
        .game_state_o        (game_state_s),
        .revealed_word_o     (revealed_word_s),
        .word_length_o       (word_length_s),
        .attempts_left_o     (attempts_left_s),
        .time_remaining_o    (time_remaining_s),
        .wins_o              (wins_s),

        .correct_pulse_o     (correct_pulse_s),
        .wrong_pulse_o       (wrong_pulse_s),
        .game_over_pulse_o   (game_over_pulse_s),
        .game_won_o          (game_won_s)
    );

    // =========================================================================
    // 3. SUBSISTEMA DE INTERFAZ LOCAL (LCD, 7 SEGMENTOS, LEDS, BUZZER)
    // =========================================================================
    local_interface u_local_interface (
        .clk_i             (clk_i),
        .rst_i             (rst_sync_top),

        .game_state_i      (game_state_s),
        .difficulty_i      (difficulty_s),
        .attempts_left_i   (attempts_left_s),
        .time_remaining_i  (time_remaining_s),
        .wins_i            (wins_s),
        .game_won_i        (game_won_s),
        .correct_pulse_i   (correct_pulse_s),
        .wrong_pulse_i     (wrong_pulse_s),
        .game_over_pulse_i (game_over_pulse_s),

        .revealed_word_i   (revealed_word_s),
        .word_length_i     (word_length_s),

        .lcd_ready_o       (lcd_ready_s),
        .lcd_busy_o        (lcd_busy_s),
        .screen_done_o     (screen_done_s),
        .buzzer_busy_o     (buzzer_busy_s),

        // Puertos físicos externos
        .lcd_db_o          (lcd_db_o),
        .lcd_rs_o          (lcd_rs_o),
        .lcd_rw_o          (lcd_rw_o),
        .lcd_e_o           (lcd_e_o),
        .seg_o             (seg_o),
        .an_o              (an_o),
        .led_estado_o      (led_estado_o),
        .buzzer_o          (buzzer_o)
    );

    // =========================================================================
    // 4. WORD ENGINE
    // =========================================================================
    word_engine u_word_engine (
        .clk            (clk_i),
        .reset          (rst_sync_top),
        .new_game       (new_game_s),
        .difficulty     (difficulty_s),
        .letter_valid   (letter_valid_s),
        .letter_ascii   (letter_ascii_s),
        .word_ready     (word_ready_s),
        .word_length    (word_length_from_engine_s),
        .revealed_word  (revealed_word_from_engine_s),
        .letter_correct (letter_correct_s),
        .letter_repeated(letter_repeated_s),
        .word_complete  (word_complete_s)
    );

    logic [2:0] game_state_d1_s;
    logic       correct_pulse_d1_s;
    logic       wrong_pulse_d1_s;
    logic       game_over_pulse_d1_s;

    always_ff @(posedge clk_i) begin
        if (rst_sync_top) begin
            game_state_d1_s      <= '0;
            correct_pulse_d1_s   <= 1'b0;
            wrong_pulse_d1_s     <= 1'b0;
            game_over_pulse_d1_s <= 1'b0;
        end else begin
            game_state_d1_s      <= game_state_s;
            correct_pulse_d1_s   <= correct_pulse_s;
            wrong_pulse_d1_s     <= wrong_pulse_s;
            game_over_pulse_d1_s <= game_over_pulse_s;
        end
    end

    logic       start_trigger_s;
    logic       new_event_pulse_s;
    logic [2:0] new_event_type_s;

    assign start_trigger_s = (game_state_d1_s == GS_STARTING) &&
                              (game_state_s   == GS_ACTIVE);

    always_comb begin
        new_event_pulse_s = 1'b0;
        new_event_type_s  = EVENT_HIT;

        
        if (game_over_pulse_d1_s) begin
            new_event_pulse_s = 1'b1;
            unique case (game_state_s)
                GS_WIN:           new_event_type_s = EVENT_WIN;
                GS_LOSE_ATTEMPTS: new_event_type_s = EVENT_LOSE_ATTEMPTS;
                GS_LOSE_TIME:     new_event_type_s = EVENT_LOSE_TIME;
                default:          new_event_pulse_s = 1'b0;
            endcase
        end else if (start_trigger_s) begin
            new_event_pulse_s = 1'b1;
            new_event_type_s  = EVENT_START;
        end else if (correct_pulse_d1_s) begin
            new_event_pulse_s = 1'b1;
            new_event_type_s  = EVENT_HIT;
        end else if (wrong_pulse_d1_s) begin
            new_event_pulse_s = 1'b1;
            new_event_type_s  = EVENT_MISS;
        end
    end

    
    always_ff @(posedge clk_i) begin
        if (rst_sync_top) begin
            event_valid_s <= 1'b0;
            event_type_s  <= EVENT_START;
        end else if (event_valid_s && event_ready_s) begin
            event_valid_s <= 1'b0;
        end else if (new_event_pulse_s && !event_valid_s) begin
            event_valid_s          <= 1'b1;
            event_type_s           <= new_event_type_s;
            event_difficulty_s     <= difficulty_s;
            event_word_length_s    <= word_length_s;
            event_attempts_left_s  <= attempts_left_s;
            event_revealed_word_s  <= revealed_word_s;
            event_final_word_s     <= revealed_word_s;
        end
    end

endmodule
