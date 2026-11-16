`timescale 1ns / 1ps
// Solo simulacion: sustituto digital del XADC Wizard, NO modelo ACS712/analogico.
// Reutiliza la latencia EOC=100 y DRDY=7 del TB PWM-ADC existente.
module xadc_wiz_0 (
    input wire [15:0] di_in,
    input wire [6:0] daddr_in,
    input wire den_in, dwe_in, dclk_in, reset_in, convst_in,
    input wire vp_in, vn_in, vauxp6, vauxn6,
    output logic drdy_out=0,
    output logic [15:0] do_out=0,
    output wire user_temp_alarm_out, vccint_alarm_out, vccaux_alarm_out, ot_out,
    output wire [4:0] channel_out,
    output logic eoc_out=0,
    output wire [7:0] alarm_out,
    output wire eos_out,
    output logic busy_out=0
);
    integer espera_eoc=-1, espera_drdy=-1, conversiones=0;
    assign {user_temp_alarm_out,vccint_alarm_out,vccaux_alarm_out,ot_out}=0;
    assign channel_out=5'h16;
    assign alarm_out=0;
    assign eos_out=eoc_out;
    always @(negedge dclk_in) begin
        if(reset_in) begin
            espera_eoc=-1; espera_drdy=-1; conversiones=0;
            drdy_out=0; eoc_out=0; busy_out=0; do_out=0;
        end else begin
            eoc_out=0; drdy_out=0;
            if(convst_in) begin
                if(busy_out) $fatal(1,"Modelo: conversion superpuesta");
                espera_eoc=100; conversiones++;
                busy_out=1;
            end
            if(espera_eoc==0) begin
                eoc_out=1; busy_out=0; espera_eoc=-1;
            end else if(espera_eoc>0) espera_eoc--;
            if(den_in) begin
                if(dwe_in || daddr_in!=7'h16) $fatal(1,"Modelo: acceso DRP no permitido");
                espera_drdy=7;
            end
            if(espera_drdy==0) begin
                drdy_out=1; do_out=16'((12'h122+conversiones)<<4);
                espera_drdy=-1;
            end else if(espera_drdy>0) espera_drdy--;
        end
    end
endmodule
