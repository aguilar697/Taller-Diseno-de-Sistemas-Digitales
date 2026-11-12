`timescale 1ns / 1ps
// Une el esclavo AXI con adc_top en un dominio de 100 MHz, sin plataforma externa.
// El token viaja con la muestra y vuelve por ACK para comparar en el controlador.
module adc_system_axi #(
    parameter int ADDR_WIDTH = 6, // Dirección local en bytes; mínimo 5.
    parameter int ADC_TIMEOUT_CYCLES = 1024 // Presupuesto de cada espera XADC.
)(
    input logic s_axi_aclk, s_axi_aresetn,
    input logic [ADDR_WIDTH-1:0] s_axi_awaddr,
    input logic [2:0] s_axi_awprot,
    input logic s_axi_awvalid,
    output logic s_axi_awready,
    input logic [31:0] s_axi_wdata,
    input logic [3:0] s_axi_wstrb,
    input logic s_axi_wvalid,
    output logic s_axi_wready,
    output logic [1:0] s_axi_bresp,
    output logic s_axi_bvalid,
    input logic s_axi_bready,
    input logic [ADDR_WIDTH-1:0] s_axi_araddr,
    input logic [2:0] s_axi_arprot,
    input logic s_axi_arvalid,
    output logic s_axi_arready,
    output logic [31:0] s_axi_rdata,
    output logic [1:0] s_axi_rresp,
    output logic s_axi_rvalid,
    input logic s_axi_rready,
    input logic pwm_trigger_i,
    input wire vauxp6, vauxn6
);
    logic [31:0] sample;
    logic [31:0] sample_token, ack_id;
    logic busy, valid, new_data, xadc_busy;
    logic missed_trigger, overrun, timeout;
    logic start_sw, ack_sample;

    // Solo este esclavo conduce START, ACK y su identificador hacia adquisición.
    adc_axi_lite #(.ADDR_WIDTH(ADDR_WIDTH)) u_axi (
        .s_axi_aclk(s_axi_aclk), .s_axi_aresetn(s_axi_aresetn),
        .s_axi_awaddr(s_axi_awaddr), .s_axi_awprot(s_axi_awprot),
        .s_axi_awvalid(s_axi_awvalid), .s_axi_awready(s_axi_awready),
        .s_axi_wdata(s_axi_wdata), .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid), .s_axi_wready(s_axi_wready),
        .s_axi_bresp(s_axi_bresp), .s_axi_bvalid(s_axi_bvalid), .s_axi_bready(s_axi_bready),
        .s_axi_araddr(s_axi_araddr), .s_axi_arprot(s_axi_arprot),
        .s_axi_arvalid(s_axi_arvalid), .s_axi_arready(s_axi_arready),
        .s_axi_rdata(s_axi_rdata), .s_axi_rresp(s_axi_rresp),
        .s_axi_rvalid(s_axi_rvalid), .s_axi_rready(s_axi_rready),
        .sample_i(sample), .sample_token_i(sample_token), .busy_i(busy), .valid_i(valid), .new_data_i(new_data),
        .xadc_busy_i(xadc_busy), .missed_trigger_i(missed_trigger),
        .overrun_i(overrun), .timeout_i(timeout),
        .start_sw_o(start_sw), .ack_sample_o(ack_sample), .ack_id_o(ack_id)
    );

    // El pulso PWM es una entrada de evento; no se crean señales de potencia.
    adc_top #(.ADC_TIMEOUT_CYCLES(ADC_TIMEOUT_CYCLES)) u_adc (
        .clk(s_axi_aclk), .aresetn(s_axi_aresetn),
        .pwm_trigger_i(pwm_trigger_i), .start_sw_i(start_sw), .ack_sample_i(ack_sample), .ack_id_i(ack_id),
        .vauxp6(vauxp6), .vauxn6(vauxn6),
        .sample_o(sample), .sample_token_o(sample_token), .busy_o(busy), .valid_o(valid), .new_data_o(new_data),
        .missed_trigger_o(missed_trigger), .overrun_o(overrun),
        .timeout_o(timeout), .xadc_busy_o(xadc_busy)
    );
endmodule
