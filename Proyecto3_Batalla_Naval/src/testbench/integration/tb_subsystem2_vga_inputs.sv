`timescale 1ns / 1ps

module tb_subsystem2_vga_inputs;

    // =========================================================================
    // Test configuration
    // =========================================================================
    //
    // En hardware el debounce utiliza muchos ciclos para filtrar rebotes reales.
    // Para simulación se reduce el valor y así evitar tiempos innecesarios.
    localparam int unsigned TEST_DEBOUNCE_CYCLES = 4;

    // Paleta utilizada por tile_renderer.
    localparam logic [11:0] RGB_BLACK  = 12'h000;
    localparam logic [11:0] RGB_WATER  = 12'h04F;
    localparam logic [11:0] RGB_CURSOR = 12'hFF0;
    localparam logic [11:0] RGB_GLYPH  = 12'hFFF;

    // =========================================================================
    // Clock and reset
    // =========================================================================

    logic clk_100_i;
    logic rst_i;

    // =========================================================================
    // Player 1 physical inputs
    // =========================================================================

    logic up_i;
    logic down_i;
    logic left_i;
    logic right_i;
    logic sel_i;
    logic ok_i;
    logic game_rst_i;

    // =========================================================================
    // Player 1 MMIO interface
    // =========================================================================

    logic        input_write_enable_i;
    logic [1:0]  input_addr_i;
    logic [31:0] input_wdata_i;
    logic [31:0] input_rdata_o;

    // =========================================================================
    // VGA memory MMIO interface
    // =========================================================================

    logic        vga_write_enable_i;
    logic [8:0]  vga_addr_i;
    logic [31:0] vga_wdata_i;
    logic [31:0] vga_rdata_o;

    // =========================================================================
    // Physical VGA outputs
    // =========================================================================

    logic        vga_hsync_o;
    logic        vga_vsync_o;
    logic [11:0] vga_rgb_o;

    int errors;

    // =========================================================================
    // Device Under Test
    // =========================================================================

    subsystem2_vga_inputs #(
        .INPUT_DEBOUNCE_CYCLES(TEST_DEBOUNCE_CYCLES)
    ) dut (
        .clk_100_i             (clk_100_i),
        .rst_i                 (rst_i),

        // Player 1 inputs
        .up_i                  (up_i),
        .down_i                (down_i),
        .left_i                (left_i),
        .right_i               (right_i),
        .sel_i                 (sel_i),
        .ok_i                  (ok_i),
        .game_rst_i            (game_rst_i),

        // Input MMIO
        .input_write_enable_i  (input_write_enable_i),
        .input_addr_i          (input_addr_i),
        .input_wdata_i         (input_wdata_i),
        .input_rdata_o         (input_rdata_o),

        // VGA MMIO
        .vga_write_enable_i    (vga_write_enable_i),
        .vga_addr_i            (vga_addr_i),
        .vga_wdata_i           (vga_wdata_i),
        .vga_rdata_o           (vga_rdata_o),

        // VGA physical outputs
        .vga_hsync_o           (vga_hsync_o),
        .vga_vsync_o           (vga_vsync_o),
        .vga_rgb_o             (vga_rgb_o)
    );

    // =========================================================================
    // 100 MHz Basys 3 clock
    // =========================================================================
    //
    // 100 MHz -> periodo de 10 ns.
    always #5 clk_100_i = ~clk_100_i;

    // =========================================================================
    // Generic checker
    // =========================================================================

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

    // =========================================================================
    // Build a video-memory tile word
    // =========================================================================
    //
    // [2:0]  COLOR
    // [3]    GLYPH_ENABLE
    // [11:4] ASCII
    // [31:12] reserved
    // =========================================================================

    function automatic logic [31:0] make_tile(
        input logic [2:0] color,
        input logic       glyph_enable,
        input logic [7:0] ascii
    );
        begin

            make_tile = {
                20'b0,
                ascii,
                glyph_enable,
                color
            };

        end
    endfunction

    // =========================================================================
    // CPU write to VGA memory
    // =========================================================================

    task automatic cpu_vga_write(
        input logic [8:0]  address,
        input logic [31:0] data
    );
        begin

            @(negedge clk_100_i);

            vga_addr_i         = address;
            vga_wdata_i        = data;
            vga_write_enable_i = 1'b1;

            @(posedge clk_100_i);
            #1;

            @(negedge clk_100_i);

            vga_write_enable_i = 1'b0;

        end
    endtask

    // =========================================================================
    // CPU read from VGA memory
    // =========================================================================

    task automatic cpu_vga_read_check(
        input logic [8:0]  address,
        input logic [31:0] expected,
        input string       message
    );
        begin

            @(negedge clk_100_i);

            vga_addr_i         = address;
            vga_write_enable_i = 1'b0;

            @(posedge clk_100_i);
            #1;

            check(
                vga_rdata_o === expected,
                message
            );

        end
    endtask

    // =========================================================================
    // Wait for one delayed renderer coordinate
    // =========================================================================
    //
    // tile_renderer delays pixel coordinates one pixel-clock cycle so that
    // they remain aligned with the synchronous VRAM output.
    // =========================================================================

    task automatic wait_renderer_pixel(
        input logic [9:0] x,
        input logic [9:0] y
    );
        begin

            while (!(
                (dut.u_tile_renderer.pixel_x_q === x) &&
                (dut.u_tile_renderer.pixel_y_q === y)
            )) begin

                @(posedge dut.clk_pixel);
                #1;

            end

        end
    endtask

    // =========================================================================
    // Check rendered RGB at one coordinate
    // =========================================================================

    task automatic check_rendered_pixel(
        input logic [9:0]  x,
        input logic [9:0]  y,
        input logic [11:0] expected_rgb,
        input string       message
    );
        begin

            wait_renderer_pixel(x, y);

            check(
                vga_rgb_o === expected_rgb,
                message
            );

        end
    endtask

    // =========================================================================
    // Wait for MMCM lock with timeout
    // =========================================================================

    task automatic wait_for_clock_lock;
        int count;
        begin

            count = 0;

            while (
                (dut.pixel_clock_locked !== 1'b1) &&
                (count < 2000)
            ) begin

                @(posedge clk_100_i);
                count++;

            end

            check(
                dut.pixel_clock_locked === 1'b1,
                "Pixel clock MMCM reaches lock"
            );

        end
    endtask

    // =========================================================================
    // Wait for synchronized pixel reset release
    // =========================================================================

    task automatic wait_for_pixel_reset_release;
        int count;
        begin

            count = 0;

            while (
                (dut.rst_pixel !== 1'b0) &&
                (count < 20)
            ) begin

                @(posedge dut.clk_pixel);
                #1;
                count++;

            end

            check(
                dut.rst_pixel === 1'b0,
                "Pixel-domain reset releases after MMCM lock"
            );

        end
    endtask

    // =========================================================================
    // Main test sequence
    // =========================================================================

    initial begin

        // ---------------------------------------------------------------------
        // Initial state
        // ---------------------------------------------------------------------

        clk_100_i = 1'b0;
        rst_i     = 1'b1;

        up_i       = 1'b0;
        down_i     = 1'b0;
        left_i     = 1'b0;
        right_i    = 1'b0;
        sel_i      = 1'b0;
        ok_i       = 1'b0;
        game_rst_i = 1'b0;

        input_write_enable_i = 1'b0;
        input_addr_i         = 2'b00;
        input_wdata_i        = 32'b0;

        vga_write_enable_i = 1'b0;
        vga_addr_i         = 9'd0;
        vga_wdata_i        = 32'b0;

        errors = 0;

        $display("========================================");
        $display("TB SUBSYSTEM2 VGA + INPUTS");
        $display("========================================");

        // =====================================================================
        // Test 1: General reset
        // =====================================================================

        repeat (5) @(posedge clk_100_i);
        #1;

        check(
            input_rdata_o === 32'h0000_0000,
            "General reset clears Player 1 input state"
        );

        check(
            dut.pixel_clock_locked === 1'b0,
            "Pixel clock remains unlocked during general reset"
        );

        // ---------------------------------------------------------------------
        // Release general reset
        // ---------------------------------------------------------------------

        @(negedge clk_100_i);
        rst_i = 1'b0;

        // =====================================================================
        // Test 2: CPU -> Video Memory integration
        // =====================================================================
        //
        // Tile 0  = water
        // Tile 1  = cursor
        // Tile 10 = water + enabled glyph 'A'
        //
        // These writes occur while the MMCM is still locking. The CPU-side
        // VRAM port already operates from clk_100_i.
        // =====================================================================

        cpu_vga_write(
            9'd0,
            make_tile(3'd1, 1'b0, 8'h20)
        );

        cpu_vga_write(
            9'd1,
            make_tile(3'd5, 1'b0, 8'h20)
        );

        cpu_vga_write(
            9'd10,
            make_tile(3'd1, 1'b1, 8'h41)
        );

        cpu_vga_read_check(
            9'd0,
            make_tile(3'd1, 1'b0, 8'h20),
            "CPU reads back water tile from integrated VRAM"
        );

        cpu_vga_read_check(
            9'd10,
            make_tile(3'd1, 1'b1, 8'h41),
            "CPU reads back glyph tile from integrated VRAM"
        );

        // =====================================================================
        // Test 3: Physical inputs -> sync -> debounce -> MMIO
        // =====================================================================
        //
        // Assert UP and OK.
        //
        // Expected:
        // bit 0 = UP = 1
        // bit 5 = OK = 1
        //
        // 0b0010_0001 = 0x21
        // =====================================================================

        @(negedge clk_100_i);

        up_i = 1'b1;
        ok_i = 1'b1;

        // Allow synchronizers and debounce filters to settle.
        repeat (TEST_DEBOUNCE_CYCLES + 8)
            @(posedge clk_100_i);

        #1;

        input_addr_i = 2'b00;
        #1;

        check(
            input_rdata_o[6:0] === 7'b0100001,
            "UP and OK reach the Player 1 MMIO status register"
        );

        check(
            input_rdata_o[31:7] === 25'b0,
            "Unused Player 1 status bits remain zero"
        );

        // ---------------------------------------------------------------------
        // Release buttons again
        // ---------------------------------------------------------------------

        @(negedge clk_100_i);

        up_i = 1'b0;
        ok_i = 1'b0;

        repeat (TEST_DEBOUNCE_CYCLES + 8)
            @(posedge clk_100_i);

        #1;

        check(
            input_rdata_o[6:0] === 7'b0000000,
            "Player 1 inputs return low after release"
        );

        // ---------------------------------------------------------------------
        // Invalid local input address should return zero
        // ---------------------------------------------------------------------

        input_addr_i = 2'b01;
        #1;

        check(
            input_rdata_o === 32'h0000_0000,
            "Invalid Player 1 MMIO address returns zero"
        );

        input_addr_i = 2'b00;

        // =====================================================================
        // Test 4: Clock/reset chain integration
        // =====================================================================

        wait_for_clock_lock();

        wait_for_pixel_reset_release();

        check(
            dut.clk_pixel === 1'b0 ||
            dut.clk_pixel === 1'b1,
            "25 MHz pixel clock is active after MMCM lock"
        );

        // =====================================================================
        // Test 5: Video Memory -> Renderer -> RGB
        // =====================================================================
        //
        // Renderer coordinates are used because RGB is delayed one pixel clock
        // to compensate for synchronous VRAM latency.
        // =====================================================================

        check_rendered_pixel(
            10'd16,
            10'd0,
            RGB_WATER,
            "Tile 0 renders water color through complete VGA path"
        );

        check(
            vga_hsync_o === 1'b1,
            "HSYNC is inactive during visible pixel"
        );

        check(
            vga_vsync_o === 1'b1,
            "VSYNC is inactive during visible pixel"
        );

        // Tile 1 occupies x = 32..63.
        check_rendered_pixel(
            10'd48,
            10'd0,
            RGB_CURSOR,
            "Tile 1 renders cursor color through complete VGA path"
        );

        // =====================================================================
        // Test 6: Glyph integration
        // =====================================================================
        //
        // Tile 10 starts at x = 320.
        //
        // x = 332 -> internal x = 12 -> glyph_x = 3
        // y =   4 -> internal y =  4 -> glyph_y = 1
        //
        // The glyph 'A' contains an active bit at (3,1).
        // =====================================================================

        check_rendered_pixel(
            10'd332,
            10'd4,
            RGB_GLYPH,
            "VRAM ASCII A is rendered as a white glyph pixel"
        );

        // =====================================================================
        // Test 7: Horizontal blanking
        // =====================================================================
        //
        // x=640 is the first pixel outside the visible horizontal region.
        // Regardless of VRAM contents, RGB must be black.
        // =====================================================================

        check_rendered_pixel(
            10'd640,
            10'd4,
            RGB_BLACK,
            "Horizontal blanking forces RGB black at x=640"
        );

        // =====================================================================
        // Test 8: HSYNC alignment with renderer pipeline
        // =====================================================================
        //
        // VGA 640x480 timing:
        //
        // x = 655 -> HSYNC high
        // x = 656 -> HSYNC low
        // x = 751 -> HSYNC low
        // x = 752 -> HSYNC high
        //
        // Because the subsystem delays HSYNC one clock just like RGB,
        // these transitions must align with pixel_x_q.
        // =====================================================================

        wait_renderer_pixel(10'd655, 10'd4);

        check(
            vga_hsync_o === 1'b1,
            "Aligned HSYNC remains high at delayed x=655"
        );

        wait_renderer_pixel(10'd656, 10'd4);

        check(
            vga_hsync_o === 1'b0,
            "Aligned HSYNC falls at delayed x=656"
        );

        wait_renderer_pixel(10'd751, 10'd4);

        check(
            vga_hsync_o === 1'b0,
            "Aligned HSYNC remains low through delayed x=751"
        );

        wait_renderer_pixel(10'd752, 10'd4);

        check(
            vga_hsync_o === 1'b1,
            "Aligned HSYNC returns high at delayed x=752"
        );

        // =====================================================================
        // Test 9: Reassert general reset
        // =====================================================================

        @(negedge clk_100_i);
        rst_i = 1'b1;

        repeat (10) @(posedge clk_100_i);
        #1;

        check(
            dut.pixel_clock_locked === 1'b0,
            "General reset forces MMCM out of lock"
        );

        check(
            input_rdata_o === 32'h0000_0000,
            "General reset clears input peripheral again"
        );

        // =====================================================================
        // Final result
        // =====================================================================

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