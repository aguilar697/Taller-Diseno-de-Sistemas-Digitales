module tile_renderer (
    // -------------------------------------------------------------------------
    // Pixel domain
    // -------------------------------------------------------------------------
    input  logic        clk_pixel_i,
    input  logic        rst_pixel_i,

    // -------------------------------------------------------------------------
    // Current VGA position
    // -------------------------------------------------------------------------
    input  logic [9:0]  pixel_x_i,
    input  logic [9:0]  pixel_y_i,
    input  logic        active_video_i,

    // -------------------------------------------------------------------------
    // Video memory interface
    // -------------------------------------------------------------------------
    output logic [8:0]  tile_addr_o,
    input  logic [31:0] tile_word_i,

    // -------------------------------------------------------------------------
    // VGA color output
    // [11:8] = red, [7:4] = green, [3:0] = blue
    // -------------------------------------------------------------------------
    output logic [11:0] vga_rgb_o
);

    // -------------------------------------------------------------------------
    // Pixel -> tile mapping
    // -------------------------------------------------------------------------
    // Cada tile mide 32 x 32 píxeles:
    //
    // tile_col = pixel_x / 32
    // tile_row = pixel_y / 32
    //
    // Como 32 = 2^5, la división se implementa tomando los bits superiores.
    logic [4:0] tile_col;
    logic [3:0] tile_row;

    assign tile_col = pixel_x_i[9:5];
    assign tile_row = pixel_y_i[8:5];

    // -------------------------------------------------------------------------
    // Tile address
    // -------------------------------------------------------------------------
    // tile_index = row * 20 + column
    //
    // Multiplicar por 20 equivale a:
    //
    // row * 20 = row * 16 + row * 4
    //
    // Esto permite expresar claramente la operación mediante desplazamientos.
    always_comb begin

        if (active_video_i) begin
            tile_addr_o =
                ({5'b0, tile_row} << 4) +
                ({5'b0, tile_row} << 2) +
                {4'b0, tile_col};
        end else begin
            tile_addr_o = 9'd0;
        end

    end

    // -------------------------------------------------------------------------
    // Pipeline stage
    // -------------------------------------------------------------------------
    // El puerto VGA de video_memory posee lectura síncrona.
    //
    // Durante un flanco:
    // 1. La VRAM captura tile_addr_o.
    // 2. Este módulo captura las coordenadas correspondientes.
    // 3. Después del flanco, tile_word_i y estas coordenadas pertenecen
    //    al mismo píxel solicitado.
    logic [9:0] pixel_x_q;
    logic [9:0] pixel_y_q;
    logic       active_video_q;

    always_ff @(posedge clk_pixel_i) begin
        if (rst_pixel_i) begin
            pixel_x_q      <= 10'd0;
            pixel_y_q      <= 10'd0;
            active_video_q <= 1'b0;
        end else begin
            pixel_x_q      <= pixel_x_i;
            pixel_y_q      <= pixel_y_i;
            active_video_q <= active_video_i;
        end
    end

    // -------------------------------------------------------------------------
    // Tile word decoder
    // -------------------------------------------------------------------------
    // [2:0]  COLOR
    // [3]    GLYPH_ENABLE
    // [11:4] ASCII
    // [31:12] reservado
    logic [2:0] color_code;
    logic       glyph_enable;
    logic [7:0] ascii_code;

    assign color_code   = tile_word_i[2:0];
    assign glyph_enable = tile_word_i[3];
    assign ascii_code   = tile_word_i[11:4];

    // -------------------------------------------------------------------------
    // Position inside the 32 x 32 tile
    // -------------------------------------------------------------------------
    // glyph_rom utiliza una fuente 8 x 8.
    //
    // Cada píxel lógico del glyph ocupa un bloque físico de 4 x 4:
    //
    // 32 / 8 = 4
    //
    // Por eso descartamos los dos bits inferiores de la posición interna.
    logic [2:0] glyph_x;
    logic [2:0] glyph_y;

    assign glyph_x = pixel_x_q[4:2];
    assign glyph_y = pixel_y_q[4:2];

    // -------------------------------------------------------------------------
    // Glyph ROM
    // -------------------------------------------------------------------------
    logic glyph_bit;

    glyph_rom u_glyph_rom (
        .ascii_i    (ascii_code),
        .glyph_x_i  (glyph_x),
        .glyph_y_i  (glyph_y),
        .glyph_bit_o(glyph_bit)
    );

    // -------------------------------------------------------------------------
    // Color decoder
    // -------------------------------------------------------------------------
    // La documentación define el significado de los códigos COLOR.
    // Los valores RGB concretos son una decisión de implementación.
    function automatic logic [11:0] color_to_rgb(
        input logic [2:0] color
    );
        begin

            case (color)

                3'd0: color_to_rgb = 12'h000; // fondo - negro
                3'd1: color_to_rgb = 12'h04F; // agua - azul
                3'd2: color_to_rgb = 12'h888; // barco - gris
                3'd3: color_to_rgb = 12'hF00; // impacto - rojo
                3'd4: color_to_rgb = 12'hFFF; // fallo - blanco
                3'd5: color_to_rgb = 12'hFF0; // cursor - amarillo
                3'd6: color_to_rgb = 12'h0F8; // HUD/acento
                default:
                    color_to_rgb = 12'h000;    // código 7 reservado

            endcase

        end
    endfunction

    logic [11:0] base_rgb;

    always_comb begin

        base_rgb = color_to_rgb(color_code);

        // Fuera de la región visible siempre enviamos negro.
        if (!active_video_q) begin

            vga_rgb_o = 12'h000;

        end else if (glyph_enable && glyph_bit) begin

            // Los píxeles activos del glyph se dibujan en blanco.
            vga_rgb_o = 12'hFFF;

        end else begin

            // Sin glyph, o en el fondo del glyph, se muestra el color del tile.
            vga_rgb_o = base_rgb;

        end

    end

endmodule