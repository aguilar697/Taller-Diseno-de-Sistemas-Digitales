`timescale 1ns / 1ps

module tb_input_sync;

    // -------------------------------------------------------------------------
    // Testbench signals
    // -------------------------------------------------------------------------

    logic clk_i;
    logic rst_i;
    logic async_i;
    logic sync_o;

    int errors;

    // -------------------------------------------------------------------------
    // Device Under Test
    // -------------------------------------------------------------------------

    input_sync dut (
        .clk_i   (clk_i),
        .rst_i   (rst_i),
        .async_i (async_i),
        .sync_o  (sync_o)
    );

    // -------------------------------------------------------------------------
    // 100 MHz clock
    // -------------------------------------------------------------------------

    always #5 clk_i = ~clk_i;

    // -------------------------------------------------------------------------
    // Test sequence
    // -------------------------------------------------------------------------

    initial begin
        clk_i   = 1'b0;
        rst_i   = 1'b1;
        async_i = 1'b0;
        errors  = 0;

        $display("========================================");
        $display("TB INPUT_SYNC");
        $display("========================================");

        // -------------------------------------------------------------
        // Test 1: Reset
        // -------------------------------------------------------------

        repeat (2) @(posedge clk_i);
        #1;

        if (sync_o !== 1'b0) begin
            $display("[FAIL] Reset");
            errors++;
        end else begin
            $display("[PASS] Reset");
        end

        rst_i = 1'b0;

        // -------------------------------------------------------------
        // Test 2: Synchronize logic high
        // -------------------------------------------------------------

        @(negedge clk_i);
        async_i = 1'b1;

        @(posedge clk_i);
        #1;

        if (sync_o !== 1'b0) begin
            $display("[FAIL] Output changed too early");
            errors++;
        end

        @(posedge clk_i);
        #1;

        if (sync_o !== 1'b1) begin
            $display("[FAIL] High level synchronization");
            errors++;
        end else begin
            $display("[PASS] High level synchronization");
        end

        // -------------------------------------------------------------
        // Test 3: Synchronize logic low
        // -------------------------------------------------------------

        @(negedge clk_i);
        async_i = 1'b0;

        @(posedge clk_i);
        #1;

        if (sync_o !== 1'b1) begin
            $display("[FAIL] Output changed too early");
            errors++;
        end

        @(posedge clk_i);
        #1;

        if (sync_o !== 1'b0) begin
            $display("[FAIL] Low level synchronization");
            errors++;
        end else begin
            $display("[PASS] Low level synchronization");
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