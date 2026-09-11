`timescale 1ns/1ps

module reset_sync_tb;

    logic clk_i;
    logic btn_rst_i;
    logic rst_sync;

    // Clock de 100 MHz: periodo de 10 ns.
    initial begin
        clk_i = 1'b0;
        forever #5 clk_i = ~clk_i;
    end

    reset_sync dut (
        .clk_i     (clk_i),
        .btn_rst_i (btn_rst_i),
        .rst_sync  (rst_sync)
    );

    initial begin
        btn_rst_i = 1'b0;

        #2;
        btn_rst_i = 1'b1;

        #8;
        btn_rst_i = 1'b0;

        @(posedge clk_i);
        @(posedge clk_i);

        #7;
        btn_rst_i = 1'b1;

        #4;
        btn_rst_i = 1'b0;

        @(posedge clk_i);
        @(posedge clk_i);

        #20;

        $finish;
    end

endmodule