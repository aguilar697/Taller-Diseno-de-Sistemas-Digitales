`timescale 1ns / 1ps

module button_conditioner #(
    // Número de muestras consecutivas necesarias
    // antes de aceptar un cambio del botón.
    // Con tick_1ms, 20 significa aproximadamente 20 ms.
    parameter int DEBOUNCE_TICKS = 20
)(
    input  logic clk,
    input  logic reset,
    input  logic tick_1ms,

    input  logic button_in,

    output logic button_level,
    output logic press_pulse
);

    //---------------------------------------------------------
    // Sincronizador de dos flip-flops
    //---------------------------------------------------------

    logic sync_ff1;
    logic sync_ff2;


    //---------------------------------------------------------
    // Contador del debounce
    //---------------------------------------------------------

    localparam int COUNT_WIDTH =
        (DEBOUNCE_TICKS <= 1)
        ? 1
        : $clog2(DEBOUNCE_TICKS + 1);

    logic [COUNT_WIDTH-1:0] stable_count;


    //---------------------------------------------------------
    // Sincronización
    //---------------------------------------------------------

    always_ff @(posedge clk) begin

        if (reset) begin

            sync_ff1 <= 1'b0;
            sync_ff2 <= 1'b0;

        end
        else begin

            sync_ff1 <= button_in;
            sync_ff2 <= sync_ff1;

        end

    end


    //---------------------------------------------------------
    // Debounce + detector de flanco positivo
    //---------------------------------------------------------

    always_ff @(posedge clk) begin

        if (reset) begin

            button_level <= 1'b0;
            stable_count <= '0;
            press_pulse  <= 1'b0;

        end
        else begin

            // Por defecto no hay pulsación nueva.
            press_pulse <= 1'b0;


            // Solamente evaluamos el debounce cada 1 ms.
            if (tick_1ms) begin

                //-------------------------------------------------
                // La entrada coincide con el estado ya aceptado.
                // No existe ningún cambio pendiente.
                //-------------------------------------------------

                if (sync_ff2 == button_level) begin

                    stable_count <= '0;

                end


                //-------------------------------------------------
                // La entrada es diferente.
                // Debe mantenerse estable varios ticks.
                //-------------------------------------------------

                else begin

                    if (stable_count == DEBOUNCE_TICKS - 1) begin

                        //-------------------------------------------------
                        // Cambio aceptado
                        //-------------------------------------------------

                        button_level <= sync_ff2;
                        stable_count <= '0;


                        //-------------------------------------------------
                        // Solamente generamos pulso al pasar de 0 → 1
                        //-------------------------------------------------

                        if (sync_ff2 == 1'b1)
                            press_pulse <= 1'b1;

                    end
                    else begin

                        stable_count <= stable_count + 1'b1;

                    end

                end

            end

        end

    end

endmodule