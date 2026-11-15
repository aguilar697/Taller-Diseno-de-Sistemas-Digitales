`timescale 1ns / 1ps
// Portadora centrada y actualización atómica de los dos umbrales en el valle.
// Todos los eventos son habilitaciones síncronas; no se generan relojes derivados.
module pwm_core (
    input  logic clk, aresetn,
    input  logic enable_i,
    input  logic [1:0] freq_sel_i,
    input  logic signed [15:0] reference_i,
    input  logic [31:0] deadtime_i, trigger_phase_i,
    output logic running_o,
    output logic pwm_ah, pwm_al, pwm_bh, pwm_bl,
    output logic pwm_trigger_o, pwm_period_start_o
);
    logic [13:0] phase_q, phase_next;
    logic [12:0] h_a_q, h_b_q, h_a_next, h_b_next;
    logic signed [15:0] active_reference_q;
    logic [12:0] n_half;
    logic [13:0] p_full;
    logic signed [12:0] displacement;
    logic [12:0] center;
    logic begin_period, raw_a, raw_b;

    function automatic logic signed [12:0] quantize_displacement(
        input logic signed [15:0] ref_q15, input logic [1:0] frequency);
        logic signed [28:0] product, rounding;
        begin
            // Desplazamiento aritmético con redondeo simétrico, incluidos empates
            // alejándose de cero. Evita calcular primero el valor absoluto.
            rounding = ref_q15[15] ? 29'sd32767 : 29'sd32768;
            case (frequency)
                0: product=29'sd5000*$signed(ref_q15)+rounding;
                1: product=29'sd2500*$signed(ref_q15)+rounding;
                2: product=29'sd2000*$signed(ref_q15)+rounding;
                default: product=0;
            endcase
            quantize_displacement = product[28:16];
        end
    endfunction

    always_comb begin
        case (freq_sel_i)
            2'd0: n_half = 5000;
            2'd1: n_half = 2500;
            2'd2: n_half = 2000;
            default: n_half = 0;
        endcase
        p_full = 2*n_half;
        center=n_half >> 1;
        displacement=quantize_displacement(reference_i,freq_sel_i);
        phase_next = 0;
        begin_period = 0;
        h_a_next = h_a_q;
        h_b_next = h_b_q;
        if (enable_i) begin
            if (!running_o || phase_q == p_full-1) begin
                phase_next = 0;
                begin_period = 1;
                h_a_next = center+displacement;
                h_b_next = center-displacement;
            end else phase_next = phase_q + 1'b1;
        end
        // Se usan fase y umbrales del intervalo que comienza en este flanco.
        // En el valle ambas órdenes superiores son altas para todo el rango
        // validado. Separar este caso evita llevar el multiplicador hasta las
        // entradas de las FSM de tiempo muerto en el mismo ciclo de registro.
        // c2(p)<2*h equivale a p<h o p>=P-h. Comparar los intervalos
        // evita encadenar la resta de la portadora y otro comparador.
        raw_a = begin_period || phase_next < {1'b0,h_a_q} ||
                phase_next >= p_full-{1'b0,h_a_q};
        raw_b = begin_period || phase_next < {1'b0,h_b_q} ||
                phase_next >= p_full-{1'b0,h_b_q};
    end

    always_ff @(posedge clk or negedge aresetn) begin
        if (!aresetn) begin
            phase_q <= 0; h_a_q <= 0; h_b_q <= 0;
            active_reference_q <= 0;
            running_o <= 0; pwm_trigger_o <= 0; pwm_period_start_o <= 0;
        end else if (!enable_i) begin
            phase_q <= 0; h_a_q <= 0; h_b_q <= 0;
            active_reference_q <= 0;
            running_o <= 0; pwm_trigger_o <= 0; pwm_period_start_o <= 0;
        end else begin
            phase_q <= phase_next;
            h_a_q <= h_a_next; h_b_q <= h_b_next;
            running_o <= 1;
            pwm_period_start_o <= begin_period;
            pwm_trigger_o <= (int'(phase_next) == trigger_phase_i);
            if (begin_period) active_reference_q <= reference_i;
        end
    end

    pwm_deadtime rama_a (
        .clk(clk), .aresetn(aresetn), .enable_i(enable_i), .raw_high_i(raw_a),
        .deadtime_i(deadtime_i), .high_o(pwm_ah), .low_o(pwm_al)
    );
    pwm_deadtime rama_b (
        .clk(clk), .aresetn(aresetn), .enable_i(enable_i), .raw_high_i(raw_b),
        .deadtime_i(deadtime_i), .high_o(pwm_bh), .low_o(pwm_bl)
    );
endmodule
