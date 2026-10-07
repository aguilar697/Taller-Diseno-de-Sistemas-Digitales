module subsystem2_basys3_test_top (
    // ------------------------------------------------------------
    // Reloj principal de la Basys 3
    // ------------------------------------------------------------
    input  logic        clk,

    // ------------------------------------------------------------
    // Switches fisicos de la Basys 3
    //
    // SW0  -> SEL
    // SW1  -> OK
    // SW15 -> RUN / habilitacion del Subsistema 2
    //
    // SW15 = 0 -> reset aplicado / subsistema inactivo
    // SW15 = 1 -> funcionamiento normal
    // ------------------------------------------------------------
    input  logic [15:0] sw,

    // ------------------------------------------------------------
    // Push buttons fisicos
    //
    // BTNU -> UP
    // BTND -> DOWN
    // BTNL -> LEFT
    // BTNR -> RIGHT
    // BTNC -> GAME_RST
    // ------------------------------------------------------------
    input  logic        btnU,
    input  logic        btnD,
    input  logic        btnL,
    input  logic        btnR,
    input  logic        btnC,

    // ------------------------------------------------------------
    // LEDs utilizados para observar las entradas ya acondicionadas
    // ------------------------------------------------------------
    output logic [15:0] led,

    // ------------------------------------------------------------
    // Salidas fisicas hacia el conector VGA
    // ------------------------------------------------------------
    output logic [3:0]  vgaRed,
    output logic [3:0]  vgaGreen,
    output logic [3:0]  vgaBlue,
    output logic        Hsync,
    output logic        Vsync
);


    // ============================================================
    // 1. RESET GENERAL
    // ============================================================

    /*
     * Los modulos internos del Subsistema 2 utilizan reset
     * activo en alto.
     *
     * Fisicamente se define:
     *
     * SW15 = 0 -> subsistema en reset / inactivo
     * SW15 = 1 -> subsistema habilitado / funcionando
     *
     * La inversion y sincronizacion se realizan en este top fisico.
     */
    logic rst;

    // SW15 es asincrono: dos etapas sincronizan el reset con los 100 MHz.
    // La inicializacion tambien permite arrancar con SW15 ya en RUN.
    (* ASYNC_REG = "TRUE" *) logic [1:0] reset_pipe_q = 2'b11;
    always_ff @(posedge clk) begin
        reset_pipe_q <= {reset_pipe_q[0], ~sw[15]};
    end
    assign rst = reset_pipe_q[1];


    // ============================================================
    // 2. SEÑALES DEL PERIFERICO DE ENTRADAS
    // ============================================================

    /*
     * Registro de 32 bits que representa el estado de las entradas
     * del Jugador 1 despues de sincronizacion y debounce.
     *
     * Mapa MMIO:
     *
     * bit 0 -> UP
     * bit 1 -> DOWN
     * bit 2 -> LEFT
     * bit 3 -> RIGHT
     * bit 4 -> SEL
     * bit 5 -> OK
     * bit 6 -> GAME_RST
     * bits 31:7 -> 0
     */
    logic [31:0] input_status;


    // ============================================================
    // 3. INTERFAZ DE ESCRITURA HACIA LA MEMORIA VGA
    // ============================================================

    logic        vga_write_enable;
    logic [8:0]  vga_addr;
    logic [31:0] vga_wdata;
    logic [31:0] vga_rdata;


    // ============================================================
    // 4. SALIDA RGB INTERNA DEL SUBSISTEMA
    // ============================================================

    /*
     * El renderer genera RGB de 12 bits:
     *
     * [11:8] -> rojo
     * [7:4]  -> verde
     * [3:0]  -> azul
     */
    logic [11:0] vga_rgb;


    // ============================================================
    // 5. REGISTROS PARA INICIALIZAR LA VRAM
    // ============================================================

    logic [8:0]  init_addr_q;
    logic [4:0]  init_col_q;
    logic [3:0]  init_row_q;
    logic        init_done_q;

    logic [31:0] demo_tile;


    // ============================================================
    // 6. FUNCION PARA CONSTRUIR UNA PALABRA DE TILE
    // ============================================================

    /*
     * Formato de palabra de video:
     *
     * [31:12] -> reservados
     * [11:4]  -> ASCII
     * [3]     -> glyph_enable
     * [2:0]   -> color
     */
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


    // ============================================================
    // 7. GENERACION DEL PATRON GRAFICO DE PRUEBA
    // ============================================================

    /*
     * Este patron solamente sirve para validar fisicamente:
     *
     * - VRAM
     * - VGA
     * - renderer
     * - glyphs
     * - colores
     *
     * No implementa logica del juego.
     */
    always_comb begin

        // Fondo negro.
        demo_tile = make_tile(
            3'd0,
            1'b0,
            8'h20
        );


        // --------------------------------------------------------
        // Tablero izquierdo
        // Filas 4 ... 11
        // Columnas 1 ... 8
        // --------------------------------------------------------
        if ((init_row_q >= 4) && (init_row_q <= 11) &&
            (init_col_q >= 1) && (init_col_q <= 8)) begin

            demo_tile = make_tile(
                3'd1,
                1'b0,
                8'h20
            );
        end


        // --------------------------------------------------------
        // Tablero derecho
        // Filas 4 ... 11
        // Columnas 11 ... 18
        // --------------------------------------------------------
        if ((init_row_q >= 4) && (init_row_q <= 11) &&
            (init_col_q >= 11) && (init_col_q <= 18)) begin

            demo_tile = make_tile(
                3'd1,
                1'b0,
                8'h20
            );
        end


        // --------------------------------------------------------
        // Barcos de prueba
        // --------------------------------------------------------

        if ((init_row_q == 6) &&
            (init_col_q >= 3) && (init_col_q <= 5)) begin

            demo_tile = make_tile(
                3'd2,
                1'b0,
                8'h20
            );
        end

        if ((init_row_q == 9) &&
            (init_col_q >= 6) && (init_col_q <= 7)) begin

            demo_tile = make_tile(
                3'd2,
                1'b0,
                8'h20
            );
        end


        // --------------------------------------------------------
        // Impacto
        // --------------------------------------------------------
        if ((init_row_q == 6) && (init_col_q == 13)) begin

            demo_tile = make_tile(
                3'd3,
                1'b0,
                8'h20
            );
        end


        // --------------------------------------------------------
        // Fallo
        // --------------------------------------------------------
        if ((init_row_q == 8) && (init_col_q == 16)) begin

            demo_tile = make_tile(
                3'd4,
                1'b0,
                8'h20
            );
        end


        // --------------------------------------------------------
        // Cursor
        // --------------------------------------------------------
        if ((init_row_q == 5) && (init_col_q == 12)) begin

            demo_tile = make_tile(
                3'd5,
                1'b0,
                8'h20
            );
        end


        // --------------------------------------------------------
        // Tile de HUD
        // --------------------------------------------------------
        if ((init_row_q == 0) && (init_col_q == 0)) begin

            demo_tile = make_tile(
                3'd6,
                1'b0,
                8'h20
            );
        end


        // ========================================================
        // TEXTO DE PRUEBA
        // ========================================================

        // "P1"
        if ((init_row_q == 1) && (init_col_q == 3)) begin
            demo_tile = make_tile(
                3'd0,
                1'b1,
                8'h50
            );
        end

        if ((init_row_q == 1) && (init_col_q == 4)) begin
            demo_tile = make_tile(
                3'd0,
                1'b1,
                8'h31
            );
        end


        // "P2"
        if ((init_row_q == 1) && (init_col_q == 13)) begin
            demo_tile = make_tile(
                3'd0,
                1'b1,
                8'h50
            );
        end

        if ((init_row_q == 1) && (init_col_q == 14)) begin
            demo_tile = make_tile(
                3'd0,
                1'b1,
                8'h32
            );
        end


        // "TEST"
        if ((init_row_q == 13) && (init_col_q == 8)) begin
            demo_tile = make_tile(
                3'd0,
                1'b1,
                8'h54
            );
        end

        if ((init_row_q == 13) && (init_col_q == 9)) begin
            demo_tile = make_tile(
                3'd0,
                1'b1,
                8'h45
            );
        end

        if ((init_row_q == 13) && (init_col_q == 10)) begin
            demo_tile = make_tile(
                3'd0,
                1'b1,
                8'h53
            );
        end

        if ((init_row_q == 13) && (init_col_q == 11)) begin
            demo_tile = make_tile(
                3'd0,
                1'b1,
                8'h54
            );
        end

    end


    // ============================================================
    // 8. INICIALIZACION DE VRAM
    // ============================================================

    /*
     * Se escriben los 300 tiles visibles:
     *
     * 20 columnas x 15 filas = 300 tiles.
     */
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


    // ============================================================
    // 9. INTERFAZ HACIA LA VRAM
    // ============================================================

    assign vga_write_enable = !init_done_q;
    assign vga_addr         = init_addr_q;
    assign vga_wdata        = demo_tile;


    // ============================================================
    // 10. INSTANCIA DEL SUBSISTEMA 2
    // ============================================================

    /*
     * Integra:
     *
     * - sincronizacion de entradas
     * - debounce
     * - periferico de entradas
     * - memoria de video
     * - pixel clock
     * - VGA timing
     * - glyph ROM
     * - tile renderer
     *
     * Debounce:
     *
     * 1_000_000 ciclos @ 100 MHz ~= 10 ms
     */
    subsystem2_vga_inputs #(
        .INPUT_DEBOUNCE_CYCLES(1_000_000)
    ) u_subsystem2 (

        // Reloj y reset
        .clk_100_i(clk),
        .rst_i(rst),

        // Navegacion
        .up_i(btnU),
        .down_i(btnD),
        .left_i(btnL),
        .right_i(btnR),

        // --------------------------------------------------------
        // Controles adicionales
        //
        // ASIGNACION FISICA FINAL:
        //
        // SW0  -> SEL
        // SW1  -> OK
        // BTNC -> GAME_RST
        //
        // El mapa MMIO permanece:
        //
        // bit 4 -> SEL
        // bit 5 -> OK
        // bit 6 -> GAME_RST
        // --------------------------------------------------------
        .sel_i(sw[0]),
        .ok_i(sw[1]),
        .game_rst_i(btnC),

        // Periferico de entradas
        .input_write_enable_i(1'b0),
        .input_addr_i(2'b00),
        .input_wdata_i(32'b0),
        .input_rdata_o(input_status),

        // Periferico VGA
        .vga_write_enable_i(vga_write_enable),
        .vga_addr_i(vga_addr),
        .vga_wdata_i(vga_wdata),
        .vga_rdata_o(vga_rdata),

        // Salidas VGA
        .vga_hsync_o(Hsync),
        .vga_vsync_o(Vsync),
        .vga_rgb_o(vga_rgb)
    );


    // ============================================================
    // 11. ADAPTACION RGB
    // ============================================================

    assign vgaRed   = vga_rgb[11:8];
    assign vgaGreen = vga_rgb[7:4];
    assign vgaBlue  = vga_rgb[3:0];


    // ============================================================
    // 12. VISUALIZACION MEDIANTE LEDs
    // ============================================================

    /*
     * Los LEDs 0 a 6 muestran las entradas DESPUES de
     * sincronizacion y debounce.
     *
     * LED0 -> UP       = BTNU
     * LED1 -> DOWN     = BTND
     * LED2 -> LEFT     = BTNL
     * LED3 -> RIGHT    = BTNR
     * LED4 -> SEL      = SW0
     * LED5 -> OK       = SW1
     * LED6 -> GAME_RST = BTNC
     *
     * LED14:
     *     VRAM completamente inicializada.
     *
     * LED15:
     *     indicador de Subsistema 2 habilitado.
     *
     * SW15 = 0 -> LED15 = 0 y reset aplicado
     * SW15 = 1 -> LED15 = 1 y funcionamiento normal
     */
    always_comb begin

        led = 16'b0;

        // Entradas filtradas.
        led[6:0] = input_status[6:0];

        // Inicializacion de VRAM terminada.
        led[14] = init_done_q;

        // Indicador RUN.
        led[15] = sw[15];

    end

endmodule
