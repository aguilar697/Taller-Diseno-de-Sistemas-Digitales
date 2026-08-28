`timescale 1ns / 1ps

module buttons_frontend #(
    parameter int DEBOUNCE_TICKS = 20
)(
    input  logic       clk,
    input  logic       reset,
    input  logic       tick_1ms,

    input  logic [7:0] buttons_in,

    output logic [7:0] buttons_level,
    output logic [7:0] press_pulse
);

    //---------------------------------------------------------
    // Se crean automáticamente 8 acondicionadores,
    // uno para cada botón externo.
    //---------------------------------------------------------

    genvar i;

    generate

        for (i = 0; i < 8; i = i + 1) begin : GEN_BUTTONS

            button_conditioner #(
                .DEBOUNCE_TICKS(DEBOUNCE_TICKS)
            ) button_inst (
                .clk          (clk),
                .reset        (reset),
                .tick_1ms     (tick_1ms),

                .button_in    (buttons_in[i]),

                .button_level (buttons_level[i]),
                .press_pulse  (press_pulse[i])
            );

        end

    endgenerate

endmodule