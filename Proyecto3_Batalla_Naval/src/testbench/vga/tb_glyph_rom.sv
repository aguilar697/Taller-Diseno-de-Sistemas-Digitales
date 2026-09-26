`timescale 1ns / 1ps

module tb_glyph_rom;

    // -------------------------------------------------------------------------
    // Testbench signals
    // -------------------------------------------------------------------------

    logic [7:0] ascii_i;
    logic [2:0] glyph_x_i;
    logic [2:0] glyph_y_i;
    logic       glyph_bit_o;

    int errors;
    int pixel_count;

    // -------------------------------------------------------------------------
    // Device Under Test
    // -------------------------------------------------------------------------

    glyph_rom dut (
        .ascii_i    (ascii_i),
        .glyph_x_i  (glyph_x_i),
        .glyph_y_i  (glyph_y_i),
        .glyph_bit_o(glyph_bit_o)
    );

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
    // Pixel checker
    // -------------------------------------------------------------------------

    task automatic check_pixel(
        input logic [7:0] character,
        input logic [2:0] x,
        input logic [2:0] y,
        input logic       expected,
        input string      message
    );
        begin
            ascii_i   = character;
            glyph_x_i = x;
            glyph_y_i = y;

            #1;

            check(glyph_bit_o === expected, message);
        end
    endtask

    // -------------------------------------------------------------------------
    // Count active pixels in a glyph
    // -------------------------------------------------------------------------

    task automatic count_pixels(
        input  logic [7:0] character,
        output int         count
    );
        begin
            count   = 0;
            ascii_i = character;

            for (int y = 0; y < 8; y++) begin
                for (int x = 0; x < 8; x++) begin

                    glyph_x_i = x[2:0];
                    glyph_y_i = y[2:0];

                    #1;

                    if (glyph_bit_o)
                        count++;

                end
            end
        end
    endtask

    // -------------------------------------------------------------------------
    // Print one glyph in the simulation console
    // -------------------------------------------------------------------------

    task automatic print_glyph(
        input logic [7:0] character
    );
        begin

            ascii_i = character;

            $display("");
            $display("Glyph ASCII 0x%02h (%c)", character, character);

            for (int y = 0; y < 8; y++) begin

                for (int x = 0; x < 8; x++) begin

                    glyph_x_i = x[2:0];
                    glyph_y_i = y[2:0];

                    #1;

                    if (glyph_bit_o)
                        $write("#");
                    else
                        $write(".");

                end

                $write("\n");

            end

            $display("");

        end
    endtask

    // -------------------------------------------------------------------------
    // Test sequence
    // -------------------------------------------------------------------------

    initial begin

        ascii_i     = 8'h20;
        glyph_x_i   = 3'd0;
        glyph_y_i   = 3'd0;
        errors      = 0;
        pixel_count = 0;

        $display("========================================");
        $display("TB GLYPH_ROM");
        $display("========================================");

        // ---------------------------------------------------------------------
        // Test 1: Known pixels of character 'A'
        // ---------------------------------------------------------------------

        check_pixel(
            8'h41, 3'd3, 3'd1, 1'b1,
            "A contains active top pixel"
        );

        check_pixel(
            8'h41, 3'd0, 3'd1, 1'b0,
            "A background pixel remains clear"
        );

        check_pixel(
            8'h41, 3'd1, 3'd4, 1'b1,
            "A horizontal bar is present"
        );

        check_pixel(
            8'h41, 3'd6, 3'd4, 1'b1,
            "A horizontal bar reaches right side"
        );

        // ---------------------------------------------------------------------
        // Test 2: Known pixels of digit '0'
        // ---------------------------------------------------------------------

        check_pixel(
            8'h30, 3'd2, 3'd1, 1'b1,
            "Digit 0 top stroke"
        );

        check_pixel(
            8'h30, 3'd1, 3'd2, 1'b1,
            "Digit 0 left stroke"
        );

        check_pixel(
            8'h30, 3'd3, 3'd2, 1'b0,
            "Digit 0 interior remains clear"
        );

        // ---------------------------------------------------------------------
        // Test 3: Symbols
        // ---------------------------------------------------------------------

        check_pixel(
            8'h2D, 3'd2, 3'd4, 1'b1,
            "Hyphen is present"
        );

        check_pixel(
            8'h3A, 3'd3, 3'd2, 1'b1,
            "Colon upper dot is present"
        );

        check_pixel(
            8'h3A, 3'd3, 3'd5, 1'b1,
            "Colon lower dot is present"
        );

        check_pixel(
            8'h2E, 3'd3, 3'd6, 1'b1,
            "Period is present"
        );

        // ---------------------------------------------------------------------
        // Test 4: Space must be completely blank
        // ---------------------------------------------------------------------

        count_pixels(8'h20, pixel_count);

        check(
            pixel_count == 0,
            "Space contains no active pixels"
        );

        // ---------------------------------------------------------------------
        // Test 5: Unsupported characters must behave as space
        // ---------------------------------------------------------------------

        count_pixels(8'h61, pixel_count); // lowercase 'a'

        check(
            pixel_count == 0,
            "Unsupported lowercase character renders blank"
        );

        count_pixels(8'h40, pixel_count); // '@'

        check(
            pixel_count == 0,
            "Unsupported symbol renders blank"
        );

        // ---------------------------------------------------------------------
        // Test 6: Every A-Z glyph must contain visible pixels
        // ---------------------------------------------------------------------

        for (int character = 8'h41; character <= 8'h5A; character++) begin

            count_pixels(character[7:0], pixel_count);

            if (pixel_count == 0) begin
                $display(
                    "[FAIL] Letter %c contains no active pixels",
                    character
                );
                errors++;
            end

        end

        if (errors == 0)
            $display("[PASS] All A-Z glyphs contain visible pixels");

        // ---------------------------------------------------------------------
        // Test 7: Every digit 0-9 must contain visible pixels
        // ---------------------------------------------------------------------

        for (int character = 8'h30; character <= 8'h39; character++) begin

            count_pixels(character[7:0], pixel_count);

            if (pixel_count == 0) begin
                $display(
                    "[FAIL] Digit %c contains no active pixels",
                    character
                );
                errors++;
            end

        end

        if (errors == 0)
            $display("[PASS] All 0-9 glyphs contain visible pixels");

        // ---------------------------------------------------------------------
        // Visual console demonstration
        // ---------------------------------------------------------------------

        print_glyph(8'h41); // A
        print_glyph(8'h30); // 0

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