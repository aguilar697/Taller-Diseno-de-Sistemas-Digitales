module subsystem2_vga_inputs #(
    // En hardware se utiliza el valor normal del periférico de entradas.
    // En el testbench de integración podremos reducirlo para acelerar
    // la simulación.
    parameter int unsigned INPUT_DEBOUNCE_CYCLES = 1_000_000
) (
    // -------------------------------------------------------------------------
    // Clock and general reset
    // -------------------------------------------------------------------------
    input  logic        clk_100_i,
    input  logic        rst_i,

    // -------------------------------------------------------------------------
    // Player 1 physical inputs
    // -------------------------------------------------------------------------
    input  logic        up_i,
    input  logic        down_i,
    input  logic        left_i,
    input  logic        right_i,
    input  logic        sel_i,
    input  logic        ok_i,
    input  logic        game_rst_i,

    // -------------------------------------------------------------------------
    // Player 1 input peripheral - MMIO interface
    // -------------------------------------------------------------------------
    input  logic        input_write_enable_i,
    input  logic [1:0]  input_addr_i,
    input  logic [31:0] input_wdata_i,
    output logic [31:0] input_rdata_o,

    // -------------------------------------------------------------------------
    // VGA video memory - CPU/MMIO interface
    // -------------------------------------------------------------------------
    input  logic        vga_write_enable_i,
    input  logic [8:0]  vga_addr_i,
    input  logic [31:0] vga_wdata_i,
    output logic [31:0] vga_rdata_o,

    // -------------------------------------------------------------------------
    // VGA outputs
    // -------------------------------------------------------------------------
    output logic        vga_hsync_o,
    output logic        vga_vsync_o,
    output logic [11:0] vga_rgb_o
);

    // =========================================================================
    // Internal clock and reset signals
    // =========================================================================

    logic clk_pixel;
    logic pixel_clock_locked;
    logic rst_pixel;

    // =========================================================================
    // VGA timing signals
    // =========================================================================

    logic [9:0] pixel_x;
    logic [9:0] pixel_y;
    logic       active_video;

    logic       hsync_raw;
    logic       vsync_raw;
    logic       line_end;

    // =========================================================================
    // Video memory / renderer interconnection
    // =========================================================================

    logic [8:0]  tile_addr;
    logic [31:0] tile_word;

    // =========================================================================
    // 1. Pixel clock generator
    // =========================================================================
    //
    // Convierte los 100 MHz de la Basys 3 en 25 MHz mediante el MMCM
    // configurado con Clocking Wizard.
    // =========================================================================

    pixel_clock u_pixel_clock (
        .clk_100_i   (clk_100_i),
        .rst_i       (rst_i),
        .clk_pixel_o (clk_pixel),
        .locked_o    (pixel_clock_locked)
    );

    // =========================================================================
    // 2. Pixel-domain reset synchronizer
    // =========================================================================
    //
    // El dominio VGA permanece en reset mientras el MMCM no esté estable.
    // La liberación del reset se sincroniza con clk_pixel.
    // =========================================================================

    pixel_reset_sync u_pixel_reset_sync (
        .clk_pixel_i (clk_pixel),
        .rst_i       (rst_i),
        .locked_i    (pixel_clock_locked),
        .rst_pixel_o (rst_pixel)
    );

    // =========================================================================
    // 3. VGA timing controller
    // =========================================================================
    //
    // Genera las coordenadas 640x480 y las señales de sincronización VGA.
    // =========================================================================

    vga_timing u_vga_timing (
        .clk_pixel_i    (clk_pixel),
        .rst_pixel_i    (rst_pixel),

        .pixel_x_o      (pixel_x),
        .pixel_y_o      (pixel_y),
        .active_video_o (active_video),

        .vga_hsync_o    (hsync_raw),
        .vga_vsync_o    (vsync_raw),
        .line_end_o     (line_end)
    );

    // =========================================================================
    // 4. Dual-port video memory
    // =========================================================================
    //
    // Puerto CPU:
    //      100 MHz, lectura/escritura.
    //
    // Puerto VGA:
    //      25 MHz, solo lectura.
    // =========================================================================

    video_memory u_video_memory (
        // CPU port
        .clk_100_i          (clk_100_i),
        .rst_i              (rst_i),
        .vga_write_enable_i (vga_write_enable_i),
        .vga_addr_i         (vga_addr_i),
        .vga_wdata_i        (vga_wdata_i),
        .vga_rdata_o        (vga_rdata_o),

        // VGA port
        .clk_pixel_i        (clk_pixel),
        .tile_addr_i        (tile_addr),
        .tile_word_o        (tile_word)
    );

    // =========================================================================
    // 5. Tile / glyph renderer
    // =========================================================================
    //
    // Convierte:
    //
    // pixel_x, pixel_y
    //        +
    // tile_word
    //
    // en el color RGB correspondiente al píxel.
    //
    // glyph_rom está instanciada internamente dentro de tile_renderer.
    // =========================================================================

    tile_renderer u_tile_renderer (
        .clk_pixel_i    (clk_pixel),
        .rst_pixel_i    (rst_pixel),

        .pixel_x_i      (pixel_x),
        .pixel_y_i      (pixel_y),
        .active_video_i (active_video),

        .tile_addr_o    (tile_addr),
        .tile_word_i    (tile_word),

        .vga_rgb_o      (vga_rgb_o)
    );

    // =========================================================================
    // 6. HSYNC / VSYNC pipeline alignment
    // =========================================================================
    //
    // La lectura VGA de video_memory es síncrona. Por ello tile_renderer
    // registra las coordenadas durante un ciclo para alinearlas con tile_word.
    //
    // HSYNC y VSYNC se retrasan también un ciclo de clk_pixel para que las
    // señales de sincronización correspondan al mismo píxel que vga_rgb_o.
    // =========================================================================

    always_ff @(posedge clk_pixel) begin
        if (rst_pixel) begin
            // HSYNC y VSYNC son activas en bajo. Durante reset permanecen
            // en su nivel inactivo.
            vga_hsync_o <= 1'b1;
            vga_vsync_o <= 1'b1;
        end else begin
            vga_hsync_o <= hsync_raw;
            vga_vsync_o <= vsync_raw;
        end
    end

    // =========================================================================
    // 7. Player 1 input peripheral
    // =========================================================================
    //
    // Cada entrada física pasa por sincronización y debounce antes de ser
    // empaquetada en input_rdata_o.
    //
    // bit 0 = UP
    // bit 1 = DOWN
    // bit 2 = LEFT
    // bit 3 = RIGHT
    // bit 4 = SEL
    // bit 5 = OK
    // bit 6 = GAME_RST
    // =========================================================================

    player1_inputs #(
        .DEBOUNCE_CYCLES(INPUT_DEBOUNCE_CYCLES)
    ) u_player1_inputs (
        .clk_i                (clk_100_i),
        .rst_i                (rst_i),

        .up_i                 (up_i),
        .down_i               (down_i),
        .left_i               (left_i),
        .right_i              (right_i),
        .sel_i                (sel_i),
        .ok_i                 (ok_i),
        .game_rst_i           (game_rst_i),

        .input_write_enable_i (input_write_enable_i),
        .input_addr_i         (input_addr_i),
        .input_wdata_i        (input_wdata_i),
        .input_rdata_o        (input_rdata_o)
    );

endmodule