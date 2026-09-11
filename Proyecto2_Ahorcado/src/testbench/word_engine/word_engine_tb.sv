`timescale 1ns/1ps
module word_engine_tb;
    logic clk = 0;
    always #5 clk = ~clk;
    logic reset = 1, new_game = 0, difficulty = 0, letter_valid = 0;
    logic [7:0] letter_ascii = 0;
    wire word_ready, letter_correct, letter_repeated, word_complete;
    wire [3:0] word_length;
    wire [95:0] revealed_word;
    word_engine dut (.*);

    logic [5:0] rom_index = 0;
    wire [95:0] rom_word;
    wire [3:0] rom_length;
    wire rom_valid;
    word_rom rom (.index(rom_index), .word_data(rom_word), .word_length(rom_length), .valid(rom_valid));
    wire [5:0] lfsr_state;
    word_lfsr lfsr (.clk(clk), .reset(reset), .state(lfsr_state));

    logic [95:0] reference_words [0:49];
    integer reference_lengths [0:49];
    logic [49:0] easy_coverage = 0, hard_coverage = 0;
    logic [63:0] states_seen;
    logic [95:0] model_pattern;
    logic [25:0] model_used;
    logic model_complete, expected_correct, expected_repeat;
    integer selected_index, checks = 0, games = 0;
    integer fd, result, i, j, mode, phase, code, waited, found;
    string reference_text;

    task automatic require(input logic condition, input string message);
        begin
            checks = checks + 1;
            if (condition !== 1'b1) $fatal(1, "%s (game=%0d index=%0d time=%0t)",
                                         message, games, selected_index, $time);
        end
    endtask

    task automatic reset_system;
        begin
            @(negedge clk); reset = 1; new_game = 0; letter_valid = 0;
            @(posedge clk); #1;
            require(word_length == 0 && !word_ready && !word_complete,
                    "reset must clear length and status");
            require(revealed_word == {12{8'h20}}, "reset pattern must be spaces");
            require(!letter_correct && !letter_repeated, "reset must clear result flags");
            @(negedge clk); reset = 0;
        end
    endtask

    task automatic begin_game(input logic hard);
        integer k;
        begin
            @(negedge clk); difficulty = hard; new_game = 1; letter_valid = 1; letter_ascii = "A";
            @(posedge clk); #1;
            require(!word_ready && !letter_correct && !letter_repeated,
                    "new_game must override simultaneous letter");
            @(negedge clk); new_game = 0; letter_valid = 0;
            // Change the external mode: selection must use its captured value.
            difficulty = !hard;
            waited = 0;
            while (!word_ready && waited < 64) begin
                @(posedge clk); #1; waited = waited + 1;
            end
            require(word_ready && waited <= 63, "selection must finish in at most 63 candidate cycles");
            selected_index = -1;
            for (k = 0; k < 50; k = k + 1)
                if (dut.secret_word === reference_words[k]) selected_index = k;
            require(selected_index >= 0, "selected word must belong to reference bank");
            require(word_length == reference_lengths[selected_index], "selected length mismatch");
            require(!hard || word_length >= 6, "hard selection must reject short words");
            require(!word_complete && dut.used_letters == 0, "new game must clear progress");
            if (hard) hard_coverage[selected_index] = 1;
            else easy_coverage[selected_index] = 1;
            model_pattern = {12{8'h20}};
            for (k = 0; k < reference_lengths[selected_index]; k = k + 1)
                model_pattern[8*k +: 8] = "_";
            model_used = 0;
            model_complete = 0;
            require(revealed_word === model_pattern, "initial pattern and padding mismatch");
            @(posedge clk); #1;
            require(!word_ready, "word_ready must last one cycle");
            games = games + 1;
        end
    endtask

    task automatic send_and_check(input logic [7:0] value);
        integer k, bit_index;
        begin
            expected_correct = 0;
            expected_repeat = 0;
            if (!model_complete && value >= 65 && value <= 90) begin
                bit_index = int'(value) - 65;
                expected_repeat = model_used[bit_index];
                if (!expected_repeat) begin
                    model_used[bit_index] = 1;
                    for (k = 0; k < reference_lengths[selected_index]; k = k + 1)
                        if (reference_words[selected_index][8*k +: 8] == value) begin
                            model_pattern[8*k +: 8] = value;
                            expected_correct = 1;
                        end
                    model_complete = (model_pattern == reference_words[selected_index]);
                end
            end
            @(negedge clk); letter_ascii = value; letter_valid = 1;
            @(posedge clk); #1;
            require(letter_correct === expected_correct, "correct flag or latency mismatch");
            require(letter_repeated === expected_repeat, "repeat flag or latency mismatch");
            require(revealed_word === model_pattern, "all occurrences must update together");
            require(dut.used_letters === model_used, "used letters must include correct and wrong guesses");
            require(word_complete === model_complete, "complete flag mismatch");
            // Adjacent calls may hold letter_valid high across consecutive edges.
        end
    endtask

    initial begin
        // Independent ASCII fixture, rather than decoding the RTL constants.
        fd = $fopen("word_bank.txt", "r");
        if (fd == 0) fd = $fopen("src/design/word_engine/word_bank.txt", "r");
        require(fd != 0, "word_bank.txt not found in simulation working directory or project source path");
        for (i = 0; i < 50; i = i + 1) begin
            result = $fscanf(fd, "%s", reference_text);
            require(result == 1, "bank must contain 50 words");
            reference_lengths[i] = reference_text.len();
            require(reference_text.len() >= 4 && reference_text.len() <= 12, "invalid bank length");
            reference_words[i] = {12{8'h20}};
            for (j = 0; j < reference_text.len(); j = j + 1) begin
                require(reference_text[j] >= 65 && reference_text[j] <= 90, "bank must use A-Z");
                reference_words[i][8*j +: 8] = reference_text[j];
            end
            for (j = 0; j < i; j = j + 1)
                require(reference_words[j] != reference_words[i], "duplicate bank entry");
            rom_index = i; #1;
            require(rom_valid && rom_word === reference_words[i] && rom_length == reference_lengths[i],
                    "ROM differs from independent ASCII bank");
        end
        result = $fscanf(fd, "%s", reference_text);
        require(result != 1, "bank contains unexpected additional entries");
        $fclose(fd);
        for (i = 50; i < 64; i = i + 1) begin
            rom_index = i; #1;
            require(!rom_valid && rom_length == 0 && rom_word == {12{8'h20}}, "invalid ROM index");
        end

        reset_system();
        states_seen = 0;
        for (i = 0; i < 63; i = i + 1) begin
            #1;
            require(lfsr_state != 0 && !states_seen[lfsr_state], "LFSR repeated before period 63");
            states_seen[lfsr_state] = 1;
            @(negedge clk);
        end
        require(states_seen == 64'hFFFFFFFFFFFFFFFE, "LFSR must visit all nonzero states");
        require(lfsr_state == 1, "LFSR must return to seed after 63 updates");

        // Bytes before a game must not alter the motor.
        letter_valid = 1; letter_ascii = "A";
        @(posedge clk); #1;
        require(word_length == 0 && !letter_correct && !word_complete, "ignore letters in IDLE");
        @(negedge clk); letter_valid = 0;

        // Sweep every LFSR phase: all 50 easy and all eligible hard words must be reachable.
        for (mode = 0; mode < 2; mode = mode + 1) begin
            for (phase = 0; phase < 63; phase = phase + 1) begin
                reset_system();
                repeat (phase) @(negedge clk);
                begin_game(mode == 1);
                // Every non-A-Z byte must preserve a live game's entire state.
                if (phase == 0)
                    for (code = 0; code < 256; code = code + 1)
                        if (code < 65 || code > 90) send_and_check(code);
                for (code = 65; code <= 90; code = code + 1) begin
                    send_and_check(code);
                    send_and_check(code); // repeat hits AND misses, including A/Z boundaries
                end
                require(word_complete && revealed_word == reference_words[selected_index],
                        "all alphabet guesses must complete word");
                @(negedge clk); letter_valid = 0;
                @(posedge clk); #1;
                require(!letter_correct && !letter_repeated && word_complete,
                        "result flags clear but completion persists");
            end
        end
        require(&easy_coverage, "easy mode did not reach all 50 words");
        for (i = 0; i < 50; i = i + 1)
            require(hard_coverage[i] == (reference_lengths[i] >= 6), "hard coverage mismatch");

        // Restart without a global reset, including a restart during selection.
        begin_game(0);
        send_and_check("A");
        @(negedge clk); letter_valid = 0; new_game = 1; difficulty = 1;
        @(posedge clk); #1;
        require(!word_ready && word_length == 0, "restart must clear old word");
        begin_game(0);
        require(dut.used_letters == 0, "restart must clear used letters");
        @(negedge clk); reset = 1; new_game = 1; letter_valid = 1;
        @(posedge clk); #1;
        require(word_length == 0 && !word_ready && !letter_correct, "reset has highest priority");
        $display("PASS: word_engine_tb; %0d checks, %0d games; 50 easy words and all eligible hard words covered", checks, games);
        $finish;
    end
    initial begin
        #2000000;
        $fatal(1, "global simulation timeout");
    end
endmodule
