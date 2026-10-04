`timescale 1ns / 1ps

// =============================================================================
// Proyecto 3 - Batalla Naval
// Subsistema 2 - VGA + entradas del Jugador 1
//
// Prueba de aceptación del PERIFÉRICO COMPLETO.
//
// Criterio de esta prueba:
//   - El DUT se trata como caja negra.
//   - Solo se estimulan entradas externas del periférico.
//   - Solo se comprueban salidas externas del periférico.
//   - No se consultan señales internas ni jerarquías del DUT.
//   - El resultado es completamente autoverificable mediante PASS / FAIL.
//
// DUT:
//   subsystem2_vga_inputs
// =============================================================================

module tb_subsystem2_peripheral;

    // -------------------------------------------------------------------------
    // Configuración de simulación
    // -------------------------------------------------------------------------

    // En hardware se utiliza 1_000_000. En simulación se reduce para acelerar
    // la comprobación sin cambiar la función lógica del periférico.
    localparam int unsigned TEST_DEBOUNCE_CYCLES = 4;

    // Paleta definida para el periférico VGA.
    localparam logic [11:0] RGB_BLACK  = 12'h000;
    localparam logic [11:0] RGB_WATER  = 12'h04F;
    localparam logic [11:0] RGB_CURSOR = 12'hFF0;
    localparam logic [11:0] RGB_GLYPH  = 12'hFFF;

    // Temporización VGA nominal a 25 MHz.
    localparam realtime HSYNC_LOW_NS    = 3_840.0;   // 96 píxeles * 40 ns
    localparam realtime HSYNC_PERIOD_NS = 32_000.0;  // 800 píxeles * 40 ns
    localparam realtime VSYNC_LOW_NS    = 64_000.0;  // 2 líneas * 800 * 40 ns

    // Se permite una pequeña tolerancia para evitar depender de detalles de
    // delta-cycles del modelo de simulación.
    localparam realtime VGA_TIME_TOL_NS = 100.0;

    // -------------------------------------------------------------------------
    // Entradas / salidas externas del periférico
    // -------------------------------------------------------------------------

    logic clk_100_i;
    logic rst_i;

    logic up_i;
    logic down_i;
    logic left_i;
    logic right_i;
    logic sel_i;
    logic ok_i;
    logic game_rst_i;

    logic        input_write_enable_i;
    logic [1:0]  input_addr_i;
    logic [31:0] input_wdata_i;
    logic [31:0] input_rdata_o;

    logic        vga_write_enable_i;
    logic [8:0]  vga_addr_i;
    logic [31:0] vga_wdata_i;
    logic [31:0] vga_rdata_o;

    logic        vga_hsync_o;
    logic        vga_vsync_o;
    logic [11:0] vga_rgb_o;

    int unsigned checks;
    int unsigned errors;

    // =========================================================================
    // DUT - periférico completo
    // =========================================================================

    subsystem2_vga_inputs #(
        .INPUT_DEBOUNCE_CYCLES(TEST_DEBOUNCE_CYCLES)
    ) dut (
        .clk_100_i            (clk_100_i),
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
        .input_rdata_o        (input_rdata_o),

        .vga_write_enable_i   (vga_write_enable_i),
        .vga_addr_i           (vga_addr_i),
        .vga_wdata_i          (vga_wdata_i),
        .vga_rdata_o          (vga_rdata_o),

        .vga_hsync_o          (vga_hsync_o),
        .vga_vsync_o          (vga_vsync_o),
        .vga_rgb_o            (vga_rgb_o)
    );

    // =========================================================================
    // Reloj principal: 100 MHz
    // =========================================================================

    always #5 clk_100_i = ~clk_100_i;

    // =========================================================================
    // Checker genérico
    // =========================================================================

    task automatic check(
        input logic  condition,
        input string message
    );
        begin
            checks++;

            if (condition !== 1'b1) begin
                errors++;
                $display("[FAIL] %s", message);
            end
            else begin
                $display("[PASS] %s", message);
            end
        end
    endtask

    // =========================================================================
    // Checker de intervalos temporales
    // =========================================================================

    task automatic check_time(
        input realtime observed_ns,
        input realtime expected_ns,
        input realtime tolerance_ns,
        input string   message
    );
        realtime minimum_ns;
        realtime maximum_ns;
        begin
            minimum_ns = expected_ns - tolerance_ns;
            maximum_ns = expected_ns + tolerance_ns;

            checks++;

            if ((observed_ns < minimum_ns) ||
                (observed_ns > maximum_ns)) begin
                errors++;
                $display(
                    "[FAIL] %s | observado = %0.1f ns | esperado = %0.1f ns",
                    message,
                    observed_ns,
                    expected_ns
                );
            end
            else begin
                $display(
                    "[PASS] %s | observado = %0.1f ns",
                    message,
                    observed_ns
                );
            end
        end
    endtask

    // =========================================================================
    // Construcción de palabra de tile
    //
    // [31:12] reservados
    // [11:4]  ASCII
    // [3]     GLYPH_ENABLE
    // [2:0]   COLOR
    // =========================================================================

    function automatic logic [31:0] make_tile(
        input logic [2:0] color,
        input logic       glyph_enable,
        input logic [7:0] ascii
    );
        begin
            make_tile = {
                20'b0,
                ascii,
                glyph_enable,
                color
            };
        end
    endfunction

    // =========================================================================
    // Acceso externo al puerto VGA/MMIO
    // =========================================================================

    task automatic vga_write(
        input logic [8:0]  address,
        input logic [31:0] data
    );
        begin
            @(negedge clk_100_i);

            vga_addr_i         = address;
            vga_wdata_i        = data;
            vga_write_enable_i = 1'b1;

            @(posedge clk_100_i);
            #1;

            @(negedge clk_100_i);
            vga_write_enable_i = 1'b0;
        end
    endtask

    task automatic vga_read_check(
        input logic [8:0]  address,
        input logic [31:0] expected,
        input string       message
    );
        begin
            @(negedge clk_100_i);

            vga_addr_i         = address;
            vga_write_enable_i = 1'b0;

            @(posedge clk_100_i);
            #1;

            check(
                vga_rdata_o === expected,
                message
            );
        end
    endtask

    // Escribe el mismo patrón en los 300 tiles visibles.
    task automatic fill_visible_tiles(
        input logic [31:0] data
    );
        int unsigned i;
        begin
            for (i = 0; i < 300; i++) begin
                vga_write(i[8:0], data);
            end
        end
    endtask

    // =========================================================================
    // Estímulo externo de las siete entradas del Jugador 1
    //
    // bits:
    // [0] UP
    // [1] DOWN
    // [2] LEFT
    // [3] RIGHT
    // [4] SEL
    // [5] OK
    // [6] GAME_RST
    // =========================================================================

    task automatic drive_player_inputs(
        input logic [6:0] levels
    );
        begin
            @(negedge clk_100_i);

            up_i       = levels[0];
            down_i     = levels[1];
            left_i     = levels[2];
            right_i    = levels[3];
            sel_i      = levels[4];
            ok_i       = levels[5];
            game_rst_i = levels[6];

            // 2 FF de sincronización + debounce + margen.
            repeat (TEST_DEBOUNCE_CYCLES + 8)
                @(posedge clk_100_i);

            #1;
        end
    endtask

    task automatic check_input_status(
        input logic [6:0] expected,
        input string      message
    );
        begin
            input_addr_i = 2'b00;
            #1;

            check(
                input_rdata_o === {25'b0, expected},
                message
            );
        end
    endtask

    // =========================================================================
    // Espera de un color en la salida EXTERNA RGB con timeout
    // =========================================================================

    task automatic wait_rgb_check(
        input logic [11:0] expected_rgb,
        input time         timeout_ns,
        input string       message
    );
        bit seen;
        begin
            seen = 1'b0;

            fork : rgb_wait
                begin
                    wait (vga_rgb_o === expected_rgb);
                    seen = 1'b1;
                end

                begin
                    #(timeout_ns);
                end
            join_any

            disable rgb_wait;

            check(seen, message);
        end
    endtask

    // =========================================================================
    // Comprobación externa de HSYNC
    // =========================================================================

    task automatic check_hsync_output;
        realtime fall_1;
        realtime rise_1;
        realtime fall_2;
        begin
            // Evita interpretar una transición X->0 como pulso válido.
            wait (vga_hsync_o === 1'b1);

            @(negedge vga_hsync_o);
            fall_1 = $realtime;

            // Durante HSYNC estamos fuera del área visible.
            #1;
            check(
                vga_rgb_o === RGB_BLACK,
                "VGA RGB is black during horizontal blanking"
            );

            @(posedge vga_hsync_o);
            rise_1 = $realtime;

            check_time(
                rise_1 - fall_1,
                HSYNC_LOW_NS,
                VGA_TIME_TOL_NS,
                "HSYNC low pulse width is correct"
            );

            @(negedge vga_hsync_o);
            fall_2 = $realtime;

            check_time(
                fall_2 - fall_1,
                HSYNC_PERIOD_NS,
                VGA_TIME_TOL_NS,
                "HSYNC line period is correct"
            );
        end
    endtask

    // =========================================================================
    // Comprobación externa de VSYNC
    // =========================================================================

    task automatic check_vsync_output;
        realtime fall_time;
        realtime rise_time;
        begin
            wait (vga_vsync_o === 1'b1);

            @(negedge vga_vsync_o);
            fall_time = $realtime;

            @(posedge vga_vsync_o);
            rise_time = $realtime;

            check_time(
                rise_time - fall_time,
                VSYNC_LOW_NS,
                VGA_TIME_TOL_NS,
                "VSYNC low pulse width is correct"
            );
        end
    endtask

    // =========================================================================
    // Watchdog global
    //
    // Si una salida esperada nunca aparece, la simulación no queda colgada.
    // =========================================================================

    initial begin : watchdog
        #60_000_000;  // 60 ms

        $display("");
        $display("============================================================");
        $display("FATAL: PERIPHERAL TEST TIMEOUT");
        $display("============================================================");

        $finish;
    end

    // =========================================================================
    // Secuencia principal
    // =========================================================================

    initial begin

        // ---------------------------------------------------------------------
        // Inicialización
        // ---------------------------------------------------------------------

        clk_100_i = 1'b0;
        rst_i     = 1'b1;

        up_i       = 1'b0;
        down_i     = 1'b0;
        left_i     = 1'b0;
        right_i    = 1'b0;
        sel_i      = 1'b0;
        ok_i       = 1'b0;
        game_rst_i = 1'b0;

        input_write_enable_i = 1'b0;
        input_addr_i         = 2'b00;
        input_wdata_i        = 32'b0;

        vga_write_enable_i = 1'b0;
        vga_addr_i         = 9'd0;
        vga_wdata_i        = 32'b0;

        checks = 0;
        errors = 0;

        $display("");
        $display("============================================================");
        $display("SUBSYSTEM 2 - BLACK-BOX PERIPHERAL ACCEPTANCE TEST");
        $display("VGA + PLAYER 1 INPUTS");
        $display("============================================================");
        $display("");

        // =====================================================================
        // 1. RESET GENERAL
        // =====================================================================

        repeat (5) @(posedge clk_100_i);
        #1;

        check(
            input_rdata_o === 32'h0000_0000,
            "Reset clears Player 1 MMIO output"
        );

        check(
            vga_rdata_o === 32'h0000_0000,
            "Reset clears VGA MMIO read output"
        );

        @(negedge clk_100_i);
        rst_i = 1'b0;

        // =====================================================================
        // 2. ENTRADAS DEL JUGADOR 1 -> SALIDA MMIO
        // =====================================================================

        drive_player_inputs(7'b0000001);
        check_input_status(7'b0000001, "UP maps to MMIO bit 0");

        drive_player_inputs(7'b0000010);
        check_input_status(7'b0000010, "DOWN maps to MMIO bit 1");

        drive_player_inputs(7'b0000100);
        check_input_status(7'b0000100, "LEFT maps to MMIO bit 2");

        drive_player_inputs(7'b0001000);
        check_input_status(7'b0001000, "RIGHT maps to MMIO bit 3");

        drive_player_inputs(7'b0010000);
        check_input_status(7'b0010000, "SEL maps to MMIO bit 4");

        drive_player_inputs(7'b0100000);
        check_input_status(7'b0100000, "OK maps to MMIO bit 5");

        drive_player_inputs(7'b1000000);
        check_input_status(7'b1000000, "GAME_RST maps to MMIO bit 6");

        drive_player_inputs(7'b1111111);
        check_input_status(7'b1111111, "All Player 1 inputs produce 0x0000007F");

        // ---------------------------------------------------------------------
        // Escrituras al periférico de entradas deben ignorarse
        // ---------------------------------------------------------------------

        drive_player_inputs(7'b0010000);  // SEL activo

        input_write_enable_i = 1'b1;
        input_wdata_i        = 32'hFFFF_FFFF;

        @(posedge clk_100_i);
        #1;

        check_input_status(
            7'b0010000,
            "Input MMIO write does not modify filtered input state"
        );

        input_write_enable_i = 1'b0;
        input_wdata_i        = 32'b0;

        // ---------------------------------------------------------------------
        // Direcciones locales inválidas retornan cero
        // ---------------------------------------------------------------------

        input_addr_i = 2'b01;
        #1;
        check(
            input_rdata_o === 32'h0000_0000,
            "Input MMIO address 01 returns zero"
        );

        input_addr_i = 2'b10;
        #1;
        check(
            input_rdata_o === 32'h0000_0000,
            "Input MMIO address 10 returns zero"
        );

        input_addr_i = 2'b11;
        #1;
        check(
            input_rdata_o === 32'h0000_0000,
            "Input MMIO address 11 returns zero"
        );

        input_addr_i = 2'b00;

        drive_player_inputs(7'b0000000);
        check_input_status(7'b0000000, "Player 1 inputs return low after release");

        // =====================================================================
        // 3. INTERFAZ VGA/MMIO
        // =====================================================================

        vga_write(
            9'd0,
            make_tile(3'd1, 1'b0, 8'h20)
        );

        vga_read_check(
            9'd0,
            make_tile(3'd1, 1'b0, 8'h20),
            "VGA tile 0 supports CPU write/read"
        );

        vga_write(
            9'd299,
            make_tile(3'd5, 1'b0, 8'h20)
        );

        vga_read_check(
            9'd299,
            make_tile(3'd5, 1'b0, 8'h20),
            "VGA tile 299 supports CPU write/read"
        );

        // Índice reservado: la escritura debe ignorarse y la lectura dar cero.
        vga_write(
            9'd300,
            32'hDEAD_BEEF
        );

        vga_read_check(
            9'd300,
            32'h0000_0000,
            "Reserved VGA tile 300 ignores writes and reads zero"
        );

        // =====================================================================
        // 4. SALIDA RGB - CAMINO COMPLETO DEL PERIFÉRICO
        // =====================================================================
        //
        // Se llena toda la pantalla visible con un patrón conocido. Así la
        // comprobación solo necesita observar la salida física RGB; no necesita
        // conocer contadores ni señales internas del DUT.
        // =====================================================================

        fill_visible_tiles(
            make_tile(3'd1, 1'b0, 8'h20)
        );

        wait_rgb_check(
            RGB_WATER,
            20_000_000,
            "Water tile data reaches external VGA RGB output"
        );

        // =====================================================================
        // 5. HSYNC - SALIDA EXTERNA
        // =====================================================================

        check_hsync_output();

        // =====================================================================
        // 6. COLOR DE CURSOR - CAMINO CPU/MMIO -> VRAM -> RGB
        // =====================================================================

        fill_visible_tiles(
            make_tile(3'd5, 1'b0, 8'h20)
        );

        wait_rgb_check(
            RGB_CURSOR,
            20_000_000,
            "Cursor tile data reaches external VGA RGB output"
        );

        // =====================================================================
        // 7. GLYPH - CAMINO CPU/MMIO -> VRAM -> GLYPH -> RGB
        // =====================================================================

        fill_visible_tiles(
            make_tile(3'd1, 1'b1, 8'h41)  // fondo agua + ASCII 'A'
        );

        wait_rgb_check(
            RGB_GLYPH,
            20_000_000,
            "ASCII A produces visible glyph pixels on external RGB output"
        );

        // =====================================================================
        // 8. VSYNC - SALIDA EXTERNA
        // =====================================================================

        check_vsync_output();

        // =====================================================================
        // 9. RESET FINAL
        // =====================================================================

        @(negedge clk_100_i);
        rst_i = 1'b1;

        repeat (5) @(posedge clk_100_i);
        #1;

        input_addr_i = 2'b00;

        check(
            input_rdata_o === 32'h0000_0000,
            "Final reset clears Player 1 MMIO output"
        );

        check(
            vga_rdata_o === 32'h0000_0000,
            "Final reset clears VGA MMIO read output"
        );

        // =====================================================================
        // RESUMEN
        // =====================================================================

        $display("");
        $display("============================================================");
        $display("SUBSYSTEM 2 PERIPHERAL TEST SUMMARY");
        $display("Checks : %0d", checks);
        $display("Errors : %0d", errors);

        if (errors == 0) begin
            $display("RESULT : TEST PASSED");
        end
        else begin
            $display("RESULT : TEST FAILED");
        end

        $display("============================================================");
        $display("");

        $finish;
    end

endmodule
