`timescale 1ns / 1ps
// Controla conversiones por software/PWM, lee DRP y publica muestras identificadas.
// El reconocimiento solo consume la muestra cuyo token completo sigue vigente.
module adc_control #(
    parameter logic [6:0] ADC_ADDR = 7'h16, // Registro DRP de VAUX6.
    parameter int TIMEOUT_CYCLES = 1024    // Límite independiente para EOC y DRDY.
)(
    input  logic clk, aresetn,
    input  logic pwm_trigger_i, start_sw_i,
    input  logic ack_sample_i,
    input  logic [31:0] ack_id_i,          // Token de la muestra que consumió software.
    input  logic eoc_i, drdy_i,
    input  logic [15:0] do_i,
    output logic convst_o, den_o,
    output logic [6:0] daddr_o,
    output logic dwe_o,
    output logic busy_o, valid_o, new_data_o,
    output logic [31:0] sample_o,          // ID 16, cuatro ceros y código de 12.
    output logic [31:0] sample_token_o,    // Generación de 16 bits e ID 16; cero no es reconocible.
    output logic missed_trigger_o, overrun_o, timeout_o
);
    typedef enum logic [1:0] { IDLE, WAIT_EOC, SEND_READ, WAIT_DRDY } state_t;
    state_t state;
    logic eoc_prev;
    logic [31:0] wait_count;
    logic [15:0] sample_id;
    logic ack_exhausted;
    logic ack_matches;

    assign busy_o = (state != IDLE);
    assign daddr_o = ADC_ADDR;
    assign dwe_o = 1'b0;
    // Se compara en el flanco del efecto, no al recibir AW: puede llegar otra muestra.
    assign ack_matches = ack_sample_i && valid_o && new_data_o &&
                         (sample_token_o != 0) && (ack_id_i == sample_token_o);

    always_ff @(posedge clk or negedge aresetn) begin
        if (!aresetn) begin
            state <= IDLE;
            eoc_prev <= 0; wait_count <= 0; sample_id <= 0;
            sample_o <= 0; sample_token_o <= 0; ack_exhausted <= 0;
            valid_o <= 0; new_data_o <= 0;
            convst_o <= 0; den_o <= 0;
            missed_trigger_o <= 0; overrun_o <= 0; timeout_o <= 0;
        end else begin
            eoc_prev <= eoc_i;
            convst_o <= 0; den_o <= 0;
            if (ack_matches)
                new_data_o <= 0;
            // Los errores son persistentes hasta reset; no detienen la base de tiempo PWM.
            if (busy_o && (pwm_trigger_i || start_sw_i))
                missed_trigger_o <= 1;

            case (state)
                IDLE: begin
                    wait_count <= 0;
                    // Dos solicitudes coincidentes producen una sola conversión.
                    if (pwm_trigger_i || start_sw_i) begin
                        convst_o <= 1;
                        state <= WAIT_EOC;
                        if (pwm_trigger_i && start_sw_i)
                            missed_trigger_o <= 1;
                    end
                end
                WAIT_EOC: begin
                    if (eoc_i && !eoc_prev) begin
                        wait_count <= 0;
                        state <= SEND_READ;
                    end else if (wait_count >= TIMEOUT_CYCLES-1) begin
                        timeout_o <= 1;
                        state <= IDLE;
                    end else wait_count <= wait_count + 1'b1;
                end
                SEND_READ: begin
                    // DEN dura un ciclo; solo DRDY autoriza capturar DO.
                    den_o <= 1;
                    wait_count <= 0;
                    state <= WAIT_DRDY;
                end
                WAIT_DRDY: begin
                    if (drdy_i) begin
                        sample_id <= sample_id + 1'b1;
                        sample_o <= {(sample_id + 16'd1), 4'b0, do_i[15:4]};
                        // El token no reutiliza valores tras una vuelta completa de ID 16.
                        // Al agotar 32 bits se bloquea ACK con token 0 hasta reset coordinado.
                        if (!ack_exhausted) begin
                            if (sample_token_o == 32'hffff_ffff) begin
                                sample_token_o <= 0;
                                ack_exhausted <= 1;
                            end else sample_token_o <= sample_token_o + 1'b1;
                        end
                        if (new_data_o && !ack_matches)
                            overrun_o <= 1;
                        // Publicar prevalece sobre cualquier ACK del mismo flanco.
                        valid_o <= 1;
                        new_data_o <= 1;
                        state <= IDLE;
                    end else if (wait_count >= TIMEOUT_CYCLES-1) begin
                        timeout_o <= 1;
                        state <= IDLE;
                    end else wait_count <= wait_count + 1'b1;
                end
                default: state <= IDLE;
            endcase
        end
    end
endmodule
