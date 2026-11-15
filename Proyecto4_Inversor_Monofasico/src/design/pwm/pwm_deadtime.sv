`timescale 1ns / 1ps
// Una instancia por rama. Todo cambio de interruptor pasa por ambas salidas bajas.
module pwm_deadtime (
    input  logic clk, aresetn,
    input  logic enable_i, raw_high_i,
    input  logic [31:0] deadtime_i,
    output logic high_o, low_o
);
    typedef enum logic [2:0] {APAGADO, SINCRONIZAR, ESPERA, SUPERIOR, INFERIOR} state_t;
    state_t state_q;
    logic target_q;
    logic [31:0] remaining_q;

    always_ff @(posedge clk or negedge aresetn) begin
        if (!aresetn) begin
            state_q <= APAGADO;
            high_o <= 0; low_o <= 0;
            target_q <= 0; remaining_q <= 0;
        end else if (!enable_i) begin
            state_q <= APAGADO;
            high_o <= 0; low_o <= 0;
            target_q <= 0; remaining_q <= 0;
        end else begin
            case (state_q)
                APAGADO: begin
                    high_o <= 0; low_o <= 0;
                    target_q <= raw_high_i;
                    state_q <= SINCRONIZAR;
                end
                SINCRONIZAR: begin
                    // El primer pulso admitido es completo y de la rama inferior
                    // cuando se arranca con referencia cero desde el valle.
                    if (raw_high_i != target_q) begin
                        target_q <= raw_high_i;
                        remaining_q <= deadtime_i - 1'b1;
                        state_q <= ESPERA;
                    end
                end
                ESPERA: begin
                    if (raw_high_i != target_q) begin
                        target_q <= raw_high_i;
                        remaining_q <= deadtime_i - 1'b1;
                    end else if (remaining_q != 0) begin
                        remaining_q <= remaining_q - 1'b1;
                    end else begin
                        high_o <= target_q;
                        low_o <= !target_q;
                        state_q <= target_q ? SUPERIOR : INFERIOR;
                    end
                end
                SUPERIOR: begin
                    if (!raw_high_i) begin
                        high_o <= 0; low_o <= 0;
                        target_q <= 0;
                        remaining_q <= deadtime_i - 1'b1;
                        state_q <= ESPERA;
                    end
                end
                INFERIOR: begin
                    if (raw_high_i) begin
                        high_o <= 0; low_o <= 0;
                        target_q <= 1;
                        remaining_q <= deadtime_i - 1'b1;
                        state_q <= ESPERA;
                    end
                end
                default: begin
                    state_q <= APAGADO;
                    high_o <= 0; low_o <= 0;
                    remaining_q <= 0;
                end
            endcase
        end
    end
endmodule
