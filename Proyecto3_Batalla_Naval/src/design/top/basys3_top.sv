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
// LEDs (mismo orden que el top de prueba del Subsistema 2):
//   LED0-LED6    UP, DOWN, LEFT, RIGHT, SEL, OK, GAME_RST
//   LED11-LED13  un LED por fase: colocacion, batalla, resultado
//   LED15        RUN, sigue a SW15
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

    // LED0-LED6: entradas del Jugador 1, en el orden de bits del registro
    // INPUTS y del top de prueba del Subsistema 2.
    // LED11-LED13: un LED por fase (codigo del LED: 00 colocacion, 01 batalla,
    // 10 resultado), para que siempre haya uno encendido.
    // LED15: RUN, sigue a SW15. Punto decimal apagado.
    logic [2:0] phase_onehot;

    always_comb begin
        case (game_phase_led)
            2'b00:   phase_onehot = 3'b001;
            2'b01:   phase_onehot = 3'b010;
            2'b10:   phase_onehot = 3'b100;
            default: phase_onehot = 3'b000;
        endcase
    end

    always_comb begin
        led        = 16'b0;
        led[0]     = btnU;
        led[1]     = btnD;
        led[2]     = btnL;
        led[3]     = btnR;
        led[4]     = sw[0];
        led[5]     = sw[1];
        led[6]     = btnC;
        led[13:11] = phase_onehot;
        led[15]    = sw[15];
    end

    assign dp = 1'b1;

endmodule
