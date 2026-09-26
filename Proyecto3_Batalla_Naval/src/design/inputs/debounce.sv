module debounce #(
    parameter int unsigned DEBOUNCE_CYCLES = 1_000_000
) (
    input  logic clk_i,
    input  logic rst_i,
    input  logic sync_i,
    output logic clean_o
);

    // -------------------------------------------------------------------------
    // Counter sizing
    // -------------------------------------------------------------------------
    // El contador mide cuánto tiempo la entrada permanece diferente
    // del valor actualmente aceptado en clean_o.
    localparam int unsigned COUNTER_WIDTH =
        (DEBOUNCE_CYCLES <= 1) ? 1 : $clog2(DEBOUNCE_CYCLES);

    logic [COUNTER_WIDTH-1:0] counter_q;

    // -------------------------------------------------------------------------
    // Debounce logic
    // -------------------------------------------------------------------------
    // Si la entrada coincide con la salida estable, no hay ningún cambio
    // pendiente y el contador se reinicia.
    //
    // Si son diferentes, se cuenta cuántos ciclos consecutivos permanece
    // la entrada en ese nuevo nivel. Solo después de DEBOUNCE_CYCLES ciclos
    // se acepta el cambio y se actualiza clean_o.
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            counter_q <= '0;
            clean_o   <= 1'b0;
        end else begin
            if (sync_i == clean_o) begin
                counter_q <= '0;
            end else if (counter_q == DEBOUNCE_CYCLES - 1) begin
                clean_o   <= sync_i;
                counter_q <= '0;
            end else begin
                counter_q <= counter_q + 1'b1;
            end
        end
    end

endmodule