module button_conditioner #(
    parameter int unsigned DEBOUNCE_CYCLES = 2_000_000
)(
    input  logic clk_i,
    input  logic rst_sync,
    input  logic btn_i,
    output logic btn_pulse
);

    // ------------------------------------------------------------
    // Ancho del contador de debounce
    // ------------------------------------------------------------
    localparam int unsigned COUNTER_WIDTH =
        (DEBOUNCE_CYCLES <= 1) ? 1 : $clog2(DEBOUNCE_CYCLES);

    // ------------------------------------------------------------
    // Sincronizador de dos etapas
    // ------------------------------------------------------------
    (* ASYNC_REG = "TRUE" *)
    logic btn_meta;
    (* ASYNC_REG = "TRUE" *)
    logic btn_sync;

    // ------------------------------------------------------------
    // Señales del debounce
    // ------------------------------------------------------------
    logic debounced_state;
    logic [COUNTER_WIDTH-1:0] debounce_counter;

    // Estado anterior para detección de flanco
    logic debounced_state_d;


    // ============================================================
    // 1. SINCRONIZACIÓN DEL BOTÓN
    // ============================================================
    always_ff @(posedge clk_i or posedge rst_sync) begin
        if (rst_sync) begin
            btn_meta <= 1'b0;
            btn_sync <= 1'b0;
        end
        else begin
            btn_meta <= btn_i;
            btn_sync <= btn_meta;
        end
    end


    // ============================================================
    // 2. DEBOUNCE
    // ============================================================
    always_ff @(posedge clk_i or posedge rst_sync) begin
        if (rst_sync) begin
            debounce_counter <= '0;
            debounced_state  <= 1'b0;
        end
        else begin

            // Si la entrada sincronizada coincide con el estado
            // aceptado, no existe un cambio pendiente.
            if (btn_sync == debounced_state) begin
                debounce_counter <= '0;
            end

            // Si cambió, debe permanecer estable durante
            // DEBOUNCE_CYCLES ciclos consecutivos.
            else begin

                if (DEBOUNCE_CYCLES <= 1) begin
                    debounced_state  <= btn_sync;
                    debounce_counter <= '0;
                end

                else if (debounce_counter == DEBOUNCE_CYCLES - 1) begin
                    debounced_state  <= btn_sync;
                    debounce_counter <= '0;
                end

                else begin
                    debounce_counter <= debounce_counter + 1'b1;
                end
            end
        end
    end


    // ============================================================
    // 3. GENERACIÓN DEL PULSO
    // ============================================================
    always_ff @(posedge clk_i or posedge rst_sync) begin
        if (rst_sync) begin
            debounced_state_d <= 1'b0;
            btn_pulse         <= 1'b0;
        end
        else begin
            btn_pulse         <= debounced_state & ~debounced_state_d;
            debounced_state_d <= debounced_state;
        end
    end

endmodule