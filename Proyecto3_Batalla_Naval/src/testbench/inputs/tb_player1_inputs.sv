`timescale 1ns / 1ps

module tb_player1_inputs;

    // -------------------------------------------------------------------------
    // Testbench configuration
    // -------------------------------------------------------------------------

    localparam int unsigned TEST_DEBOUNCE_CYCLES = 4;

    // El sincronizador introduce dos etapas antes del debounce.
    localparam int unsigned FILTER_WAIT_CYCLES =
        TEST_DEBOUNCE_CYCLES + 2;

    // -------------------------------------------------------------------------
    // Testbench signals
    // -------------------------------------------------------------------------

    logic clk_i;
    logic rst_i;

    logic up_i;
    logic down_i;
    logic left_i;
    logic right_i;
    logic sel_i;
    logic ok_i;
    logic game_rst_i;

    logic        input_write_enable_i;
    logic [1:0]  input_addr_i;
    logic [31:0] input_wdata_i;
    logic [31:0] input_rdata_o;

    int errors;

    // -------------------------------------------------------------------------
    // Device Under Test
    // -------------------------------------------------------------------------

    player1_inputs #(
        .DEBOUNCE_CYCLES(TEST_DEBOUNCE_CYCLES)
    ) dut (
        .clk_i                 (clk_i),
        .rst_i                 (rst_i),

        .up_i                  (up_i),
        .down_i                (down_i),
        .left_i                (left_i),
        .right_i               (right_i),
        .sel_i                 (sel_i),
        .ok_i                  (ok_i),
        .game_rst_i            (game_rst_i),

        .input_write_enable_i  (input_write_enable_i),
        .input_addr_i          (input_addr_i),
        .input_wdata_i         (input_wdata_i),
        .input_rdata_o         (input_rdata_o)
    );

    // -------------------------------------------------------------------------
    // 100 MHz clock
    // -------------------------------------------------------------------------

    always #5 clk_i = ~clk_i;

    // -------------------------------------------------------------------------
    // Test sequence
    // -------------------------------------------------------------------------

    initial begin

        clk_i                = 1'b0;
        rst_i                = 1'b1;

        up_i                 = 1'b0;
        down_i               = 1'b0;
        left_i               = 1'b0;
        right_i              = 1'b0;
        sel_i                = 1'b0;
        ok_i                 = 1'b0;
        game_rst_i           = 1'b0;

        input_write_enable_i = 1'b0;
        input_addr_i         = 2'b00;
        input_wdata_i        = 32'b0;

        errors               = 0;

        $display("========================================");
        $display("TB PLAYER1_INPUTS");
        $display("========================================");

        // ---------------------------------------------------------------------
        // Test 1: Reset
        // ---------------------------------------------------------------------

        repeat (2) @(posedge clk_i);
        #1;

        if (input_rdata_o !== 32'h0000_0000) begin
            $display("[FAIL] Reset");
            errors++;
        end else begin
            $display("[PASS] Reset");
        end

        rst_i = 1'b0;

        // ---------------------------------------------------------------------
        // Test 2: UP -> bit 0
        // ---------------------------------------------------------------------

        @(negedge clk_i);
        up_i = 1'b1;

        repeat (FILTER_WAIT_CYCLES) @(posedge clk_i);
        #1;

        if (input_rdata_o !== 32'h0000_0001) begin
            $display("[FAIL] UP mapping");
            errors++;
        end else begin
            $display("[PASS] UP -> bit 0");
        end

        @(negedge clk_i);
        up_i = 1'b0;

        repeat (FILTER_WAIT_CYCLES) @(posedge clk_i);
        #1;

        // ---------------------------------------------------------------------
        // Test 3: DOWN -> bit 1
        // ---------------------------------------------------------------------

        @(negedge clk_i);
        down_i = 1'b1;

        repeat (FILTER_WAIT_CYCLES) @(posedge clk_i);
        #1;

        if (input_rdata_o !== 32'h0000_0002) begin
            $display("[FAIL] DOWN mapping");
            errors++;
        end else begin
            $display("[PASS] DOWN -> bit 1");
        end

        @(negedge clk_i);
        down_i = 1'b0;

        repeat (FILTER_WAIT_CYCLES) @(posedge clk_i);
        #1;

        // ---------------------------------------------------------------------
        // Test 4: LEFT -> bit 2
        // ---------------------------------------------------------------------

        @(negedge clk_i);
        left_i = 1'b1;

        repeat (FILTER_WAIT_CYCLES) @(posedge clk_i);
        #1;

        if (input_rdata_o !== 32'h0000_0004) begin
            $display("[FAIL] LEFT mapping");
            errors++;
        end else begin
            $display("[PASS] LEFT -> bit 2");
        end

        @(negedge clk_i);
        left_i = 1'b0;

        repeat (FILTER_WAIT_CYCLES) @(posedge clk_i);
        #1;

        // ---------------------------------------------------------------------
        // Test 5: RIGHT -> bit 3
        // ---------------------------------------------------------------------

        @(negedge clk_i);
        right_i = 1'b1;

        repeat (FILTER_WAIT_CYCLES) @(posedge clk_i);
        #1;

        if (input_rdata_o !== 32'h0000_0008) begin
            $display("[FAIL] RIGHT mapping");
            errors++;
        end else begin
            $display("[PASS] RIGHT -> bit 3");
        end

        @(negedge clk_i);
        right_i = 1'b0;

        repeat (FILTER_WAIT_CYCLES) @(posedge clk_i);
        #1;

        // ---------------------------------------------------------------------
        // Test 6: SEL -> bit 4
        // ---------------------------------------------------------------------

        @(negedge clk_i);
        sel_i = 1'b1;

        repeat (FILTER_WAIT_CYCLES) @(posedge clk_i);
        #1;

        if (input_rdata_o !== 32'h0000_0010) begin
            $display("[FAIL] SEL mapping");
            errors++;
        end else begin
            $display("[PASS] SEL -> bit 4");
        end

        @(negedge clk_i);
        sel_i = 1'b0;

        repeat (FILTER_WAIT_CYCLES) @(posedge clk_i);
        #1;

        // ---------------------------------------------------------------------
        // Test 7: OK -> bit 5
        // ---------------------------------------------------------------------

        @(negedge clk_i);
        ok_i = 1'b1;

        repeat (FILTER_WAIT_CYCLES) @(posedge clk_i);
        #1;

        if (input_rdata_o !== 32'h0000_0020) begin
            $display("[FAIL] OK mapping");
            errors++;
        end else begin
            $display("[PASS] OK -> bit 5");
        end

        @(negedge clk_i);
        ok_i = 1'b0;

        repeat (FILTER_WAIT_CYCLES) @(posedge clk_i);
        #1;

        // ---------------------------------------------------------------------
        // Test 8: GAME_RST -> bit 6
        // ---------------------------------------------------------------------

        @(negedge clk_i);
        game_rst_i = 1'b1;

        repeat (FILTER_WAIT_CYCLES) @(posedge clk_i);
        #1;

        if (input_rdata_o !== 32'h0000_0040) begin
            $display("[FAIL] GAME_RST mapping");
            errors++;
        end else begin
            $display("[PASS] GAME_RST -> bit 6");
        end

        @(negedge clk_i);
        game_rst_i = 1'b0;

        repeat (FILTER_WAIT_CYCLES) @(posedge clk_i);
        #1;

        // ---------------------------------------------------------------------
        // Test 9: All inputs active
        // ---------------------------------------------------------------------

        @(negedge clk_i);

        up_i       = 1'b1;
        down_i     = 1'b1;
        left_i     = 1'b1;
        right_i    = 1'b1;
        sel_i      = 1'b1;
        ok_i       = 1'b1;
        game_rst_i = 1'b1;

        repeat (FILTER_WAIT_CYCLES) @(posedge clk_i);
        #1;

        if (input_rdata_o !== 32'h0000_007F) begin
            $display("[FAIL] All inputs active");
            errors++;
        end else begin
            $display("[PASS] All seven inputs correctly packed");
        end

        // ---------------------------------------------------------------------
        // Test 10: MMIO writes must be ignored
        // ---------------------------------------------------------------------

        input_write_enable_i = 1'b1;
        input_wdata_i        = 32'hFFFF_FFFF;

        @(posedge clk_i);
        #1;

        input_write_enable_i = 1'b0;

        if (input_rdata_o !== 32'h0000_007F) begin
            $display("[FAIL] MMIO write modified input state");
            errors++;
        end else begin
            $display("[PASS] MMIO writes ignored");
        end

        // ---------------------------------------------------------------------
        // Test 11: Invalid local addresses must return zero
        // ---------------------------------------------------------------------

        input_addr_i = 2'b01;
        #1;

        if (input_rdata_o !== 32'h0000_0000) begin
            $display("[FAIL] Address 01");
            errors++;
        end

        input_addr_i = 2'b10;
        #1;

        if (input_rdata_o !== 32'h0000_0000) begin
            $display("[FAIL] Address 10");
            errors++;
        end

        input_addr_i = 2'b11;
        #1;

        if (input_rdata_o !== 32'h0000_0000) begin
            $display("[FAIL] Address 11");
            errors++;
        end

        if (errors == 0) begin
            $display("[PASS] Invalid addresses return zero");
        end

        // Restore valid register address.
        input_addr_i = 2'b00;

        // ---------------------------------------------------------------------
        // Test 12: Reset clears all filtered levels
        // ---------------------------------------------------------------------

        rst_i = 1'b1;

        @(posedge clk_i);
        #1;

        if (input_rdata_o !== 32'h0000_0000) begin
            $display("[FAIL] Final reset");
            errors++;
        end else begin
            $display("[PASS] Final reset clears input state");
        end

        // ---------------------------------------------------------------------
        // Final result
        // ---------------------------------------------------------------------

        $display("----------------------------------------");

        if (errors == 0) begin
            $display("TEST PASSED");
        end else begin
            $display("TEST FAILED - %0d error(s)", errors);
        end

        $display("========================================");

        $finish;

    end

endmodule