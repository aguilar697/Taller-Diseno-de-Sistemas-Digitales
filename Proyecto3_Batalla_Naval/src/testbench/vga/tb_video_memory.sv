`timescale 1ns / 1ps

module tb_video_memory;

    // -------------------------------------------------------------------------
    // Testbench signals
    // -------------------------------------------------------------------------

    logic        clk_100_i;
    logic        rst_i;
    logic        vga_write_enable_i;
    logic [8:0]  vga_addr_i;
    logic [31:0] vga_wdata_i;
    logic [31:0] vga_rdata_o;

    logic        clk_pixel_i;
    logic [8:0]  tile_addr_i;
    logic [31:0] tile_word_o;

    int errors;

    // -------------------------------------------------------------------------
    // Device Under Test
    // -------------------------------------------------------------------------

    video_memory dut (
        .clk_100_i         (clk_100_i),
        .rst_i             (rst_i),
        .vga_write_enable_i(vga_write_enable_i),
        .vga_addr_i        (vga_addr_i),
        .vga_wdata_i       (vga_wdata_i),
        .vga_rdata_o       (vga_rdata_o),

        .clk_pixel_i       (clk_pixel_i),
        .tile_addr_i       (tile_addr_i),
        .tile_word_o       (tile_word_o)
    );

    // -------------------------------------------------------------------------
    // Clocks
    // -------------------------------------------------------------------------
    // CPU clock: 100 MHz -> periodo de 10 ns.
    always #5 clk_100_i = ~clk_100_i;

    // VGA pixel clock: 25 MHz -> periodo de 40 ns.
    always #20 clk_pixel_i = ~clk_pixel_i;

    // -------------------------------------------------------------------------
    // Helper: check result
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
    // Helper: CPU write
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
    // Helper: CPU read
    // -------------------------------------------------------------------------

    task automatic cpu_read_check(
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

            check(vga_rdata_o === expected, message);
        end
    endtask

    // -------------------------------------------------------------------------
    // Helper: VGA read
    // -------------------------------------------------------------------------

    task automatic vga_read_check(
        input logic [8:0]  address,
        input logic [31:0] expected,
        input string       message
    );
        begin
            @(negedge clk_pixel_i);
            tile_addr_i = address;

            @(posedge clk_pixel_i);
            #1;

            check(tile_word_o === expected, message);
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
        tile_addr_i        = 9'd0;

        errors             = 0;

        $display("========================================");
        $display("TB VIDEO_MEMORY");
        $display("========================================");

        // ---------------------------------------------------------------------
        // Test 1: CPU output reset
        // ---------------------------------------------------------------------

        repeat (2) @(posedge clk_100_i);
        #1;

        check(
            vga_rdata_o === 32'h0000_0000,
            "CPU read output reset"
        );

        @(negedge clk_100_i);
        rst_i = 1'b0;

        // ---------------------------------------------------------------------
        // Test 2: Write/read first visible location
        // ---------------------------------------------------------------------

        cpu_write(
            9'd0,
            32'h1234_5678
        );

        cpu_read_check(
            9'd0,
            32'h1234_5678,
            "CPU write/read index 0"
        );

        // ---------------------------------------------------------------------
        // Test 3: Write/read an intermediate visible location
        // ---------------------------------------------------------------------

        cpu_write(
            9'd125,
            32'hCAFE_BABE
        );

        cpu_read_check(
            9'd125,
            32'hCAFE_BABE,
            "CPU write/read index 125"
        );

        // ---------------------------------------------------------------------
        // Test 4: Last visible tile
        // ---------------------------------------------------------------------

        cpu_write(
            9'd299,
            32'hA5A5_5A5A
        );

        cpu_read_check(
            9'd299,
            32'hA5A5_5A5A,
            "CPU write/read last visible index 299"
        );

        // ---------------------------------------------------------------------
        // Test 5: VGA port reads data written by CPU
        // ---------------------------------------------------------------------

        vga_read_check(
            9'd0,
            32'h1234_5678,
            "VGA reads index 0"
        );

        vga_read_check(
            9'd125,
            32'hCAFE_BABE,
            "VGA reads index 125"
        );

        vga_read_check(
            9'd299,
            32'hA5A5_5A5A,
            "VGA reads index 299"
        );

        // ---------------------------------------------------------------------
        // Test 6: First reserved index must read zero
        // ---------------------------------------------------------------------

        cpu_read_check(
            9'd300,
            32'h0000_0000,
            "CPU reserved index 300 returns zero"
        );

        vga_read_check(
            9'd300,
            32'h0000_0000,
            "VGA reserved index 300 returns zero"
        );

        // ---------------------------------------------------------------------
        // Test 7: Last reserved index must read zero
        // ---------------------------------------------------------------------

        cpu_read_check(
            9'd511,
            32'h0000_0000,
            "CPU reserved index 511 returns zero"
        );

        vga_read_check(
            9'd511,
            32'h0000_0000,
            "VGA reserved index 511 returns zero"
        );

        // ---------------------------------------------------------------------
        // Test 8: Reserved writes must be ignored
        // ---------------------------------------------------------------------

        cpu_write(
            9'd300,
            32'hFFFF_FFFF
        );

        cpu_read_check(
            9'd300,
            32'h0000_0000,
            "CPU write to reserved index 300 ignored"
        );

        vga_read_check(
            9'd300,
            32'h0000_0000,
            "Reserved write invisible from VGA port"
        );

        // ---------------------------------------------------------------------
        // Test 9: Reserved write must not corrupt visible memory
        // ---------------------------------------------------------------------

        cpu_read_check(
            9'd299,
            32'hA5A5_5A5A,
            "Reserved access does not corrupt index 299"
        );

        // ---------------------------------------------------------------------
        // Test 10: Both ports observe same stored word
        // ---------------------------------------------------------------------

        cpu_write(
            9'd42,
            32'hDEAD_BEEF
        );

        cpu_read_check(
            9'd42,
            32'hDEAD_BEEF,
            "CPU reads shared VRAM word"
        );

        vga_read_check(
            9'd42,
            32'hDEAD_BEEF,
            "VGA reads same shared VRAM word"
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