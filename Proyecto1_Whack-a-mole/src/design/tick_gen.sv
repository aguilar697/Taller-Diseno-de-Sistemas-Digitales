`timescale 1ns / 1ps

module tick_gen #(
    parameter int CLK_FREQ = 100_000_000,
    parameter int TICK_HZ  = 1_000
)(
    input  logic clk,
    input  logic reset,

    output logic tick
);

    // Cantidad de ciclos de clk necesarios para producir un tick
    localparam int CLKS_PER_TICK = CLK_FREQ / TICK_HZ;

    // Número mínimo de bits requerido para el contador
    localparam int COUNT_WIDTH =
        (CLKS_PER_TICK <= 1) ? 1 : $clog2(CLKS_PER_TICK);

    logic [COUNT_WIDTH-1:0] counter;


    always_ff @(posedge clk) begin

        if (reset) begin

            counter <= '0;
            tick    <= 1'b0;

        end
        else begin

            if (counter == CLKS_PER_TICK - 1) begin

                counter <= '0;
                tick    <= 1'b1;

            end
            else begin

                counter <= counter + 1'b1;
                tick    <= 1'b0;

            end

        end

    end

endmodule