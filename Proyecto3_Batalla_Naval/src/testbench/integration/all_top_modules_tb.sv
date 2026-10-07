`timescale 1ns / 1ps

// Prueba de humo autoverificable para todos los modulos top del Proyecto 3:
//   - basys3_top
//   - battleship_top
//   - subsystem2_basys3_test_top
//   - mmio_subsystem_top
//
// Las pruebas exhaustivas de cada subsistema permanecen en sus testbenches
// dedicados. Este archivo comprueba que los tops elaboran juntos y que sus
// conexiones principales funcionan de forma coherente en simulacion.
module all_top_modules_tb;
    localparam time CLK_PERIOD = 10ns;

    localparam logic [31:0] RAM_BASE          = 32'h0000_2000;
    localparam logic [31:0] INPUT_ADDRESS     = 32'h0001_0120;
    localparam logic [31:0] LED_ADDRESS       = 32'h0001_0138;
    localparam logic [31:0] VGA_BASE          = 32'h0001_1000;

    logic clk = 1'b0;

    // Entradas fisicas compartidas por los dos wrappers de Basys 3.
    logic [15:0] sw = 16'b0;
    logic btnU = 1'b0;
    logic btnD = 1'b0;
    logic btnL = 1'b0;
    logic btnR = 1'b0;
    logic btnC = 1'b0;

    // Salidas de basys3_top.
    logic        basys_uart_tx;
    logic [3:0]  basys_red;
    logic [3:0]  basys_green;
    logic [3:0]  basys_blue;
    logic        basys_hsync;
    logic        basys_vsync;
    logic [6:0]  basys_seg;
    logic        basys_dp;
    logic [3:0]  basys_an;
    logic [15:0] basys_led;
    logic        basys_buzzer;

    // Salidas de battleship_top instanciado directamente.
    logic        system_rst = 1'b1;
    logic [6:0]  system_inputs = 7'b0;
    logic        system_uart_tx;
    logic [3:0]  system_red;
    logic [3:0]  system_green;
    logic [3:0]  system_blue;
    logic        system_hsync;
    logic        system_vsync;
    logic [6:0]  system_seg;
    logic [3:0]  system_an;
    logic [1:0]  system_led;
    logic        system_buzzer;

    // Salidas del top fisico de prueba de VGA/entradas.
    logic [15:0] subsystem2_led;
    logic [3:0]  subsystem2_red;
    logic [3:0]  subsystem2_green;
    logic [3:0]  subsystem2_blue;
    logic        subsystem2_hsync;
    logic        subsystem2_vsync;

    // Interfaz directa del top MMIO.
    logic        mmio_rst = 1'b1;
    logic [31:0] mmio_addr = 32'b0;
    logic [31:0] mmio_wdata = 32'b0;
    logic        mmio_we = 1'b0;
    logic [31:0] mmio_rdata;
    logic        mmio_uart_tx;
    logic [6:0]  mmio_seg;
    logic [3:0]  mmio_an;
    logic [1:0]  mmio_led;
    logic        mmio_buzzer;
    logic [31:0] mmio_input_rdata = 32'h0000_0055;
    logic [31:0] mmio_vga_rdata = 32'hA5A5_5A5A;
    logic [1:0]  mmio_input_addr;
    logic [8:0]  mmio_vga_addr;
    logic        mmio_input_we;
    logic        mmio_vga_we;

    int verificaciones = 0;
    int errores = 0;

    always #(CLK_PERIOD / 2) clk = ~clk;

    basys3_top #(
        .ROM_INIT_FILE ("")
    ) dut_basys3 (
        .clk      (clk),
        .sw       (sw),
        .btnU     (btnU),
        .btnD     (btnD),
        .btnL     (btnL),
        .btnR     (btnR),
        .btnC     (btnC),
        .RsRx     (1'b1),
        .RsTx     (basys_uart_tx),
        .vgaRed   (basys_red),
        .vgaGreen (basys_green),
        .vgaBlue  (basys_blue),
        .Hsync    (basys_hsync),
        .Vsync    (basys_vsync),
        .seg      (basys_seg),
        .dp       (basys_dp),
        .an       (basys_an),
        .led      (basys_led),
        .JA1      (basys_buzzer)
    );

    // Se acelera solamente el debounce de esta instancia de simulacion.
    defparam dut_basys3.system_inst.INPUT_DEBOUNCE_CYCLES = 4;

    battleship_top #(
        .ROM_INIT_FILE          (""),
        .INPUT_DEBOUNCE_CYCLES  (4)
    ) dut_system (
        .clk_i       (clk),
        .rst_i       (system_rst),
        .up_i        (system_inputs[0]),
        .down_i      (system_inputs[1]),
        .left_i      (system_inputs[2]),
        .right_i     (system_inputs[3]),
        .sel_i       (system_inputs[4]),
        .ok_i        (system_inputs[5]),
        .game_rst_i  (system_inputs[6]),
        .uart_rx_i   (1'b1),
        .uart_tx_o   (system_uart_tx),
        .vga_red_o   (system_red),
        .vga_green_o (system_green),
        .vga_blue_o  (system_blue),
        .vga_hsync_o (system_hsync),
        .vga_vsync_o (system_vsync),
        .seg_o       (system_seg),
        .an_o        (system_an),
        .led_o       (system_led),
        .buzzer_o    (system_buzzer)
    );

    subsystem2_basys3_test_top dut_subsystem2 (
        .clk      (clk),
        .sw       (sw),
        .btnU     (btnU),
        .btnD     (btnD),
        .btnL     (btnL),
        .btnR     (btnR),
        .btnC     (btnC),
        .led      (subsystem2_led),
        .vgaRed   (subsystem2_red),
        .vgaGreen (subsystem2_green),
        .vgaBlue  (subsystem2_blue),
        .Hsync    (subsystem2_hsync),
        .Vsync    (subsystem2_vsync)
    );

    // Se acelera solamente el debounce de esta instancia de simulacion.
    defparam dut_subsystem2.u_subsystem2.INPUT_DEBOUNCE_CYCLES = 4;

    mmio_subsystem_top #(
        .FRAME_REFRESH_HZ (25_000_000)
    ) dut_mmio (
        .clk_i                (clk),
        .rst_i                (mmio_rst),
        .cpu_addr_i           (mmio_addr),
        .cpu_wdata_i          (mmio_wdata),
        .cpu_we_i             (mmio_we),
        .cpu_rdata_o          (mmio_rdata),
        .uart_rx_i            (1'b1),
        .uart_tx_o            (mmio_uart_tx),
        .seg_o                (mmio_seg),
        .an_o                 (mmio_an),
        .led_o                (mmio_led),
        .buzzer_o             (mmio_buzzer),
        .input_rdata_i        (mmio_input_rdata),
        .vga_rdata_i          (mmio_vga_rdata),
        .input_addr_o         (mmio_input_addr),
        .vga_addr_o           (mmio_vga_addr),
        .input_write_enable_o (mmio_input_we),
        .vga_write_enable_o   (mmio_vga_we)
    );

    task automatic verificar(input logic condicion, input string mensaje);
        verificaciones++;
        if (condicion !== 1'b1) begin
            errores++;
            $error("FALLO: %s (t=%0t)", mensaje, $time);
        end
    endtask

    task automatic escribir_mmio(
        input logic [31:0] direccion,
        input logic [31:0] valor
    );
        @(negedge clk);
        mmio_addr  = direccion;
        mmio_wdata = valor;
        mmio_we    = 1'b1;
        @(posedge clk);
        #1;
        @(negedge clk);
        mmio_we = 1'b0;
    endtask

    task automatic leer_mmio_verificar(
        input logic [31:0] direccion,
        input logic [31:0] esperado,
        input string mensaje
    );
        @(negedge clk);
        mmio_addr = direccion;
        mmio_we   = 1'b0;
        @(posedge clk);
        #1;
        verificar(mmio_rdata === esperado, mensaje);
    endtask

    initial begin
        logic [31:0] pc_inicial_system;
        logic [31:0] pc_inicial_basys3;
        bit hsync_basys3_observado;
        bit hsync_system_observado;
        bit hsync_subsystem2_observado;

        $display("========================================");
        $display("PRUEBA DE TODOS LOS MODULOS TOP");
        $display("========================================");

        // Reset inicial de todos los tops.
        repeat (6) @(posedge clk);
        #1;
        verificar(dut_basys3.rst === 1'b1,
                  "basys3_top inicia en reset");
        verificar(dut_subsystem2.rst === 1'b1,
                  "subsystem2_basys3_test_top inicia en reset");
        verificar(system_uart_tx === 1'b1 && mmio_uart_tx === 1'b1,
                  "UART permanece en reposo durante reset");
        verificar(system_led === 2'b00 && mmio_led === 2'b00,
                  "los registros LED se limpian durante reset");
        verificar(system_buzzer === 1'b0 && mmio_buzzer === 1'b0,
                  "los buzzers permanecen apagados durante reset");
        verificar(basys_dp === 1'b1,
                  "basys3_top mantiene apagado el punto decimal");
        verificar(basys_led[15] === 1'b0 && subsystem2_led[15:14] === 2'b00,
                  "los wrappers fisicos indican reset");

        // Liberacion de los resets sincronizados y directos.
        @(negedge clk);
        sw[15]    = 1'b1;
        system_rst = 1'b0;
        mmio_rst   = 1'b0;
        repeat (24) @(posedge clk);
        #1;
        verificar(dut_basys3.rst === 1'b0,
                  "basys3_top libera el reset sincronizado");
        verificar(dut_subsystem2.rst === 1'b0,
                  "top de prueba VGA libera el reset sincronizado");
        verificar(basys_led[15] === 1'b1 && subsystem2_led[15] === 1'b1,
                  "los wrappers fisicos indican funcionamiento");

        // CPU y ROM: con ROM vacia se ejecutan NOP sin entrar en FAULT.
        pc_inicial_system = dut_system.prog_address;
        pc_inicial_basys3 = dut_basys3.system_inst.prog_address;
        repeat (40) @(posedge clk);
        #1;
        verificar(dut_system.prog_address > pc_inicial_system,
                  "battleship_top conecta CPU y ROM");
        verificar(dut_basys3.system_inst.prog_address > pc_inicial_basys3,
                  "basys3_top permite avanzar al CPU");
        verificar(dut_system.cpu_inst.control.fault_q === 1'b0 &&
                  dut_basys3.system_inst.cpu_inst.control.fault_q === 1'b0,
                  "los CPU de ambos tops permanecen fuera de FAULT");

        // MMIO: RAM, LED y rutas externas de entradas/VGA.
        escribir_mmio(RAM_BASE, 32'h1234_ABCD);
        leer_mmio_verificar(RAM_BASE, 32'h1234_ABCD,
                            "mmio_subsystem_top escribe y lee RAM");

        escribir_mmio(LED_ADDRESS, 32'h0000_0002);
        verificar(mmio_led === 2'b10,
                  "mmio_subsystem_top actualiza el periferico LED");
        leer_mmio_verificar(LED_ADDRESS, 32'h0000_0002,
                            "mmio_subsystem_top lee el periferico LED");

        leer_mmio_verificar(INPUT_ADDRESS, mmio_input_rdata,
                            "MMIO enruta la lectura de entradas");
        verificar(mmio_input_addr === 2'b00,
                  "MMIO entrega la direccion local de entradas");

        leer_mmio_verificar(VGA_BASE, mmio_vga_rdata,
                            "MMIO enruta la lectura de VGA");
        verificar(mmio_vga_addr === 9'd0,
                  "MMIO entrega la direccion local de VGA");
        verificar(mmio_input_we === 1'b0 && mmio_vga_we === 1'b0,
                  "las lecturas MMIO no generan escrituras");

        // Entradas fisicas: sincronizacion, debounce y correspondencia de bits.
        @(negedge clk);
        btnU             = 1'b1;
        sw[0]            = 1'b1;
        system_inputs[0] = 1'b1;
        system_inputs[4] = 1'b1;
        repeat (16) @(posedge clk);
        #1;
        verificar(dut_system.vga_inputs_inst.u_player1_inputs.clean_levels[4:0]
                  === 5'b1_0001,
                  "battleship_top acondiciona UP y SEL");
        verificar(dut_basys3.system_inst.vga_inputs_inst.u_player1_inputs.clean_levels[4:0]
                  === 5'b1_0001,
                  "basys3_top conecta correctamente UP y SEL");
        verificar(subsystem2_led[4:0] === 5'b1_0001,
                  "top fisico VGA refleja las entradas filtradas");

        @(negedge clk);
        btnU             = 1'b0;
        sw[0]            = 1'b0;
        system_inputs    = 7'b0;
        repeat (16) @(posedge clk);

        // El top de prueba debe terminar la carga de sus 300 tiles.
        repeat (320) @(posedge clk);
        #1;
        verificar(subsystem2_led[14] === 1'b1,
                  "top fisico VGA termina la inicializacion de VRAM");

        // Actividad y valores definidos en las tres rutas VGA.
        hsync_basys3_observado    = 1'b0;
        hsync_system_observado    = 1'b0;
        hsync_subsystem2_observado = 1'b0;
        fork
            begin @(negedge basys_hsync);      hsync_basys3_observado = 1'b1; end
            begin @(negedge system_hsync);     hsync_system_observado = 1'b1; end
            begin @(negedge subsystem2_hsync); hsync_subsystem2_observado = 1'b1; end
            begin repeat (5_000) @(posedge clk); end
        join
        #1;
        verificar(hsync_basys3_observado && hsync_system_observado &&
                  hsync_subsystem2_observado,
                  "todos los tops generan sincronismo horizontal VGA");
        verificar(!$isunknown({basys_red, basys_green, basys_blue,
                               system_red, system_green, system_blue,
                               subsystem2_red, subsystem2_green,
                               subsystem2_blue}),
                  "las salidas RGB de todos los tops tienen valores definidos");
        verificar({system_red, system_green, system_blue}
                  === dut_system.vga_rgb,
                  "battleship_top divide correctamente el bus RGB");
        verificar({subsystem2_red, subsystem2_green, subsystem2_blue}
                  === dut_subsystem2.vga_rgb,
                  "top fisico VGA divide correctamente el bus RGB");

        // Para demostrar que la autoverificacion detecta fallos, descomente
        // exactamente la siguiente linea. La simulacion terminara con $fatal:
        // verificar(1'b0, "FALLO INTENCIONAL PARA PROBAR LA AUTOVERIFICACION");

        // Reset final para comprobar que todos los tops siguen respondiendo.
        @(negedge clk);
        sw[15]     = 1'b0;
        system_rst = 1'b1;
        mmio_rst   = 1'b1;
        repeat (6) @(posedge clk);
        #1;
        verificar(dut_basys3.rst === 1'b1 && dut_subsystem2.rst === 1'b1,
                  "los wrappers fisicos vuelven a reset");
        verificar(system_uart_tx === 1'b1 && mmio_uart_tx === 1'b1,
                  "reset final devuelve UART a reposo");
        verificar(system_led === 2'b00 && mmio_led === 2'b00,
                  "reset final limpia los LED MMIO");

        if (errores == 0) begin
            $display("all_top_modules_tb: TODAS LAS PRUEBAS PASARON (%0d verificaciones)",
                     verificaciones);
        end else begin
            $fatal(1,
                   "all_top_modules_tb: %0d errores en %0d verificaciones",
                   errores, verificaciones);
        end
        $finish;
    end

    initial begin
        #1ms;
        $fatal(1, "all_top_modules_tb: TIEMPO MAXIMO EXCEDIDO");
    end
endmodule
