module subsystem2_basys3_test_top (
    // ------------------------------------------------------------
    // Reloj principal de la Basys 3
    // ------------------------------------------------------------
    input  logic        clk,

    // ------------------------------------------------------------
    // Switches fisicos de la Basys 3
    //
    // SW0  -> GAME_RST
    // SW1  -> OK
    // SW15 -> Reset general del hardware
    // ------------------------------------------------------------
    input  logic [15:0] sw,

    // ------------------------------------------------------------
    // Push buttons fisicos
    //
    // BTNU -> UP
    // BTND -> DOWN
    // BTNL -> LEFT
    // BTNR -> RIGHT
    // BTNC -> SEL
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

    // Reset sincrono general del subsistema de prueba.
    // En esta prueba se activa mediante SW15.
    logic rst;

    assign rst = sw[15];


    // ============================================================
    // 2. SEÑALES DEL PERIFERICO DE ENTRADAS
    // ============================================================

    // Registro de 32 bits que representa el estado de las entradas
    // del Jugador 1 luego de sincronizacion y debounce.
    //
    // Mapa esperado:
    // bit 0 -> UP
    // bit 1 -> DOWN
    // bit 2 -> LEFT
    // bit 3 -> RIGHT
    // bit 4 -> SEL
    // bit 5 -> OK
    // bit 6 -> GAME_RST
    // bits 31:7 -> 0
    logic [31:0] input_status;


    // ============================================================
    // 3. INTERFAZ DE ESCRITURA HACIA LA MEMORIA VGA
    // ============================================================

    // Habilita una escritura sobre la memoria de video.
    logic        vga_write_enable;

    // Direccion local de tile.
    // Se requieren 9 bits porque existen hasta 512 posiciones,
    // aunque solamente 300 tiles son visibles.
    logic [8:0]  vga_addr;

    // Palabra de 32 bits que se escribe en cada tile.
    logic [31:0] vga_wdata;

    // Dato leido desde la memoria VGA.
    // En este top de prueba no es necesario utilizarlo,
    // pero se conserva para respetar la interfaz del subsistema.
    logic [31:0] vga_rdata;


    // ============================================================
    // 4. SALIDA RGB INTERNA DEL SUBSISTEMA
    // ============================================================

    // El renderer del Subsistema 2 genera RGB de 12 bits:
    //
    // [11:8] -> rojo
    // [7:4]  -> verde
    // [3:0]  -> azul
    logic [11:0] vga_rgb;


    // ============================================================
    // 5. REGISTROS PARA INICIALIZAR LA VRAM
    // ============================================================

    // Direccion lineal del tile actual.
    // Recorre desde 0 hasta 299.
    logic [8:0] init_addr_q;

    // Columna del tile actual.
    // Existen 20 columnas: 0 ... 19.
    logic [4:0] init_col_q;

    // Fila del tile actual.
    // Existen 15 filas: 0 ... 14.
    logic [3:0] init_row_q;

    // Indica que los 300 tiles visibles ya fueron inicializados.
    logic       init_done_q;

    // Palabra del tile que se escribira en la VRAM.
    logic [31:0] demo_tile;


    // ============================================================
    // 6. FUNCION PARA CONSTRUIR UNA PALABRA DE TILE
    // ============================================================

    /*
     * Formato de cada palabra almacenada en la memoria de video:
     *
     * [31:12] = reservados, siempre 0
     * [11:4]  = caracter ASCII
     * [3]     = glyph_enable
     * [2:0]   = codigo de color
     *
     * La funcion permite construir la palabra completa sin tener
     * que concatenar manualmente estos campos en cada asignacion.
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
     * Este bloque genera el contenido que se escribe inicialmente
     * en los 300 tiles visibles.
     *
     * Su unica funcion es crear una imagen conocida para comprobar:
     *
     * - memoria de video
     * - renderer
     * - colores
     * - caracteres
     * - distribucion de los tableros
     *
     * No contiene logica real del juego Batalla Naval.
     */
    always_comb begin

        // --------------------------------------------------------
        // Valor por defecto: fondo negro.
        // --------------------------------------------------------
        demo_tile = make_tile(
            3'd0,      // color negro
            1'b0,      // glyph deshabilitado
            8'h20      // espacio ASCII
        );


        // --------------------------------------------------------
        // Tablero izquierdo
        //
        // Filas:    4 ... 11
        // Columnas: 1 ... 8
        // --------------------------------------------------------
        if ((init_row_q >= 4) && (init_row_q <= 11) &&
            (init_col_q >= 1) && (init_col_q <= 8)) begin

            demo_tile = make_tile(
                3'd1,      // agua
                1'b0,
                8'h20
            );
        end


        // --------------------------------------------------------
        // Tablero derecho
        //
        // Filas:    4 ... 11
        // Columnas: 11 ... 18
        // --------------------------------------------------------
        if ((init_row_q >= 4) && (init_row_q <= 11) &&
            (init_col_q >= 11) && (init_col_q <= 18)) begin

            demo_tile = make_tile(
                3'd1,      // agua
                1'b0,
                8'h20
            );
        end


        // --------------------------------------------------------
        // Barcos de prueba sobre el tablero izquierdo.
        // --------------------------------------------------------

        // Barco horizontal de longitud 3.
        if ((init_row_q == 6) &&
            (init_col_q >= 3) && (init_col_q <= 5)) begin

            demo_tile = make_tile(
                3'd2,      // barco propio
                1'b0,
                8'h20
            );
        end

        // Barco horizontal de longitud 2.
        if ((init_row_q == 9) &&
            (init_col_q >= 6) && (init_col_q <= 7)) begin

            demo_tile = make_tile(
                3'd2,
                1'b0,
                8'h20
            );
        end


        // --------------------------------------------------------
        // Casilla de impacto sobre el tablero derecho.
        // --------------------------------------------------------
        if ((init_row_q == 6) && (init_col_q == 13)) begin
            demo_tile = make_tile(
                3'd3,      // impacto
                1'b0,
                8'h20
            );
        end


        // --------------------------------------------------------
        // Casilla de fallo.
        // --------------------------------------------------------
        if ((init_row_q == 8) && (init_col_q == 16)) begin
            demo_tile = make_tile(
                3'd4,      // fallo
                1'b0,
                8'h20
            );
        end


        // --------------------------------------------------------
        // Cursor de prueba.
        // --------------------------------------------------------
        if ((init_row_q == 5) && (init_col_q == 12)) begin
            demo_tile = make_tile(
                3'd5,      // cursor
                1'b0,
                8'h20
            );
        end


        // --------------------------------------------------------
        // Tile de color de HUD.
        // --------------------------------------------------------
        if ((init_row_q == 0) && (init_col_q == 0)) begin
            demo_tile = make_tile(
                3'd6,      // color HUD
                1'b0,
                8'h20
            );
        end


        // ========================================================
        // TEXTO DE PRUEBA
        // ========================================================

        // --------------------------------------------------------
        // Titulo "P1"
        // --------------------------------------------------------
        if ((init_row_q == 1) && (init_col_q == 3)) begin
            demo_tile = make_tile(
                3'd0,
                1'b1,      // habilita glyph
                8'h50      // ASCII 'P'
            );
        end

        if ((init_row_q == 1) && (init_col_q == 4)) begin
            demo_tile = make_tile(
                3'd0,
                1'b1,
                8'h31      // ASCII '1'
            );
        end


        // --------------------------------------------------------
        // Titulo "P2"
        // --------------------------------------------------------
        if ((init_row_q == 1) && (init_col_q == 13)) begin
            demo_tile = make_tile(
                3'd0,
                1'b1,
                8'h50      // ASCII 'P'
            );
        end

        if ((init_row_q == 1) && (init_col_q == 14)) begin
            demo_tile = make_tile(
                3'd0,
                1'b1,
                8'h32      // ASCII '2'
            );
        end


        // --------------------------------------------------------
        // Mensaje "TEST"
        // --------------------------------------------------------

        if ((init_row_q == 13) && (init_col_q == 8)) begin
            demo_tile = make_tile(
                3'd0,
                1'b1,
                8'h54      // T
            );
        end

        if ((init_row_q == 13) && (init_col_q == 9)) begin
            demo_tile = make_tile(
                3'd0,
                1'b1,
                8'h45      // E
            );
        end

        if ((init_row_q == 13) && (init_col_q == 10)) begin
            demo_tile = make_tile(
                3'd0,
                1'b1,
                8'h53      // S
            );
        end

        if ((init_row_q == 13) && (init_col_q == 11)) begin
            demo_tile = make_tile(
                3'd0,
                1'b1,
                8'h54      // T
            );
        end

    end


    // ============================================================
    // 8. MAQUINA SECUENCIAL DE INICIALIZACION DE VRAM
    // ============================================================

    /*
     * Se escribe un tile por ciclo de reloj.
     *
     * La pantalla tiene:
     *
     * 20 columnas x 15 filas = 300 tiles
     *
     * init_addr_q:
     *     direccion lineal 0 ... 299
     *
     * init_col_q:
     *     columna 0 ... 19
     *
     * init_row_q:
     *     fila 0 ... 14
     *
     * Cuando se alcanza la direccion 299 se activa init_done_q
     * y se detienen las escrituras.
     */
    always_ff @(posedge clk) begin

        if (rst) begin

            // Reinicia el recorrido de la VRAM.
            init_addr_q <= 9'd0;
            init_col_q  <= 5'd0;
            init_row_q  <= 4'd0;

            // Indica que todavia falta inicializar la memoria.
            init_done_q <= 1'b0;

        end
        else if (!init_done_q) begin

            // Ultimo tile visible.
            if (init_addr_q == 9'd299) begin

                // Finaliza la inicializacion.
                init_done_q <= 1'b1;

            end
            else begin

                // Avanza a la siguiente direccion.
                init_addr_q <= init_addr_q + 1'b1;


                // Si se llego al final de una fila...
                if (init_col_q == 5'd19) begin

                    // Regresa a la columna cero.
                    init_col_q <= 5'd0;

                    // Avanza a la siguiente fila.
                    init_row_q <= init_row_q + 1'b1;

                end
                else begin

                    // Avanza una columna.
                    init_col_q <= init_col_q + 1'b1;

                end
            end
        end
    end


    // ============================================================
    // 9. INTERFAZ HACIA LA VRAM
    // ============================================================

    /*
     * Mientras init_done_q sea 0:
     *
     *     write_enable = 1
     *
     * y se escribe un tile por ciclo.
     *
     * Cuando termina la inicializacion:
     *
     *     write_enable = 0
     *
     * y la memoria deja de modificarse desde este top de prueba.
     */
    assign vga_write_enable = !init_done_q;

    // Direccion actual de escritura.
    assign vga_addr = init_addr_q;

    // Contenido generado para el tile actual.
    assign vga_wdata = demo_tile;


    // ============================================================
    // 10. INSTANCIA DEL SUBSISTEMA 2
    // ============================================================

    /*
     * Este modulo integra:
     *
     * - periferico de entradas
     * - sincronizacion de botones
     * - debounce
     * - memoria de video
     * - reloj de pixel
     * - VGA timing
     * - glyph ROM
     * - tile renderer
     *
     * El parametro INPUT_DEBOUNCE_CYCLES define cuantos ciclos
     * debe permanecer estable una entrada antes de ser aceptada.
     *
     * A 100 MHz:
     *
     * 1_000_000 ciclos ≈ 10 ms
     */
    subsystem2_vga_inputs #(
        .INPUT_DEBOUNCE_CYCLES(1_000_000)
    ) u_subsystem2 (

        // --------------------------------------------------------
        // Reloj y reset
        // --------------------------------------------------------
        .clk_100_i(clk),
        .rst_i(rst),


        // --------------------------------------------------------
        // Botones direccionales
        // --------------------------------------------------------
        .up_i(btnU),
        .down_i(btnD),
        .left_i(btnL),
        .right_i(btnR),


        // --------------------------------------------------------
        // Controles adicionales
        //
        // NUEVA ASIGNACION:
        //
        // BTNC -> SEL
        // SW1  -> OK
        // SW0  -> GAME_RST
        //
        // Esto solamente cambia la interfaz fisica.
        // El mapa MMIO permanece igual.
        // --------------------------------------------------------
        .sel_i(btnC),
        .ok_i(sw[1]),
        .game_rst_i(sw[0]),


        // --------------------------------------------------------
        // Interfaz del periferico de entradas
        //
        // Como esta prueba solamente lee las entradas:
        //
        // write_enable = 0
        //
        // Las escrituras no son necesarias.
        // --------------------------------------------------------
        .input_write_enable_i(1'b0),
        .input_addr_i(2'b00),
        .input_wdata_i(32'b0),
        .input_rdata_o(input_status),


        // --------------------------------------------------------
        // Interfaz del periferico VGA
        //
        // Este top simula el comportamiento de un bus/CPU
        // escribiendo directamente los tiles de prueba.
        // --------------------------------------------------------
        .vga_write_enable_i(vga_write_enable),
        .vga_addr_i(vga_addr),
        .vga_wdata_i(vga_wdata),
        .vga_rdata_o(vga_rdata),


        // --------------------------------------------------------
        // Salidas graficas
        // --------------------------------------------------------
        .vga_hsync_o(Hsync),
        .vga_vsync_o(Vsync),
        .vga_rgb_o(vga_rgb)
    );


    // ============================================================
    // 11. ADAPTACION DE RGB AL CONECTOR FISICO DE BASYS 3
    // ============================================================

    /*
     * El renderer entrega 12 bits:
     *
     *     RRRR GGGG BBBB
     *
     * y el conector VGA de Basys 3 tambien utiliza
     * cuatro bits por componente.
     */
    assign vgaRed   = vga_rgb[11:8];
    assign vgaGreen = vga_rgb[7:4];
    assign vgaBlue  = vga_rgb[3:0];


    // ============================================================
    // 12. VISUALIZACION DE LAS ENTRADAS MEDIANTE LEDs
    // ============================================================

    /*
     * Los LEDs muestran directamente el registro del periferico
     * de entradas DESPUES de sincronizacion y debounce.
     *
     * Esto permite comprobar fisicamente que el periferico entrega
     * niveles estables al sistema.
     *
     * LED0 -> UP
     * LED1 -> DOWN
     * LED2 -> LEFT
     * LED3 -> RIGHT
     * LED4 -> SEL      = BTNC
     * LED5 -> OK       = SW1
     * LED6 -> GAME_RST = SW0
     *
     * LED15:
     *     indica que los 300 tiles visibles de VRAM ya fueron
     *     inicializados.
     */
    always_comb begin

        // Todos los LEDs apagados por defecto.
        led = 16'b0;

        // Visualiza las siete entradas del jugador.
        led[6:0] = input_status[6:0];

        // Indicador independiente de inicializacion de VRAM.
        led[15] = init_done_q;

    end

endmodule