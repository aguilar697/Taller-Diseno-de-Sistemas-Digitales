`timescale 1ns / 1ps

module tb_pixel_reset_sync;

    // -------------------------------------------------------------------------
    // Testbench signals
    // -------------------------------------------------------------------------

    logic clk_pixel_i;
    logic rst_i;
    logic locked_i;
    logic rst_pixel_o;

    int errors;

    // -------------------------------------------------------------------------
    // Device Under Test
    // -------------------------------------------------------------------------

    pixel_reset_sync dut (
        .clk_pixel_i (clk_pixel_i),
        .rst_i       (rst_i),
        .locked_i    (locked_i),
        .rst_pixel_o (rst_pixel_o)
    );

    // -------------------------------------------------------------------------
    // 25 MHz pixel clock
    // -------------------------------------------------------------------------
    // T = 1 / 25 MHz = 40 ns.
    // Por lo tanto, el reloj cambia de nivel cada 20 ns.
    always #20 clk_pixel_i = ~clk_pixel_i;

    // -------------------------------------------------------------------------
    // Test sequence
    // -------------------------------------------------------------------------

    initial begin

        clk_pixel_i = 1'b0;
        rst_i       = 1'b1;
        locked_i    = 1'b0;
        errors      = 0;

        $display("========================================");
        $display("TB PIXEL_RESET_SYNC");
        $display("========================================");

        // ---------------------------------------------------------------------
        // Test 1: General reset must assert pixel reset
        // ---------------------------------------------------------------------

        #5;

        if (rst_pixel_o !== 1'b1) begin
            $display("[FAIL] General reset assertion");
            errors++;
        end else begin
            $display("[PASS] General reset asserted");
        end

        // ---------------------------------------------------------------------
        // Test 2: Pixel reset must remain active while PLL is unlocked
        // ---------------------------------------------------------------------

        rst_i = 1'b0;

        repeat (2) @(posedge clk_pixel_i);
        #1;

        if (rst_pixel_o !== 1'b1) begin
            $display("[FAIL] Reset released while PLL unlocked");
            errors++;
        end else begin
            $display("[PASS] Reset held while PLL unlocked");
        end

        // ---------------------------------------------------------------------
        // Test 3: Reset release must be synchronized
        // ---------------------------------------------------------------------

        @(negedge clk_pixel_i);
        locked_i = 1'b1;

        // Después del primer flanco, el reset todavía debe seguir activo.
        @(posedge clk_pixel_i);
        #1;

        if (rst_pixel_o !== 1'b1) begin
            $display("[FAIL] Reset released too early");
            errors++;
        end else begin
            $display("[PASS] Reset held during first synchronization stage");
        end

        // Después del segundo flanco ya puede liberarse.
        @(posedge clk_pixel_i);
        #1;

        if (rst_pixel_o !== 1'b0) begin
            $display("[FAIL] Synchronized reset release");
            errors++;
        end else begin
            $display("[PASS] Synchronized reset released");
        end

        // ---------------------------------------------------------------------
        // Test 4: PLL lock loss must assert reset
        // ---------------------------------------------------------------------

        #7;
        locked_i = 1'b0;

        #1;

        if (rst_pixel_o !== 1'b1) begin
            $display("[FAIL] PLL lock loss did not assert reset");
            errors++;
        end else begin
            $display("[PASS] PLL lock loss asserted reset");
        end

        // ---------------------------------------------------------------------
        // Test 5: Recover after PLL locks again
        // ---------------------------------------------------------------------

        @(negedge clk_pixel_i);
        locked_i = 1'b1;

        repeat (2) @(posedge clk_pixel_i);
        #1;

        if (rst_pixel_o !== 1'b0) begin
            $display("[FAIL] Reset did not release after PLL recovery");
            errors++;
        end else begin
            $display("[PASS] Reset released after PLL recovery");
        end

        // ---------------------------------------------------------------------
        // Test 6: General reset must assert again
        // ---------------------------------------------------------------------

        #7;
        rst_i = 1'b1;

        #1;

        if (rst_pixel_o !== 1'b1) begin
            $display("[FAIL] General reset reassertion");
            errors++;
        end else begin
            $display("[PASS] General reset reasserted");
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