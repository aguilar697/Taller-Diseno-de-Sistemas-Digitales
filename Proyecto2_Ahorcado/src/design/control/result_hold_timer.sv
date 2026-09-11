module result_hold_timer #(
    parameter int unsigned CLK_HZ       = 100_000_000,
    parameter int unsigned HOLD_SECONDS = 3
)(
    input  logic clk_i,
    input  logic rst_sync,
    input  logic start,

    output logic result_hold_done
);

    // Cantidad total de ciclos necesarios para cumplir
    // el tiempo de retención.
    localparam int unsigned HOLD_CYCLES =
        CLK_HZ * HOLD_SECONDS;

    // Ancho mínimo necesario para el contador.
    localparam int unsigned COUNTER_WIDTH =
        (HOLD_CYCLES <= 1) ? 1 : $clog2(HOLD_CYCLES);

    logic [COUNTER_WIDTH-1:0] hold_counter;
    logic active;


    always_ff @(posedge clk_i or posedge rst_sync) begin

        if (rst_sync) begin
            hold_counter     <= '0;
            active           <= 1'b0;
            result_hold_done <= 1'b0;
        end

        // start inicia o reinicia la retención del resultado.
        else if (start) begin
            hold_counter     <= '0;
            active           <= 1'b1;
            result_hold_done <= 1'b0;
        end

        // Temporización activa.
        else if (active) begin

            if (hold_counter == HOLD_CYCLES - 1) begin
                hold_counter     <= hold_counter;
                active           <= 1'b0;
                result_hold_done <= 1'b1;
            end
            else begin
                hold_counter <= hold_counter + 1'b1;
            end

        end

        // Cuando termina, result_hold_done permanece en 1
        // hasta un nuevo start o un reset.
    end

endmodule