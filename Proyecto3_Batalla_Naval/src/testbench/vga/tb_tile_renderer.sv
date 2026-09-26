`timescale 1ns / 1ps

module tb_tile_renderer;

    // -------------------------------------------------------------------------
    // Expected palette
    // -------------------------------------------------------------------------

    localparam logic [11:0] RGB_BACKGROUND = 12'h000;
    localparam logic [11:0] RGB_WATER      = 12'h04F;
    localparam logic [11:0] RGB_SHIP       = 12'h888;
    localparam logic [11:0] RGB_HIT        = 12'hF00;
    localparam logic [11:0] RGB_MISS       = 12'hFFF;
    localparam logic [11:0] RGB_CURSOR     = 12'hFF0;
    localparam logic [11:0] RGB_HUD        = 12'h0F8;
    localparam logic [11:0] RGB_GLYPH      = 12'hFFF;

    // -------------------------------------------------------------------------
    // CPU / VRAM signals
    // -------------------------------------------------------------------------

    logic        clk_100_i;
    logic        rst_i;

    logic        vga_write_enable_i;
    logic [8:0]  vga_addr_i;
    logic [31:0] vga_wdata_i;
    logic [31:0] vga_rdata_o;

    // -------------------------------------------------------------------------
    // Pixel domain
    // -------------------------------------------------------------------------

    logic        clk_pixel_i;
    logic        rst_pixel_i;

    logic [9:0]  pixel_x_i;
    logic [9:0]  pixel_y_i;
    logic        active_video_i;

    logic [8:0]  tile_addr_o;
    logic [31:0] tile_word;

    logic [11:0] vga_rgb_o;

    int errors;

    // -------------------------------------------------------------------------
    // Video memory
    // -------------------------------------------------------------------------

    video_memory u_video_memory (
        .clk_100_i          (clk_100_i),
        .rst_i              (rst_i),
        .vga_write_enable_i (vga_write_enable_i),
        .vga_addr_i         (vga_addr_i),
        .vga_wdata_i        (vga_wdata_i),
        .vga_rdata_o        (vga_rdata_o),

        .clk_pixel_i        (clk_pixel_i),
        .tile_addr_i        (tile_addr_o),
        .tile_word_o        (tile_word)
    );

    // -------------------------------------------------------------------------
    // Renderer
    // -------------------------------------------------------------------------

    tile_renderer dut (
        .clk_pixel_i   (clk_pixel_i),
        .rst_pixel_i   (rst_pixel_i),

        .pixel_x_i     (pixel_x_i),
        .pixel_y_i     (pixel_y_i),
        .active_video_i(active_video_i),

        .tile_addr_o   (tile_addr_o),
        .tile_word_i   (tile_word),

        .vga_rgb_o     (vga_rgb_o)
    );

    // -------------------------------------------------------------------------
    // Clocks
    // -------------------------------------------------------------------------

    // 100 MHz
    always #5 clk_100_i = ~clk_100_i;

    // 25 MHz
    always #20 clk_pixel_i = ~clk_pixel_i;

    // -------------------------------------------------------------------------
    // Tile word construction
    // -------------------------------------------------------------------------

    function automatic logic [31:0] make_tile(
        input logic [2:0] color,
        input logic       glyph_enable,
        input logic [7:0] ascii
    );

        make_tile = {
            20'b0,
            ascii,
            glyph_enable,
            color
        };

    endfunction

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
    // CPU write helper
    // -------------------------------------------------------------------------

    task automatic cpu_write(
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

    // -------------------------------------------------------------------------
    // Tile address checker
    // -------------------------------------------------------------------------

    task automatic check_tile_address(
        input int unsigned x,
        input int unsigned y,
        input logic [8:0] expected_address,
        input string message
    );
        begin

            @(negedge clk_pixel_i);

            pixel_x_i      = x;
            pixel_y_i      = y;
            active_video_i = 1'b1;

            #1;

            check(
                tile_addr_o === expected_address,
                message
            );

        end
    endtask

    // -------------------------------------------------------------------------
    // Render one pixel
    // -------------------------------------------------------------------------

    task automatic render_check(
        input int unsigned x,
        input int unsigned y,
        input logic        active,
        input logic [8:0]  expected_address,
        input logic [11:0] expected_rgb,
        input string       message
    );
        begin

            // Change coordinates away from the active clock edge.
            @(negedge clk_pixel_i);

            pixel_x_i      = x;
            pixel_y_i      = y;
            active_video_i = active;

            #1;

            check(
                tile_addr_o === expected_address,
                $sformatf("%s - tile address", message)
            );

            // At this edge the VRAM reads tile_addr_o and the renderer
            // stores the corresponding pixel coordinates.
            @(posedge clk_pixel_i);
            #1;

            check(
                vga_rgb_o === expected_rgb,
                message
            );

        end
    endtask

    // -------------------------------------------------------------------------
    // Test sequence
    // -------------------------------------------------------------------------

    initial begin

        clk_100_i          = 1'b0;
        rst_i              = 1'b1;

        vga_write_enable_i = 1'b0;
        vga_addr_i         = 9'd0;
        vga_wdata_i        = 32'b0;

        clk_pixel_i        = 1'b0;
        rst_pixel_i        = 1'b1;

        pixel_x_i          = 10'd0;
        pixel_y_i          = 10'd0;
        active_video_i     = 1'b0;

        errors             = 0;

        $display("========================================");
        $display("TB TILE_RENDERER");
        $display("========================================");

        // ---------------------------------------------------------------------
        // Test 1: Renderer reset
        // ---------------------------------------------------------------------

        repeat (2) @(posedge clk_pixel_i);
        #1;

        check(
            vga_rgb_o === RGB_BACKGROUND,
            "Reset forces black video output"
        );

        @(negedge clk_100_i);
        rst_i = 1'b0;

        @(negedge clk_pixel_i);
        rst_pixel_i = 1'b0;

        // ---------------------------------------------------------------------
        // Initialize tiles through the real CPU port of video_memory
        // ---------------------------------------------------------------------

        cpu_write(
            9'd0,
            make_tile(3'd0, 1'b0, 8'h20)
        );

        cpu_write(
            9'd1,
            make_tile(3'd1, 1'b0, 8'h20)
        );

        cpu_write(
            9'd2,
            make_tile(3'd2, 1'b0, 8'h20)
        );

        cpu_write(
            9'd3,
            make_tile(3'd3, 1'b0, 8'h20)
        );

        cpu_write(
            9'd4,
            make_tile(3'd4, 1'b0, 8'h20)
        );

        cpu_write(
            9'd5,
            make_tile(3'd5, 1'b0, 8'h20)
        );

        cpu_write(
            9'd6,
            make_tile(3'd6, 1'b0, 8'h20)
        );

        cpu_write(
            9'd7,
            make_tile(3'd7, 1'b0, 8'h20)
        );

        // Tile 10:
        // fondo agua + glyph habilitado + ASCII 'A'
        cpu_write(
            9'd10,
            make_tile(3'd1, 1'b1, 8'h41)
        );

        // Tile 11:
        // cursor + ASCII 'A', pero glyph deshabilitado
        cpu_write(
            9'd11,
            make_tile(3'd5, 1'b0, 8'h41)
        );

        // ---------------------------------------------------------------------
        // Test 2: Pixel -> tile mapping
        // ---------------------------------------------------------------------

        check_tile_address(
            0, 0,
            9'd0,
            "Coordinate (0,0) maps to tile 0"
        );

        check_tile_address(
            31, 31,
            9'd0,
            "Coordinate (31,31) remains in tile 0"
        );

        check_tile_address(
            32, 0,
            9'd1,
            "Coordinate (32,0) maps to tile 1"
        );

        check_tile_address(
            0, 32,
            9'd20,
            "Coordinate (0,32) maps to tile 20"
        );

        check_tile_address(
            100, 70,
            9'd43,
            "Coordinate (100,70) maps to tile 43"
        );

        check_tile_address(
            639, 479,
            9'd299,
            "Last visible pixel maps to tile 299"
        );

        // ---------------------------------------------------------------------
        // Test 3: Palette colors
        // ---------------------------------------------------------------------

        render_check(
            16, 16, 1'b1,
            9'd0,
            RGB_BACKGROUND,
            "Background color"
        );

        render_check(
            48, 16, 1'b1,
            9'd1,
            RGB_WATER,
            "Water color"
        );

        render_check(
            80, 16, 1'b1,
            9'd2,
            RGB_SHIP,
            "Own ship color"
        );

        render_check(
            112, 16, 1'b1,
            9'd3,
            RGB_HIT,
            "Hit color"
        );

        render_check(
            144, 16, 1'b1,
            9'd4,
            RGB_MISS,
            "Miss color"
        );

        render_check(
            176, 16, 1'b1,
            9'd5,
            RGB_CURSOR,
            "Cursor color"
        );

        render_check(
            208, 16, 1'b1,
            9'd6,
            RGB_HUD,
            "HUD color"
        );

        render_check(
            240, 16, 1'b1,
            9'd7,
            RGB_BACKGROUND,
            "Reserved color code renders black"
        );

        // ---------------------------------------------------------------------
        // Test 4: Glyph rendering
        // ---------------------------------------------------------------------
        //
        // Tile 10 begins at x = 10 * 32 = 320.
        //
        // Character A has an active bit at:
        // glyph_x = 3, glyph_y = 1
        //
        // glyph_x=3 corresponds to physical x 12..15 inside the tile.
        // glyph_y=1 corresponds to physical y 4..7.

        render_check(
            332, 4, 1'b1,
            9'd10,
            RGB_GLYPH,
            "Enabled glyph draws white pixel"
        );

        // Same logical glyph pixel, another physical point of its 4x4 block.
        render_check(
            335, 7, 1'b1,
            9'd10,
            RGB_GLYPH,
            "Glyph pixel expands to 4x4 block"
        );

        // glyph_x=0, glyph_y=1 is blank for character A.
        render_check(
            320, 4, 1'b1,
            9'd10,
            RGB_WATER,
            "Glyph background keeps tile base color"
        );

        // ---------------------------------------------------------------------
        // Test 5: GLYPH_ENABLE must control text rendering
        // ---------------------------------------------------------------------

        render_check(
            364, 4, 1'b1,
            9'd11,
            RGB_CURSOR,
            "Disabled glyph does not modify base color"
        );

        // ---------------------------------------------------------------------
        // Test 6: Inactive video must be black
        // ---------------------------------------------------------------------

        render_check(
            332, 4, 1'b0,
            9'd0,
            RGB_BACKGROUND,
            "Inactive video forces black output"
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