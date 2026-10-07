// Top de la tarjeta Basys 3 para el sistema completo de Batalla Naval.
//
// battleship_top integra los subsistemas con puertos genericos; este modulo
// solo los asigna a los pines de la tarjeta, sincroniza el reset general y
// carga program.hex en la ROM. No contiene logica del juego.
//
// Controles del Jugador 1:
//   BTNU / BTND / BTNL / BTNR  navegacion
//   BTNC                       GAME_RST (nueva partida, conserva victorias)
//   SW0                        SEL (rotar el barco)
//   SW1                        OK (confirmar)
//   SW15                       RUN: 0 = reset general (borra victorias), 1 = funcionando
//
// LEDs: LED0-LED1 fase del juego, LED2-LED5 flechas presionadas
// (arriba, abajo, izquierda, derecha), LED15 sistema funcionando.
module basys3_top #(
    parameter ROM_INIT_FILE = "program.hex"
)(
    input  logic        clk,
    input  logic [15:0] sw,
    input  logic        btnU,
    input  logic        btnD,
    input  logic        btnL,
    input  logic        btnR,
    input  logic        btnC,

    input  logic        RsRx,
    output logic        RsTx,

    output logic [3:0]  vgaRed,
    output logic [3:0]  vgaGreen,
    output logic [3:0]  vgaBlue,
    output logic        Hsync,
    output logic        Vsync,

    output logic [6:0]  seg,
    output logic        dp,
    output logic [3:0]  an,
    output logic [15:0] led,
    output logic        JA1
);

    // -------------------------------------------------------------------------
    // Reset general sincronizado
    // -------------------------------------------------------------------------
    // SW15 es asincrono respecto al reloj y, como en el top de prueba del
    // Subsistema 2, el reset esta activo con SW15 en 0. Dos etapas alinean su
    // activacion y su liberacion con clk, y el valor inicial mantiene el
    // sistema en reset al terminar la configuracion de la FPGA.
    (* ASYNC_REG = "TRUE" *) logic [1:0] reset_pipe_q = 2'b11;
    logic rst;

    always_ff @(posedge clk) begin
        reset_pipe_q <= {reset_pipe_q[0], ~sw[15]};
    end

    assign rst = reset_pipe_q[1];

    // -------------------------------------------------------------------------
    // Sistema completo
    // -------------------------------------------------------------------------
    logic [1:0] game_phase_led;

    battleship_top #(
        .ROM_INIT_FILE (ROM_INIT_FILE)
    ) system_inst (
        .clk_i       (clk),
        .rst_i       (rst),
        .up_i        (btnU),
        .down_i      (btnD),
        .left_i      (btnL),
        .right_i     (btnR),
        .sel_i       (sw[0]),
        .ok_i        (sw[1]),
        .game_rst_i  (btnC),
        .uart_rx_i   (RsRx),
        .uart_tx_o   (RsTx),
        .vga_red_o   (vgaRed),
        .vga_green_o (vgaGreen),
        .vga_blue_o  (vgaBlue),
        .vga_hsync_o (Hsync),
        .vga_vsync_o (Vsync),
        .seg_o       (seg),
        .an_o        (an),
        .led_o       (game_phase_led),
        .buzzer_o    (JA1)
    );

    // LED0-LED1: fase del juego (00 colocacion, 01 batalla, 10 resultado).
    // LED2-LED5: flechas presionadas (arriba, abajo, izquierda, derecha).
    // LED15: indicador RUN, sigue a SW15 (encendido = funcionando).
    // Punto decimal apagado.
    assign led = {sw[15], 9'b0, btnR, btnL, btnD, btnU, game_phase_led};
    assign dp  = 1'b1;

endmodule
