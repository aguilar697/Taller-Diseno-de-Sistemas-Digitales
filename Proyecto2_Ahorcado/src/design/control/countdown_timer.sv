module countdown_timer #(
    parameter int unsigned CLK_HZ       = 100_000_000,
    parameter int unsigned EASY_SECONDS = 60,
    parameter int unsigned HARD_SECONDS = 45
)(
    input  logic       clk_i,
    input  logic       rst_sync,
    input  logic       difficulty,
    input  logic       load,
    input  logic       enable,

    output logic [6:0] time_remaining,
    output logic       expired
);

    // ------------------------------------------------------------
    // Cantidad de bits necesarios para contar un segundo.
    // ------------------------------------------------------------
    localparam int unsigned SEC_COUNTER_WIDTH =
        (CLK_HZ <= 1) ? 1 : $clog2(CLK_HZ);

    logic [SEC_COUNTER_WIDTH-1:0] sec_counter;


    // ------------------------------------------------------------
    // Bandera de tiempo agotado.
    // ------------------------------------------------------------
    assign expired = (time_remaining == 7'd0);


    // ------------------------------------------------------------
    // Temporizador principal
    // ------------------------------------------------------------
    always_ff @(posedge clk_i or posedge rst_sync) begin

        if (rst_sync) begin
            sec_counter     <= '0;
            time_remaining  <= 7'd0;
        end

        // La FSM solicita cargar una nueva partida.
        else if (load) begin

            sec_counter <= '0;

            if (difficulty == 1'b0)
                time_remaining <= EASY_SECONDS;
            else
                time_remaining <= HARD_SECONDS;

        end

        // Cuenta únicamente durante una partida activa.
        else if (enable) begin

            // Solo seguimos contando si todavía queda tiempo.
            if (time_remaining != 7'd0) begin

                // Se completó un segundo.
                if (sec_counter == CLK_HZ - 1) begin

                    sec_counter    <= '0;
                    time_remaining <= time_remaining - 1'b1;

                end
                else begin
                    sec_counter <= sec_counter + 1'b1;
                end

            end
            else begin
                sec_counter <= '0;
            end

        end

        // enable = 0:
        // se conserva tanto el tiempo como la fracción de segundo.
    end

endmodule