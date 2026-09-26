`timescale 1ns / 1ps

module tb_vga_timing;

    // -------------------------------------------------------------------------
    // Testbench signals
    // -------------------------------------------------------------------------

    logic       clk_pixel_i;
    logic       rst_pixel_i;

    logic [9:0] pixel_x_o;
    logic [9:0] pixel_y_o;
    logic       active_video_o;

    logic       vga_hsync_o;
    logic       vga_vsync_o;

    logic       line_end_o;

    int errors;

    // -------------------------------------------------------------------------
    // Device Under Test
    // -------------------------------------------------------------------------

    vga_timing dut (
        .clk_pixel_i   (clk_pixel_i),
        .rst_pixel_i   (rst_pixel_i),

        .pixel_x_o     (pixel_x_o),
        .pixel_y_o     (pixel_y_o),
        .active_video_o(active_video_o),

        .vga_hsync_o   (vga_hsync_o),
        .vga_vsync_o   (vga_vsync_o),

        .line_end_o    (line_end_o)
    );

    // -------------------------------------------------------------------------
    // 25 MHz pixel clock
    // -------------------------------------------------------------------------
    // Periodo = 40 ns.
    always #20 clk_pixel_i = ~clk_pixel_i;

    // -------------------------------------------------------------------------
    // Check helper
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
    // Wait until a specific VGA coordinate is reached
    // -------------------------------------------------------------------------

    task automatic wait_coord(
        input int unsigned x,
        input int unsigned y
    );
        begin
            do begin
                @(posedge clk_pixel_i);
                #1;
            end while ((pixel_x_o != x) || (pixel_y_o != y));
        end
    endtask

    // -------------------------------------------------------------------------
    // Test sequence
    // -------------------------------------------------------------------------

    initial begin

        clk_pixel_i = 1'b0;
        rst_pixel_i = 1'b1;
        errors      = 0;

        $display("========================================");
        $display("TB VGA_TIMING");
        $display("========================================");

        // ---------------------------------------------------------------------
        // Test 1: Reset
        // ---------------------------------------------------------------------

        repeat (2) @(posedge clk_pixel_i);
        #1;

        check(
            (pixel_x_o == 10'd0) &&
            (pixel_y_o == 10'd0),
            "Reset clears horizontal and vertical counters"
        );

        check(
            active_video_o == 1'b1,
            "Origin belongs to active video"
        );

        check(
            (vga_hsync_o == 1'b1) &&
            (vga_vsync_o == 1'b1),
            "Synchronization signals inactive at origin"
        );

        @(negedge clk_pixel_i);
        rst_pixel_i = 1'b0;

        // ---------------------------------------------------------------------
        // Test 2: Last visible horizontal pixel
        // ---------------------------------------------------------------------

        wait_coord(639, 0);

        check(
            active_video_o == 1'b1,
            "Pixel x=639 is still visible"
        );

        // ---------------------------------------------------------------------
        // Test 3: Horizontal blanking begins
        // ---------------------------------------------------------------------

        wait_coord(640, 0);

        check(
            active_video_o == 1'b0,
            "Horizontal blanking starts at x=640"
        );

        // ---------------------------------------------------------------------
        // Test 4: HSYNC boundaries
        // ---------------------------------------------------------------------

        wait_coord(655, 0);

        check(
            vga_hsync_o == 1'b1,
            "HSYNC high before synchronization pulse"
        );

        wait_coord(656, 0);

        check(
            vga_hsync_o == 1'b0,
            "HSYNC falls at x=656"
        );

        wait_coord(751, 0);

        check(
            vga_hsync_o == 1'b0,
            "HSYNC remains low through x=751"
        );

        wait_coord(752, 0);

        check(
            vga_hsync_o == 1'b1,
            "HSYNC returns high at x=752"
        );

        // ---------------------------------------------------------------------
        // Test 5: End of first line
        // ---------------------------------------------------------------------

        wait_coord(799, 0);

        check(
            line_end_o == 1'b1,
            "End-of-line detected at x=799"
        );

        @(posedge clk_pixel_i);
        #1;

        check(
            (pixel_x_o == 10'd0) &&
            (pixel_y_o == 10'd1),
            "Horizontal counter wraps and vertical counter increments"
        );

        check(
            line_end_o == 1'b0,
            "End-of-line clears after wrap"
        );

        // ---------------------------------------------------------------------
        // Test 6: Last visible vertical line
        // ---------------------------------------------------------------------

        wait_coord(0, 479);

        check(
            active_video_o == 1'b1,
            "Line y=479 is still visible"
        );

        // ---------------------------------------------------------------------
        // Test 7: Vertical blanking begins
        // ---------------------------------------------------------------------

        wait_coord(0, 480);

        check(
            active_video_o == 1'b0,
            "Vertical blanking starts at y=480"
        );

        // ---------------------------------------------------------------------
        // Test 8: VSYNC boundaries
        // ---------------------------------------------------------------------

        wait_coord(0, 489);

        check(
            vga_vsync_o == 1'b1,
            "VSYNC high before synchronization pulse"
        );

        wait_coord(0, 490);

        check(
            vga_vsync_o == 1'b0,
            "VSYNC falls at y=490"
        );

        wait_coord(0, 491);

        check(
            vga_vsync_o == 1'b0,
            "VSYNC remains low through y=491"
        );

        wait_coord(0, 492);

        check(
            vga_vsync_o == 1'b1,
            "VSYNC returns high at y=492"
        );

        // ---------------------------------------------------------------------
        // Test 9: Last pixel of the frame
        // ---------------------------------------------------------------------

        wait_coord(799, 524);

        check(
            line_end_o == 1'b1,
            "Last line ends at coordinate 799,524"
        );

        @(posedge clk_pixel_i);
        #1;

        check(
            (pixel_x_o == 10'd0) &&
            (pixel_y_o == 10'd0),
            "Frame wraps back to coordinate 0,0"
        );

        check(
            active_video_o == 1'b1,
            "New frame begins in active video"
        );

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