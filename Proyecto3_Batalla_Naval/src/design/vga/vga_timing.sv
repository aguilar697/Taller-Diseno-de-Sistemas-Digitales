module vga_timing #(
    parameter int unsigned H_VISIBLE = 640,
    parameter int unsigned H_FRONT   = 16,
    parameter int unsigned H_SYNC    = 96,
    parameter int unsigned H_BACK    = 48,

    parameter int unsigned V_VISIBLE = 480,
    parameter int unsigned V_FRONT   = 10,
    parameter int unsigned V_SYNC    = 2,
    parameter int unsigned V_BACK    = 33
) (
    input  logic       clk_pixel_i,
    input  logic       rst_pixel_i,

    output logic [9:0] pixel_x_o,
    output logic [9:0] pixel_y_o,
    output logic       active_video_o,

    output logic       vga_hsync_o,
    output logic       vga_vsync_o,

    output logic       line_end_o
);

    // -------------------------------------------------------------------------
    // VGA timing constants
    // -------------------------------------------------------------------------
    // Un periodo horizontal contiene la zona visible y los tres intervalos
    // de blanking. Lo mismo ocurre verticalmente para cada cuadro.
    localparam int unsigned H_TOTAL =
        H_VISIBLE + H_FRONT + H_SYNC + H_BACK;

    localparam int unsigned V_TOTAL =
        V_VISIBLE + V_FRONT + V_SYNC + V_BACK;

    localparam int unsigned H_SYNC_START =
        H_VISIBLE + H_FRONT;

    localparam int unsigned H_SYNC_END =
        H_VISIBLE + H_FRONT + H_SYNC;

    localparam int unsigned V_SYNC_START =
        V_VISIBLE + V_FRONT;

    localparam int unsigned V_SYNC_END =
        V_VISIBLE + V_FRONT + V_SYNC;

    // -------------------------------------------------------------------------
    // Horizontal and vertical counters
    // -------------------------------------------------------------------------
    // Diez bits son suficientes para representar:
    // horizontal: 0 ... 799
    // vertical:   0 ... 524
    logic [9:0] h_count_q;
    logic [9:0] v_count_q;

    // -------------------------------------------------------------------------
    // VGA counters
    // -------------------------------------------------------------------------
    // El contador horizontal avanza con cada píxel.
    // Al finalizar una línea vuelve a cero e incrementa el contador vertical.
    // Al terminar la última línea comienza un nuevo cuadro.
    always_ff @(posedge clk_pixel_i) begin
        if (rst_pixel_i) begin
            h_count_q <= 10'd0;
            v_count_q <= 10'd0;
        end else begin
            if (h_count_q == H_TOTAL - 1) begin
                h_count_q <= 10'd0;

                if (v_count_q == V_TOTAL - 1) begin
                    v_count_q <= 10'd0;
                end else begin
                    v_count_q <= v_count_q + 10'd1;
                end
            end else begin
                h_count_q <= h_count_q + 10'd1;
            end
        end
    end

    // -------------------------------------------------------------------------
    // Pixel coordinates
    // -------------------------------------------------------------------------
    // Las coordenadas representan la posición dentro de la temporización
    // completa. active_video_o indica cuándo pertenecen al área visible.
    assign pixel_x_o = h_count_q;
    assign pixel_y_o = v_count_q;

    // -------------------------------------------------------------------------
    // Active video region
    // -------------------------------------------------------------------------
    // Solo los primeros 640 x 480 píxeles corresponden a imagen visible.
    assign active_video_o =
        (h_count_q < H_VISIBLE) &&
        (v_count_q < V_VISIBLE);

    // -------------------------------------------------------------------------
    // Horizontal synchronization
    // -------------------------------------------------------------------------
    // VGA utiliza sincronismos activos en bajo.
    // HSYNC permanece bajo durante H_SYNC ciclos de píxel.
    assign vga_hsync_o =
        ~((h_count_q >= H_SYNC_START) &&
          (h_count_q <  H_SYNC_END));

    // -------------------------------------------------------------------------
    // Vertical synchronization
    // -------------------------------------------------------------------------
    // VSYNC también es activo en bajo y dura V_SYNC líneas completas.
    assign vga_vsync_o =
        ~((v_count_q >= V_SYNC_START) &&
          (v_count_q <  V_SYNC_END));

    // -------------------------------------------------------------------------
    // End-of-line indication
    // -------------------------------------------------------------------------
    // Esta señal vale uno durante el último píxel de cada periodo horizontal.
    assign line_end_o = (h_count_q == H_TOTAL - 1);

endmodule