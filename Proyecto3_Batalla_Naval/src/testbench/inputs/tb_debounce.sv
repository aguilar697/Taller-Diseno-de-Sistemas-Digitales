`timescale 1ns / 1ps

module tb_debounce;

    // -------------------------------------------------------------------------
    // Testbench configuration
    // -------------------------------------------------------------------------

    localparam int unsigned TEST_CYCLES = 4;

    // -------------------------------------------------------------------------
    // Testbench signals
    // -------------------------------------------------------------------------

    logic clk_i;
    logic rst_i;
    logic sync_i;
    logic clean_o;

    int errors;

    // -------------------------------------------------------------------------
    // Device Under Test
    // -------------------------------------------------------------------------

    debounce #(
        .DEBOUNCE_CYCLES(TEST_CYCLES)
    ) dut (
        .clk_i   (clk_i),
        .rst_i   (rst_i),
        .sync_i  (sync_i),
        .clean_o (clean_o)
    );

    // -------------------------------------------------------------------------
    // 100 MHz clock
    // -------------------------------------------------------------------------

    always #5 clk_i = ~clk_i;

    // -------------------------------------------------------------------------
    // Test sequence
    // -------------------------------------------------------------------------

    initial begin
        clk_i  = 1'b0;
        rst_i  = 1'b1;
        sync_i = 1'b0;
        errors = 0;

        $display("========================================");
        $display("TB DEBOUNCE");
        $display("========================================");

        // -------------------------------------------------------------
        // Test 1: Reset
        // -------------------------------------------------------------

        repeat (2) @(posedge clk_i);
        #1;

        if (clean_o !== 1'b0) begin
            $display("[FAIL] Reset");
            errors++;
        end else begin
            $display("[PASS] Reset");
        end

        rst_i = 1'b0;

        // -------------------------------------------------------------
        // Test 2: Short bounce must not change the output
        // -------------------------------------------------------------

        @(negedge clk_i);
        sync_i = 1'b1;

        repeat (2) @(posedge clk_i);

        @(negedge clk_i);
        sync_i = 1'b0;

        @(posedge clk_i);
        #1;

        if (clean_o !== 1'b0) begin
            $display("[FAIL] Short bounce changed output");
            errors++;
        end else begin
            $display("[PASS] Short bounce rejected");
        end

        // -------------------------------------------------------------
        // Test 3: Stable high must be accepted
        // -------------------------------------------------------------

        @(negedge clk_i);
        sync_i = 1'b1;

        repeat (TEST_CYCLES) @(posedge clk_i);
        #1;

        if (clean_o !== 1'b1) begin
            $display("[FAIL] Stable high not accepted");
            errors++;
        end else begin
            $display("[PASS] Stable high accepted");
        end

        // -------------------------------------------------------------
        // Test 4: Short low bounce must not change the output
        // -------------------------------------------------------------

        @(negedge clk_i);
        sync_i = 1'b0;

        repeat (2) @(posedge clk_i);

        @(negedge clk_i);
        sync_i = 1'b1;

        @(posedge clk_i);
        #1;

        if (clean_o !== 1'b1) begin
            $display("[FAIL] Low bounce changed output");
            errors++;
        end else begin
            $display("[PASS] Low bounce rejected");
        end

        // -------------------------------------------------------------
        // Test 5: Stable low must be accepted
        // -------------------------------------------------------------

        @(negedge clk_i);
        sync_i = 1'b0;

        repeat (TEST_CYCLES) @(posedge clk_i);
        #1;

        if (clean_o !== 1'b0) begin
            $display("[FAIL] Stable low not accepted");
            errors++;
        end else begin
            $display("[PASS] Stable low accepted");
        end

        // -------------------------------------------------------------
        // Final result
        // -------------------------------------------------------------

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