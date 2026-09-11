module protocol_tx_controller (
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic        bus_grant_i,

    input  logic        event_valid_i,
    input  logic [2:0]  event_type_i,
    input  logic        difficulty_i,
    input  logic [3:0]  word_length_i,
    input  logic [2:0]  attempts_left_i,
    input  logic [95:0] revealed_word_i,
    input  logic [95:0] final_word_i,
    output logic        event_ready_o,

    output logic        write_enable_o,
    output logic [1:0]  addr_o,
    output logic [31:0] wdata_o,
    input  logic [31:0] rdata_i
);

    localparam logic [1:0] ADDR_TX_DATA = 2'b00;
    localparam logic [1:0] ADDR_CONTROL = 2'b10;

    localparam logic [2:0] EVENT_START         = 3'd0;
    localparam logic [2:0] EVENT_HIT           = 3'd1;
    localparam logic [2:0] EVENT_MISS          = 3'd2;
    localparam logic [2:0] EVENT_REPEAT        = 3'd3;
    localparam logic [2:0] EVENT_WIN           = 3'd4;
    localparam logic [2:0] EVENT_LOSE_ATTEMPTS = 3'd5;
    localparam logic [2:0] EVENT_LOSE_TIME     = 3'd6;
    localparam logic [2:0] EVENT_RESERVED      = 3'd7;

    localparam logic [7:0] ASCII_ZERO = 8'h30;
    localparam logic [7:0] ASCII_COMMA = 8'h2C;
    localparam logic [7:0] ASCII_LF = 8'h0A;

    typedef enum logic [2:0] {
        TX_IDLE,
        TX_BUILD,
        TX_CHECK_SEND,
        TX_WRITE_DATA,
        TX_WRITE_GAP,
        TX_START,
        TX_WAIT_DONE,
        TX_NEXT
    } tx_state_t;

    tx_state_t state;

    logic [7:0] message_buffer [0:31];
    logic [4:0] message_length;
    logic [4:0] message_index;

    logic [2:0]  event_type_reg;
    logic        difficulty_reg;
    logic [3:0]  word_length_reg;
    logic [2:0]  attempts_left_reg;
    logic [95:0] revealed_word_reg;
    logic [95:0] final_word_reg;

    integer character_index;

    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            state               <= TX_IDLE;
            message_length      <= 5'd0;
            message_index       <= 5'd0;
            event_type_reg      <= EVENT_RESERVED;
            difficulty_reg      <= 1'b0;
            word_length_reg     <= 4'd0;
            attempts_left_reg   <= 3'd0;
            revealed_word_reg   <= 96'b0;
            final_word_reg      <= 96'b0;
        end else if (bus_grant_i) begin
            case (state)
                TX_IDLE: begin
                    if (event_valid_i && event_ready_o) begin
                        event_type_reg    <= event_type_i;
                        difficulty_reg    <= difficulty_i;
                        word_length_reg   <= word_length_i;
                        attempts_left_reg <= attempts_left_i;
                        revealed_word_reg <= revealed_word_i;
                        final_word_reg    <= final_word_i;
                        state             <= TX_BUILD;
                    end
                end

                TX_BUILD: begin
                    message_index <= 5'd0;

                    case (event_type_reg)
                        EVENT_START: begin
                            message_buffer[0] <= 8'h53;  // S
                            message_buffer[1] <= 8'h54;  // T
                            message_buffer[2] <= 8'h41;  // A
                            message_buffer[3] <= 8'h52;  // R
                            message_buffer[4] <= 8'h54;  // T
                            message_buffer[5] <= ASCII_COMMA;

                            if (difficulty_reg == 1'b0) begin
                                message_buffer[6] <= 8'h45;  // E
                                message_buffer[7] <= 8'h41;  // A
                                message_buffer[8] <= 8'h53;  // S
                                message_buffer[9] <= 8'h59;  // Y
                            end else begin
                                message_buffer[6] <= 8'h48;  // H
                                message_buffer[7] <= 8'h41;  // A
                                message_buffer[8] <= 8'h52;  // R
                                message_buffer[9] <= 8'h44;  // D
                            end

                            message_buffer[10] <= ASCII_COMMA;

                            if (word_length_reg < 4'd10) begin
                                message_buffer[11] <= ASCII_ZERO + word_length_reg;
                                message_buffer[12] <= ASCII_LF;
                                message_length     <= 5'd13;
                            end else begin
                                message_buffer[11] <= 8'h31;  // 1
                                message_buffer[12] <= ASCII_ZERO
                                                    + (word_length_reg - 4'd10);
                                message_buffer[13] <= ASCII_LF;
                                message_length     <= 5'd14;
                            end

                            state <= TX_CHECK_SEND;
                        end

                        EVENT_HIT: begin
                            message_buffer[0] <= 8'h48;  // H
                            message_buffer[1] <= 8'h49;  // I
                            message_buffer[2] <= 8'h54;  // T
                            message_buffer[3] <= ASCII_COMMA;

                            for (character_index = 0;
                                 character_index < 12;
                                 character_index = character_index + 1) begin
                                if (character_index < word_length_reg) begin
                                    message_buffer[4 + character_index]
                                        <= revealed_word_reg[(8 * character_index) +: 8];
                                end
                            end

                            message_buffer[4 + word_length_reg] <= ASCII_COMMA;
                            message_buffer[5 + word_length_reg]
                                <= ASCII_ZERO + attempts_left_reg;
                            message_buffer[6 + word_length_reg] <= ASCII_LF;
                            message_length <= 5'd7 + word_length_reg;
                            state <= TX_CHECK_SEND;
                        end

                        EVENT_MISS: begin
                            message_buffer[0] <= 8'h4D;  // M
                            message_buffer[1] <= 8'h49;  // I
                            message_buffer[2] <= 8'h53;  // S
                            message_buffer[3] <= 8'h53;  // S
                            message_buffer[4] <= ASCII_COMMA;

                            for (character_index = 0;
                                 character_index < 12;
                                 character_index = character_index + 1) begin
                                if (character_index < word_length_reg) begin
                                    message_buffer[5 + character_index]
                                        <= revealed_word_reg[(8 * character_index) +: 8];
                                end
                            end

                            message_buffer[5 + word_length_reg] <= ASCII_COMMA;
                            message_buffer[6 + word_length_reg]
                                <= ASCII_ZERO + attempts_left_reg;
                            message_buffer[7 + word_length_reg] <= ASCII_LF;
                            message_length <= 5'd8 + word_length_reg;
                            state <= TX_CHECK_SEND;
                        end

                        EVENT_REPEAT: begin
                            message_buffer[0] <= 8'h52;  // R
                            message_buffer[1] <= 8'h45;  // E
                            message_buffer[2] <= 8'h50;  // P
                            message_buffer[3] <= 8'h45;  // E
                            message_buffer[4] <= 8'h41;  // A
                            message_buffer[5] <= 8'h54;  // T
                            message_buffer[6] <= ASCII_COMMA;

                            for (character_index = 0;
                                 character_index < 12;
                                 character_index = character_index + 1) begin
                                if (character_index < word_length_reg) begin
                                    message_buffer[7 + character_index]
                                        <= revealed_word_reg[(8 * character_index) +: 8];
                                end
                            end

                            message_buffer[7 + word_length_reg] <= ASCII_COMMA;
                            message_buffer[8 + word_length_reg]
                                <= ASCII_ZERO + attempts_left_reg;
                            message_buffer[9 + word_length_reg] <= ASCII_LF;
                            message_length <= 5'd10 + word_length_reg;
                            state <= TX_CHECK_SEND;
                        end

                        EVENT_WIN: begin
                            message_buffer[0] <= 8'h57;  // W
                            message_buffer[1] <= 8'h49;  // I
                            message_buffer[2] <= 8'h4E;  // N
                            message_buffer[3] <= ASCII_COMMA;

                            for (character_index = 0;
                                 character_index < 12;
                                 character_index = character_index + 1) begin
                                if (character_index < word_length_reg) begin
                                    message_buffer[4 + character_index]
                                        <= final_word_reg[(8 * character_index) +: 8];
                                end
                            end

                            message_buffer[4 + word_length_reg] <= ASCII_LF;
                            message_length <= 5'd5 + word_length_reg;
                            state <= TX_CHECK_SEND;
                        end

                        EVENT_LOSE_ATTEMPTS: begin
                            message_buffer[0]  <= 8'h4C;  // L
                            message_buffer[1]  <= 8'h4F;  // O
                            message_buffer[2]  <= 8'h53;  // S
                            message_buffer[3]  <= 8'h45;  // E
                            message_buffer[4]  <= 8'h5F;  // _
                            message_buffer[5]  <= 8'h41;  // A
                            message_buffer[6]  <= 8'h54;  // T
                            message_buffer[7]  <= 8'h54;  // T
                            message_buffer[8]  <= 8'h45;  // E
                            message_buffer[9]  <= 8'h4D;  // M
                            message_buffer[10] <= 8'h50;  // P
                            message_buffer[11] <= 8'h54;  // T
                            message_buffer[12] <= 8'h53;  // S
                            message_buffer[13] <= ASCII_COMMA;

                            for (character_index = 0;
                                 character_index < 12;
                                 character_index = character_index + 1) begin
                                if (character_index < word_length_reg) begin
                                    message_buffer[14 + character_index]
                                        <= final_word_reg[(8 * character_index) +: 8];
                                end
                            end

                            message_buffer[14 + word_length_reg] <= ASCII_LF;
                            message_length <= 5'd15 + word_length_reg;
                            state <= TX_CHECK_SEND;
                        end

                        EVENT_LOSE_TIME: begin
                            message_buffer[0] <= 8'h4C;  // L
                            message_buffer[1] <= 8'h4F;  // O
                            message_buffer[2] <= 8'h53;  // S
                            message_buffer[3] <= 8'h45;  // E
                            message_buffer[4] <= 8'h5F;  // _
                            message_buffer[5] <= 8'h54;  // T
                            message_buffer[6] <= 8'h49;  // I
                            message_buffer[7] <= 8'h4D;  // M
                            message_buffer[8] <= 8'h45;  // E
                            message_buffer[9] <= ASCII_COMMA;

                            for (character_index = 0;
                                 character_index < 12;
                                 character_index = character_index + 1) begin
                                if (character_index < word_length_reg) begin
                                    message_buffer[10 + character_index]
                                        <= final_word_reg[(8 * character_index) +: 8];
                                end
                            end

                            message_buffer[10 + word_length_reg] <= ASCII_LF;
                            message_length <= 5'd11 + word_length_reg;
                            state <= TX_CHECK_SEND;
                        end

                        default: begin
                            message_length <= 5'd0;
                            state          <= TX_IDLE;
                        end
                    endcase
                end

                TX_CHECK_SEND: begin
                    if (rdata_i[0] == 1'b0) begin
                        state <= TX_WRITE_DATA;
                    end
                end

                TX_WRITE_DATA: begin
                    state <= TX_WRITE_GAP;
                end

                TX_WRITE_GAP: begin
                    state <= TX_START;
                end

                TX_START: begin
                    state <= TX_WAIT_DONE;
                end

                TX_WAIT_DONE: begin
                    if (rdata_i[0] == 1'b0) begin
                        state <= TX_NEXT;
                    end
                end

                TX_NEXT: begin
                    if ((message_index + 5'd1) >= message_length) begin
                        state <= TX_IDLE;
                    end else begin
                        message_index <= message_index + 5'd1;
                        state         <= TX_CHECK_SEND;
                    end
                end

                default: begin
                    state          <= TX_IDLE;
                    message_length <= 5'd0;
                    message_index  <= 5'd0;
                end
            endcase
        end
    end

    always_comb begin
        event_ready_o  = bus_grant_i && (state == TX_IDLE);
        write_enable_o = 1'b0;
        addr_o         = ADDR_CONTROL;
        wdata_o        = 32'b0;

        case (state)
            TX_IDLE: begin
            end

            TX_CHECK_SEND: begin
                addr_o = ADDR_CONTROL;
            end

            TX_WRITE_DATA: begin
                write_enable_o = bus_grant_i;
                addr_o         = ADDR_TX_DATA;
                wdata_o        = {24'b0, message_buffer[message_index]};
            end

            TX_WRITE_GAP: begin
                addr_o = ADDR_CONTROL;
            end

            TX_START: begin
                write_enable_o = bus_grant_i;
                addr_o         = ADDR_CONTROL;
                wdata_o        = 32'h0000_0001;
            end

            TX_WAIT_DONE: begin
                addr_o = ADDR_CONTROL;
            end

            default: begin
            end
        endcase
    end

endmodule
