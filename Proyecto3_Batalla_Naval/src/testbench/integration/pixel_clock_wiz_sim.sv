`timescale 1ns / 1ps

// Modelo de simulacion del IP Clocking Wizard pixel_clock_wiz.
//
// Solo para simulacion funcional: en sintesis se usa el IP real
// (src/design/vga/ip/pixel_clock_wiz.xci). Divide los 100 MHz entre 4 para
// obtener 25 MHz y activa locked despues de unos ciclos, como el MMCM.
module pixel_clock_wiz (
    input  logic clk_in1,
    input  logic reset,
    output logic clk_out1,
    output logic locked
);

    logic [1:0] divider_q = 2'd0;
    logic [3:0] lock_count_q = 4'd0;

    always_ff @(posedge clk_in1) begin
        if (reset) begin
            divider_q    <= 2'd0;
            lock_count_q <= 4'd0;
        end else begin
            divider_q <= divider_q + 1'b1;
            if (lock_count_q != 4'hF) begin
                lock_count_q <= lock_count_q + 1'b1;
            end
        end
    end

    assign clk_out1 = divider_q[1];
    assign locked   = (lock_count_q == 4'hF);

endmodule
