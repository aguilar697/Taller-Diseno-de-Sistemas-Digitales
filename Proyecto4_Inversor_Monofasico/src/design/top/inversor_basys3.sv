`timescale 1ns / 1ps
// Integracion fisica de la plataforma. SW15 bloquea las cuatro ordenes de potencia.
// El permiso SD externo de los IR2110 se conserva independiente de la FPGA.
module inversor_basys3 (
    input wire clk_i, reset_i,
    input wire [2:0] botones,
    input wire [1:0] amplitud,
    input wire permiso_pwm,
    input wire uart_rx,
    output wire uart_tx,
    input wire vauxp6, vauxn6,
    output wire [3:0] led,
    output wire isr_debug,
    output wire pwm_ah, pwm_al, pwm_bh, pwm_bl,
    output wire pwm_period_start_o
);
    wire ah, al, bh, bl, axi_clk;
    (* ASYNC_REG = "TRUE" *) reg [1:0] permiso_sync;
    reg permiso_periodo;

    // SW15 corta las salidas al bajar. Para habilitar, sincronizar el permiso
    // y esperar un comienzo de periodo; evita incorporar un pulso a medias.
    always @(posedge axi_clk or posedge reset_i or negedge permiso_pwm) begin
        if (reset_i || !permiso_pwm) begin
            permiso_sync <= 2'b00;
        end else begin
            permiso_sync <= {permiso_sync[0], 1'b1};
        end
    end
    // El bloqueo se afirma de inmediato; su liberacion cruza dos registros
    // antes de permitir que el siguiente inicio de periodo habilite las salidas.
    always @(posedge axi_clk or negedge permiso_sync[1]) begin
        if (!permiso_sync[1])
            permiso_periodo <= 1'b0;
        else if (pwm_period_start_o)
            permiso_periodo <= 1'b1;
    end
    platform_microblaze_wrapper plataforma (
        .clk_i(clk_i), .reset_i(reset_i), .axi_clk_o(axi_clk),
        .BUTTONS_tri_i(botones), .SWITCHES_tri_i(amplitud),
        .LEDS_tri_o(led), .ISR_DIAG_tri_o(isr_debug),
        .UART_0_rxd(uart_rx), .UART_0_txd(uart_tx),
        .vauxp6(vauxp6), .vauxn6(vauxn6),
        .pwm_ah(ah), .pwm_al(al), .pwm_bh(bh), .pwm_bl(bl),
        .pwm_period_start_o(pwm_period_start_o)
    );
    assign pwm_ah = permiso_pwm && !reset_i && permiso_periodo && ah;
    assign pwm_al = permiso_pwm && !reset_i && permiso_periodo && al;
    assign pwm_bh = permiso_pwm && !reset_i && permiso_periodo && bh;
    assign pwm_bl = permiso_pwm && !reset_i && permiso_periodo && bl;
endmodule
