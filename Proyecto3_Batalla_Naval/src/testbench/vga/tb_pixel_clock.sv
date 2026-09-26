`timescale 1ns / 1ps

module tb_pixel_clock;

    // -------------------------------------------------------------------------
    // Testbench signals
    // -------------------------------------------------------------------------

    logic clk_100_i;
    logic rst_i;

    logic clk_pixel_o;
    logic locked_o;

    int errors;

    time t_in_1;
    time t_in_2;

    time t_pixel_1;
    time t_pixel_2;

    // -------------------------------------------------------------------------
    // Device Under Test
    // -------------------------------------------------------------------------

    pixel_clock dut (
        .clk_100_i   (clk_100_i),
        .rst_i       (rst_i),
        .clk_pixel_o (clk_pixel_o),
        .locked_o    (locked_o)
    );

    // -------------------------------------------------------------------------
    // 100 MHz input clock
    // -------------------------------------------------------------------------
    // T = 1 / 100 MHz = 10 ns
    always #5 clk_100_i = ~clk_100_i;

    // -------------------------------------------------------------------------
    // Generic checker
    // -------------------------------------------------------------------------

    task automatic check(
        input logic condition,
        input string message
    );
        begin

            if (condition !== 1'b1) begin
                $display("[FAIL] %s", message);
                errors++;
            end else begin
                $display("[PASS] %s", message);
            end

        end
    endtask

    // -------------------------------------------------------------------------
    // Test sequence
    // -------------------------------------------------------------------------

    initial begin

        clk_100_i = 1'b0;
        rst_i     = 1'b1;
        errors    = 0;

        $display("========================================");
        $display("TB PIXEL_CLOCK");
        $display("========================================");

        // ---------------------------------------------------------------------
        // Test 1: MMCM starts in reset
        // ---------------------------------------------------------------------

        #50;

        check(
            locked_o === 1'b0,
            "MMCM remains unlocked during reset"
        );

        // ---------------------------------------------------------------------
        // Test 2: Verify input clock period
        // ---------------------------------------------------------------------

        @(posedge clk_100_i);
        t_in_1 = $time;

        @(posedge clk_100_i);
        t_in_2 = $time;

        check(
            (t_in_2 - t_in_1) == 10ns,
            "Input clock period is 10 ns (100 MHz)"
        );

        // ---------------------------------------------------------------------
        // Release MMCM reset
        // ---------------------------------------------------------------------

        @(negedge clk_100_i);
        rst_i = 1'b0;

        $display("[INFO] Waiting for MMCM lock...");

        // ---------------------------------------------------------------------
        // Test 3: Wait for lock
        // ---------------------------------------------------------------------
        // No asumimos un tiempo exacto de lock. El modelo del MMCM decide
        // cuándo sus condiciones internas son estables.

        fork

            begin : wait_for_lock

                wait (locked_o === 1'b1);

                $display(
                    "[PASS] MMCM locked at time %0t",
                    $time
                );

            end

            begin : lock_timeout

                #10000;

                if (locked_o !== 1'b1) begin
                    $display("[FAIL] MMCM lock timeout");
                    errors++;
                end

            end

        join_any

        disable fork;

        // ---------------------------------------------------------------------
        // Continue only if the MMCM reached lock
        // ---------------------------------------------------------------------

        if (locked_o === 1'b1) begin

            // Allow the generated clock to continue for several cycles.
            repeat (4) @(posedge clk_pixel_o);

            // -----------------------------------------------------------------
            // Test 4: Measure generated pixel clock
            // -----------------------------------------------------------------

            @(posedge clk_pixel_o);
            t_pixel_1 = $time;

            @(posedge clk_pixel_o);
            t_pixel_2 = $time;

            check(
                (t_pixel_2 - t_pixel_1) == 40ns,
                "Pixel clock period is 40 ns (25 MHz)"
            );

            // -----------------------------------------------------------------
            // Test 5: Clock relationship
            // -----------------------------------------------------------------

            check(
                (t_pixel_2 - t_pixel_1) ==
                4 * (t_in_2 - t_in_1),
                "Pixel clock period is four times input period"
            );

            // -----------------------------------------------------------------
            // Test 6: Reassert reset
            // -----------------------------------------------------------------

            @(negedge clk_100_i);
            rst_i = 1'b1;

            // locked may react through the MMCM model, so allow some time.
            #100;

            check(
                locked_o === 1'b0,
                "MMCM loses lock after reset reassertion"
            );

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