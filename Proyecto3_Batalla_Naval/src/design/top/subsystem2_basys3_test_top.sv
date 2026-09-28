module subsystem2_basys3_test_top (
    input  logic        clk,
    input  logic [15:0] sw,

    input  logic        btnU,
    input  logic        btnD,
    input  logic        btnL,
    input  logic        btnR,
    input  logic        btnC,

    output logic [15:0] led,

    output logic [3:0]  vgaRed,
    output logic [3:0]  vgaGreen,
    output logic [3:0]  vgaBlue,
    output logic        Hsync,
    output logic        Vsync
);

    // Reset general desde SW15.
    logic rst;

    logic [31:0] input_status;

    logic        vga_write_enable;
    logic [8:0]  vga_addr;
    logic [31:0] vga_wdata;
    logic [31:0] vga_rdata;

    logic [11:0] vga_rgb;

    logic [8:0] init_addr_q;
    logic [4:0] init_col_q;
    logic [3:0] init_row_q;
    logic       init_done_q;

    logic [31:0] demo_tile;


    assign rst = sw[15];


    // Construye una palabra de tile:
    // [11:4] ASCII
    // [3]    glyph enable
    // [2:0]  color
    function automatic logic [31:0] make_tile (
        input logic [2:0] color,
        input logic       glyph_enable,
        input logic [7:0] ascii
    );
        make_tile = {
            20'b0,
            ascii,
            glyph_enable,
            color
        };
    endfunction


    // Patrón gráfico para comprobar VGA, colores,
    // memoria de video y caracteres.
    always_comb begin

        // Fondo negro.
        demo_tile = make_tile(3'd0, 1'b0, 8'h20);

        // Tablero izquierdo.
        if ((init_row_q >= 4) && (init_row_q <= 11) &&
            (init_col_q >= 1) && (init_col_q <= 8))
            demo_tile = make_tile(3'd1, 1'b0, 8'h20);

        // Tablero derecho.
        if ((init_row_q >= 4) && (init_row_q <= 11) &&
            (init_col_q >= 11) && (init_col_q <= 18))
            demo_tile = make_tile(3'd1, 1'b0, 8'h20);


        // Barcos de prueba.
        if ((init_row_q == 6) &&
            (init_col_q >= 3) && (init_col_q <= 5))
            demo_tile = make_tile(3'd2, 1'b0, 8'h20);

        if ((init_row_q == 9) &&
            (init_col_q >= 6) && (init_col_q <= 7))
            demo_tile = make_tile(3'd2, 1'b0, 8'h20);


        // Impacto.
        if ((init_row_q == 6) && (init_col_q == 13))
            demo_tile = make_tile(3'd3, 1'b0, 8'h20);

        // Fallo.
        if ((init_row_q == 8) && (init_col_q == 16))
            demo_tile = make_tile(3'd4, 1'b0, 8'h20);

        // Cursor.
        if ((init_row_q == 5) && (init_col_q == 12))
            demo_tile = make_tile(3'd5, 1'b0, 8'h20);

        // HUD/acento.
        if ((init_row_q == 0) && (init_col_q == 0))
            demo_tile = make_tile(3'd6, 1'b0, 8'h20);


        // Título P1.
        if ((init_row_q == 1) && (init_col_q == 3))
            demo_tile = make_tile(3'd0, 1'b1, 8'h50); // P

        if ((init_row_q == 1) && (init_col_q == 4))
            demo_tile = make_tile(3'd0, 1'b1, 8'h31); // 1


        // Título P2.
        if ((init_row_q == 1) && (init_col_q == 13))
            demo_tile = make_tile(3'd0, 1'b1, 8'h50); // P

        if ((init_row_q == 1) && (init_col_q == 14))
            demo_tile = make_tile(3'd0, 1'b1, 8'h32); // 2


        // Mensaje TEST.
        if ((init_row_q == 13) && (init_col_q == 8))
            demo_tile = make_tile(3'd0, 1'b1, 8'h54); // T

        if ((init_row_q == 13) && (init_col_q == 9))
            demo_tile = make_tile(3'd0, 1'b1, 8'h45); // E

        if ((init_row_q == 13) && (init_col_q == 10))
            demo_tile = make_tile(3'd0, 1'b1, 8'h53); // S

        if ((init_row_q == 13) && (init_col_q == 11))
            demo_tile = make_tile(3'd0, 1'b1, 8'h54); // T

    end


    // Inicializa los 300 tiles visibles una sola vez.
    always_ff @(posedge clk) begin
        if (rst) begin
            init_addr_q <= 9'd0;
            init_col_q  <= 5'd0;
            init_row_q  <= 4'd0;
            init_done_q <= 1'b0;
        end
        else if (!init_done_q) begin

            if (init_addr_q == 9'd299) begin
                init_done_q <= 1'b1;
            end
            else begin
                init_addr_q <= init_addr_q + 1'b1;

                if (init_col_q == 5'd19) begin
                    init_col_q <= 5'd0;
                    init_row_q <= init_row_q + 1'b1;
                end
                else begin
                    init_col_q <= init_col_q + 1'b1;
                end
            end
        end
    end


    assign vga_write_enable = !init_done_q;
    assign vga_addr         = init_addr_q;
    assign vga_wdata        = demo_tile;


    // Subsistema 2 completo.
    subsystem2_vga_inputs #(
        .INPUT_DEBOUNCE_CYCLES(1_000_000)
    ) u_subsystem2 (
        .clk_100_i(clk),
        .rst_i(rst),

        .up_i(btnU),
        .down_i(btnD),
        .left_i(btnL),
        .right_i(btnR),

        .sel_i(sw[0]),
        .ok_i(sw[1]),
        .game_rst_i(btnC),

        .input_write_enable_i(1'b0),
        .input_addr_i(2'b00),
        .input_wdata_i(32'b0),
        .input_rdata_o(input_status),

        .vga_write_enable_i(vga_write_enable),
        .vga_addr_i(vga_addr),
        .vga_wdata_i(vga_wdata),
        .vga_rdata_o(vga_rdata),

        .vga_hsync_o(Hsync),
        .vga_vsync_o(Vsync),
        .vga_rgb_o(vga_rgb)
    );


    // RGB interno de 12 bits al conector VGA de Basys 3.
    assign vgaRed   = vga_rgb[11:8];
    assign vgaGreen = vga_rgb[7:4];
    assign vgaBlue  = vga_rgb[3:0];


    // Visualización de las entradas en LEDs.
    always_comb begin
        led      = 16'b0;
        led[6:0] = input_status[6:0];

        // Indica que la VRAM terminó de inicializarse.
        led[15] = init_done_q;
    end

endmodule