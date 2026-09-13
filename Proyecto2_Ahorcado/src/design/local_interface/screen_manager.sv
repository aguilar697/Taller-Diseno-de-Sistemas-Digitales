`timescale 1ns/1ps
module screen_manager #(
    parameter int unsigned LCD_COLS = 16
) (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic [2:0]  game_state_i,
    input  logic        difficulty_i,
    input  logic [2:0]  attempts_left_i,
    input  logic        game_won_i,
    input  logic [95:0] revealed_word_i,
    input  logic [3:0]  word_length_i,
    input  logic [31:0] lcd_rdata_i,
    output logic        lcd_we_o,
    output logic [1:0]  lcd_addr_o,
    output logic [31:0] lcd_wdata_o,
    output logic        lcd_ready_o,
    output logic        lcd_busy_o,
    output logic        screen_done_o
);

  // ------------------------------------------------------------------
  // Codificacion externa real de game_state, definida por el Subsistema 1
  // (game_fsm.sv). Contrato externo: NO modificar estos valores aqui.
  // ------------------------------------------------------------------
  localparam logic [2:0] GS_MODE_SELECT   = 3'd0;
  localparam logic [2:0] GS_STARTING      = 3'd1;
  localparam logic [2:0] GS_ACTIVE        = 3'd2;
  localparam logic [2:0] GS_WIN           = 3'd3;
  localparam logic [2:0] GS_LOSE_ATTEMPTS = 3'd4;
  localparam logic [2:0] GS_LOSE_TIME     = 3'd5;

  // ------------------------------------------------------------------
  // Categorias internas de pantalla (adaptacion propia del Subsistema 4).
  // GS_STARTING se agrupa con GS_ACTIVE: ambos muestran la pantalla de
  // partida (la palabra puede estar aun en blanco durante GS_STARTING,
  // mientras el Word Engine entrega revealed_word_i).
  // ------------------------------------------------------------------
  typedef enum logic [1:0] {
    CAT_SELECT,
    CAT_PLAYING,
    CAT_RESULT
  } scr_category_e;

  function automatic scr_category_e state_category(input logic [2:0] gs);
    case (gs)
      GS_MODE_SELECT:                 state_category = CAT_SELECT;
      GS_STARTING, GS_ACTIVE:         state_category = CAT_PLAYING;
      GS_WIN, GS_LOSE_ATTEMPTS,
      GS_LOSE_TIME:                   state_category = CAT_RESULT;
      default:                        state_category = CAT_SELECT;
    endcase
  endfunction

  localparam logic [7:0] CH_SPACE = 8'h20;
  localparam logic [7:0] CH_EXCL  = 8'h21;
  localparam logic [7:0] CH_COLON = 8'h3A;
  localparam logic [7:0] CH_ZERO  = 8'h30;

  localparam logic [7:0] DDRAM_LINE1 = 8'h80;
  localparam logic [7:0] DDRAM_LINE2 = 8'hC0;

  typedef enum logic [2:0] {
    S_WAIT_READY,
    S_IDLE,
    S_SEND_CMD_LINE1,
    S_SEND_CHARS_LINE1,
    S_SEND_CMD_LINE2,
    S_SEND_CHARS_LINE2,
    S_SCREEN_DONE
  } scr_state_e;

  scr_state_e state;

  typedef enum logic [1:0] {
    WP_DATA,
    WP_CMD,
    WP_RISE,
    WP_FALL
  } wr_phase_e;

  wr_phase_e wr_phase;

  logic lcd_busy_flag;
  assign lcd_busy_flag = lcd_rdata_i[8];

  logic init_seen;
  logic [4:0] char_idx;

  logic [2:0]  snap_state;
  logic        snap_difficulty;
  logic [2:0]  snap_attempts;
  logic        snap_won;
  logic [95:0] snap_word;
  logic [3:0]  snap_length;

  scr_category_e snap_category;
  assign snap_category = state_category(snap_state);

  logic inputs_changed;
  assign inputs_changed = (snap_state      != game_state_i)    ||
                          (snap_difficulty != difficulty_i)    ||
                          (snap_attempts   != attempts_left_i) ||
                          (snap_won        != game_won_i)      ||
                          (snap_word       != revealed_word_i) ||
                          (snap_length     != word_length_i);

  function automatic logic [7:0] word_char(input logic [95:0] w, input logic [3:0] idx);
    logic [95:0] shifted;
    begin
      shifted   = w >> ({4'b0, idx} * 8);
      word_char = shifted[7:0];
    end
  endfunction

  function automatic logic [7:0] mode_line1(input logic [4:0] idx, input logic diff);
    case (idx)
      5'd0:  mode_line1 = 8'h4D;
      5'd1:  mode_line1 = 8'h4F;
      5'd2:  mode_line1 = 8'h44;
      5'd3:  mode_line1 = 8'h4F;
      5'd4:  mode_line1 = CH_COLON;
      5'd5:  mode_line1 = CH_SPACE;
      5'd6:  mode_line1 = diff ? 8'h44 : 8'h46;
      5'd7:  mode_line1 = diff ? 8'h49 : 8'h41;
      5'd8:  mode_line1 = diff ? 8'h46 : 8'h43;
      5'd9:  mode_line1 = diff ? 8'h49 : 8'h49;
      5'd10: mode_line1 = diff ? 8'h43 : 8'h4C;
      5'd11: mode_line1 = diff ? 8'h49 : CH_SPACE;
      5'd12: mode_line1 = diff ? 8'h4C : CH_SPACE;
      default: mode_line1 = CH_SPACE;
    endcase
  endfunction

  function automatic logic [7:0] mode_line2(input logic [4:0] idx);
    case (idx)
      5'd0:  mode_line2 = 8'h53;
      5'd1:  mode_line2 = 8'h45;
      5'd2:  mode_line2 = 8'h4C;
      5'd3:  mode_line2 = 8'h3D;
      5'd4:  mode_line2 = 8'h4D;
      5'd5:  mode_line2 = 8'h4F;
      5'd6:  mode_line2 = 8'h44;
      5'd7:  mode_line2 = 8'h4F;
      5'd8:  mode_line2 = CH_SPACE;
      5'd9:  mode_line2 = 8'h4F;
      5'd10: mode_line2 = 8'h4B;
      5'd11: mode_line2 = 8'h3D;
      5'd12: mode_line2 = 8'h49;
      5'd13: mode_line2 = 8'h52;
      default: mode_line2 = CH_SPACE;
    endcase
  endfunction

  function automatic logic [7:0] attempts_line(input logic [4:0] idx, input logic [2:0] att);
    case (idx)
      5'd0:  attempts_line = 8'h49;
      5'd1:  attempts_line = 8'h4E;
      5'd2:  attempts_line = 8'h54;
      5'd3:  attempts_line = 8'h45;
      5'd4:  attempts_line = 8'h4E;
      5'd5:  attempts_line = 8'h54;
      5'd6:  attempts_line = 8'h4F;
      5'd7:  attempts_line = 8'h53;
      5'd8:  attempts_line = CH_COLON;
      5'd9:  attempts_line = CH_SPACE;
      5'd10: attempts_line = CH_ZERO + {5'b0, att};
      default: attempts_line = CH_SPACE;
    endcase
  endfunction

  function automatic logic [7:0] result_line(input logic [4:0] idx, input logic won);
    case (idx)
      5'd0: result_line = won ? 8'h47 : 8'h50;
      5'd1: result_line = won ? 8'h41 : 8'h45;
      5'd2: result_line = won ? 8'h4E : 8'h52;
      5'd3: result_line = won ? 8'h41 : 8'h44;
      5'd4: result_line = won ? 8'h53 : 8'h49;
      5'd5: result_line = won ? 8'h54 : 8'h53;
      5'd6: result_line = won ? 8'h45 : 8'h54;
      5'd7: result_line = won ? CH_EXCL : 8'h45;
      default: result_line = CH_SPACE;
    endcase
  endfunction

  logic [7:0] char_line1, char_line2;
  logic [3:0] char_idx_low;
  logic [7:0] cur_word_char;
  logic       idx_in_word;

  assign char_idx_low  = char_idx[3:0];
  assign cur_word_char = word_char(snap_word, char_idx_low);
  assign idx_in_word   = (char_idx < {1'b0, snap_length});

  always_comb begin
    unique case (snap_category)
      CAT_SELECT:  char_line1 = mode_line1(char_idx, snap_difficulty);
      CAT_PLAYING: char_line1 = idx_in_word ? cur_word_char : CH_SPACE;
      CAT_RESULT:  char_line1 = result_line(char_idx, snap_won);
      default:     char_line1 = CH_SPACE;
    endcase
  end

  always_comb begin
    unique case (snap_category)
      CAT_SELECT:  char_line2 = mode_line2(char_idx);
      CAT_PLAYING: char_line2 = attempts_line(char_idx, snap_attempts);
      CAT_RESULT:  char_line2 = idx_in_word ? cur_word_char : CH_SPACE;
      default:     char_line2 = CH_SPACE;
    endcase
  end

  logic [7:0] byte_to_send;
  logic       rs_to_send;

  always_comb begin
    unique case (state)
      S_SEND_CMD_LINE1:   begin byte_to_send = DDRAM_LINE1; rs_to_send = 1'b0; end
      S_SEND_CHARS_LINE1: begin byte_to_send = char_line1;  rs_to_send = 1'b1; end
      S_SEND_CMD_LINE2:   begin byte_to_send = DDRAM_LINE2; rs_to_send = 1'b0; end
      S_SEND_CHARS_LINE2: begin byte_to_send = char_line2;  rs_to_send = 1'b1; end
      default:            begin byte_to_send = CH_SPACE;    rs_to_send = 1'b0; end
    endcase
  end

  // ------------------------------------------------------------------
  // Envio de un byte al periferico LCD en 4 fases explicitas:
  //   WP_DATA -> escribe el registro DATOS (addr=01)
  //   WP_CMD  -> escribe CONTROL/ESTADO con start+rs (addr=00)
  //   WP_RISE -> espera a que busy suba a 1 (confirma que el periferico
  //              realmente comenzo, evitando leer busy en el mismo ciclo
  //              en que se dispara start, cuando aun no pudo reflejarse)
  //   WP_FALL -> espera a que busy vuelva a 0 (transaccion terminada)
  // Ambas fases de espera mantienen addr_o=00, de modo que la lectura de
  // busy nunca queda enmascarada por una escritura pendiente a DATOS.
  // ------------------------------------------------------------------
  always_ff @(posedge clk_i) begin
    if (rst_i) begin
      state           <= S_WAIT_READY;
      wr_phase        <= WP_DATA;
      char_idx        <= '0;
      init_seen       <= 1'b0;
      lcd_we_o        <= 1'b0;
      lcd_addr_o      <= 2'b00;
      lcd_wdata_o     <= 32'h0;
      screen_done_o   <= 1'b0;
      snap_state      <= 3'b111;
      snap_difficulty <= 1'b0;
      snap_attempts   <= 3'b0;
      snap_won        <= 1'b0;
      snap_word       <= '0;
      snap_length     <= 4'b0;
    end else begin
      lcd_we_o      <= 1'b0;
      screen_done_o <= 1'b0;

      unique case (state)

        S_WAIT_READY: begin
          if (!lcd_busy_flag) begin
            init_seen <= 1'b1;
            state     <= S_IDLE;
          end
        end

        S_IDLE: begin
          if (inputs_changed && !lcd_busy_flag) begin
            snap_state      <= game_state_i;
            snap_difficulty <= difficulty_i;
            snap_attempts   <= attempts_left_i;
            snap_won        <= game_won_i;
            snap_word       <= revealed_word_i;
            snap_length     <= word_length_i;
            char_idx        <= '0;
            wr_phase        <= WP_DATA;
            state           <= S_SEND_CMD_LINE1;
          end
        end

        S_SEND_CMD_LINE1, S_SEND_CHARS_LINE1, S_SEND_CMD_LINE2, S_SEND_CHARS_LINE2: begin
          unique case (wr_phase)

            WP_DATA: begin
              lcd_addr_o  <= 2'b01;
              lcd_wdata_o <= {24'b0, byte_to_send};
              lcd_we_o    <= 1'b1;
              wr_phase    <= WP_CMD;
            end

            WP_CMD: begin
              lcd_addr_o  <= 2'b00;
              lcd_wdata_o <= {28'b0, rs_to_send, 1'b1};
              lcd_we_o    <= 1'b1;
              wr_phase    <= WP_RISE;
            end

            WP_RISE: begin
              if (lcd_busy_flag)
                wr_phase <= WP_FALL;
            end

            WP_FALL: begin
              if (!lcd_busy_flag) begin
                unique case (state)

                  S_SEND_CMD_LINE1: begin
                    char_idx <= '0;
                    wr_phase <= WP_DATA;
                    state    <= S_SEND_CHARS_LINE1;
                  end

                  S_SEND_CHARS_LINE1: begin
                    if (char_idx == 5'(LCD_COLS - 1)) begin
                      char_idx <= '0;
                      wr_phase <= WP_DATA;
                      state    <= S_SEND_CMD_LINE2;
                    end else begin
                      char_idx <= char_idx + 1'b1;
                      wr_phase <= WP_DATA;
                    end
                  end

                  S_SEND_CMD_LINE2: begin
                    char_idx <= '0;
                    wr_phase <= WP_DATA;
                    state    <= S_SEND_CHARS_LINE2;
                  end

                  S_SEND_CHARS_LINE2: begin
                    if (char_idx == 5'(LCD_COLS - 1)) begin
                      state <= S_SCREEN_DONE;
                    end else begin
                      char_idx <= char_idx + 1'b1;
                      wr_phase <= WP_DATA;
                    end
                  end

                  default: state <= S_IDLE;
                endcase
              end
            end

            default: wr_phase <= WP_DATA;
          endcase
        end

        S_SCREEN_DONE: begin
          screen_done_o <= 1'b1;
          state         <= S_IDLE;
        end

        default: state <= S_WAIT_READY;

      endcase
    end
  end

  assign lcd_ready_o = init_seen;
  assign lcd_busy_o  = (state != S_IDLE) || lcd_busy_flag;

endmodule
