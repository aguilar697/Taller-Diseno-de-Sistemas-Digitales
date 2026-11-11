`timescale 1ns / 1ps
// Encapsula adc_control y el XADC Wizard existente, sin modificar su configuración.
// El token de reconocimiento acompaña a SAMPLE; el XADC solo recibe control DRP/CONVST.
module adc_top #(
    parameter int ADC_TIMEOUT_CYCLES = 1024 // Ciclos por espera EOC/DRDY, no por transacción AXI.
)(
    input logic clk, aresetn,
    input logic pwm_trigger_i, start_sw_i,
    input logic ack_sample_i,
    input logic [31:0] ack_id_i,
    input wire vauxp6, vauxn6,
    output logic [31:0] sample_o,
    output logic [31:0] sample_token_o,
    output logic busy_o, valid_o, new_data_o,
    output logic missed_trigger_o, overrun_o, timeout_o,
    output logic xadc_busy_o
);
    logic convst, den, dwe, eoc, drdy;
    logic [6:0] daddr;
    logic [15:0] adc_do;
    logic [4:0] adc_channel;
    logic xadc_reset;
    assign xadc_reset = ~aresetn;

    // PWM y START llegan al mismo dominio de 100 MHz; el controlador arbitra cuando está libre.
    adc_control #(.ADC_ADDR(7'h16), .TIMEOUT_CYCLES(ADC_TIMEOUT_CYCLES)) u_adc_control (
        .clk(clk), .aresetn(aresetn),
        .pwm_trigger_i(pwm_trigger_i), .start_sw_i(start_sw_i),
        .ack_sample_i(ack_sample_i), .ack_id_i(ack_id_i),
        .eoc_i(eoc), .drdy_i(drdy), .do_i(adc_do),
        .convst_o(convst), .den_o(den), .daddr_o(daddr), .dwe_o(dwe),
        .busy_o(busy_o), .valid_o(valid_o), .new_data_o(new_data_o),
        .sample_o(sample_o), .sample_token_o(sample_token_o),
        .missed_trigger_o(missed_trigger_o), .overrun_o(overrun_o), .timeout_o(timeout_o)
    );

    // VAUX6, modo evento y lectura DRP existentes. DO[15:4] se normaliza en el controlador.
    // BUSY del XADC no reemplaza busy_o, que también incluye la espera de lectura DRP.
    xadc_wiz_0 u_xadc (
        .di_in(16'h0000), .daddr_in(daddr), .den_in(den), .dwe_in(dwe),
        .drdy_out(drdy), .do_out(adc_do), .dclk_in(clk), .reset_in(xadc_reset),
        .convst_in(convst), .vp_in(1'b0), .vn_in(1'b0),
        .vauxp6(vauxp6), .vauxn6(vauxn6),
        .user_temp_alarm_out(), .vccint_alarm_out(), .vccaux_alarm_out(), .ot_out(),
        .channel_out(adc_channel), .eoc_out(eoc), .alarm_out(), .eos_out(), .busy_out(xadc_busy_o)
    );
endmodule
