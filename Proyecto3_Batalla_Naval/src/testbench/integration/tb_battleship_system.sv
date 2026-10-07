`timescale 1ns / 1ps

// Testbench del sistema completo: battleship_top ejecutando program.hex.
//
// El testbench actua como los dos jugadores siguiendo guion.txt:
//   ESPERA n               espera n ciclos de 100 MHz
//   BOTON m n              entradas de J1 = m durante n ciclos y luego 0 otros n
//                          m = {GAME_RST, OK, SEL, RIGHT, LEFT, DOWN, UP}
//   TX k b1 .. bk          envia k bytes por la linea serie (Jugador 2)
//   ESPERA_TRAMAS k max    espera a haber recibido k tramas en total
//   FOTO archivo           captura un cuadro VGA completo
//   VOLCADO                guarda RAM, memoria de video, LED y displays
//   FIN
// Las tramas que emite la FPGA se decodifican de uart_tx_o (tramas.txt) y las
// ordenes al buzzer se registran desde el bus (buzzer.txt).
// UART a 115200 baudios reales: la UART no tiene FIFO.
module tb_battleship_system;

    localparam int BIT = 868;

    logic       clk = 1'b0;
    logic       rst;
    logic [6:0] inputs = 7'd0;
    logic       rx = 1'b1;
    logic       tx;
    logic [3:0] red, green, blue, an;
    logic       hs, vs, buzzer;
    logic [6:0] seg;
    logic [1:0] leds;

    battleship_top #(
        .ROM_INIT_FILE         ("program.hex"),
        .INPUT_DEBOUNCE_CYCLES (50)
    ) dut (
        .clk_i       (clk),
        .rst_i       (rst),
        .up_i        (inputs[0]),
        .down_i      (inputs[1]),
        .left_i      (inputs[2]),
        .right_i     (inputs[3]),
        .sel_i       (inputs[4]),
        .ok_i        (inputs[5]),
        .game_rst_i  (inputs[6]),
        .uart_rx_i   (rx),
        .uart_tx_o   (tx),
        .vga_red_o   (red),
        .vga_green_o (green),
        .vga_blue_o  (blue),
        .vga_hsync_o (hs),
        .vga_vsync_o (vs),
        .seg_o       (seg),
        .an_o        (an),
        .led_o       (leds),
        .buzzer_o    (buzzer)
    );

    always #5 clk = ~clk;

    int n_ok = 0, n_fallos = 0;
    task automatic comprobar(input bit cond, input string msg);
        if (cond) n_ok++;
        else begin n_fallos++; $display("FALLO: %s (t=%0t)", msg, $time); end
    endtask

    // --- Contrato del bus con el programa real ---
    logic we_prev = 1'b0;
    int   we_largos = 0, ciclos_en_falla = 0, escrituras_bus = 0;
    always @(posedge clk) begin
        if (!rst) begin
            if (dut.data_write_enable) begin
                escrituras_bus++;
                if (we_prev) we_largos++;
            end
            if (dut.cpu_inst.control.fault_q) ciclos_en_falla++;
        end
        we_prev = dut.data_write_enable;
    end

    // --- Ordenes al buzzer ---
    int fd_buzz;
    always @(posedge clk)
        if (!rst && dut.data_write_enable && dut.data_address == 32'h0001_0140)
            $fdisplay(fd_buzz, "%0d", dut.data_wdata);

    // --- Receptor serie: decodifica bytes y arma tramas ---
    int tramas = 0, fd_tramas;
    logic [7:0] trama [$];
    initial begin
        forever begin
            logic [7:0] byte_rx;
            @(negedge tx);
            repeat (BIT / 2) @(posedge clk);
            if (tx == 1'b0) begin
                for (int k = 0; k < 8; k++) begin repeat (BIT) @(posedge clk); byte_rx[k] = tx; end
                repeat (BIT) @(posedge clk);
                comprobar(tx == 1'b1, "bit de parada correcto");
                if (trama.size() == 0 && byte_rx != 8'hA5) begin
                    comprobar(0, $sformatf("byte %h fuera de trama", byte_rx));
                end else begin
                    trama.push_back(byte_rx);
                    if (trama.size() >= 3 && trama.size() == 3 + trama[2]) begin
                        string linea;
                        linea = $sformatf("%0d", trama[1]);
                        for (int k = 3; k < trama.size(); k++) linea = {linea, $sformatf(" %0d", trama[k])};
                        $fdisplay(fd_tramas, "%s", linea);
                        $fflush(fd_tramas);
                        tramas++;
                        trama.delete();
                    end
                end
            end
        end
    end

    // --- Transmisor serie del Jugador 2 ---
    task automatic enviar_byte(input logic [7:0] v);
        @(negedge clk);
        rx = 1'b0; repeat (BIT) @(negedge clk);
        for (int k = 0; k < 8; k++) begin rx = v[k]; repeat (BIT) @(negedge clk); end
        rx = 1'b1; repeat (BIT) @(negedge clk);
    endtask

    // Limite global incluso si el guion o una captura no terminan.
    initial begin
        #600_000_000;
        $fatal(1, "Tiempo de espera del sistema agotado");
    end

    // --- Captura de un cuadro VGA (coordenadas desde los sincronismos) ---
    task automatic foto(input string archivo);
        int fd, hx, linea;
        bit tras_vsync, activo;
        logic hs_prev;
        fd = $fopen(archivo, "w");
        @(negedge vs);
        tras_vsync = 1; linea = -1000; hx = 0; hs_prev = hs; activo = 1;
        while (activo) begin
            @(posedge dut.vga_inputs_inst.u_pixel_clock.clk_pixel_o); #1;
            if (hs_prev && !hs) begin
                if (tras_vsync) begin linea = -34; tras_vsync = 0; end else linea++;
                hx = 0;
            end else hx++;
            hs_prev = hs;
            if (linea >= 0 && linea < 480 && hx >= 144 && hx < 784)
                $fdisplay(fd, "%h%h%h", red, green, blue);
            if (linea == 480 && hx == 0) activo = 0;
        end
        $fclose(fd);
    endtask

    task automatic volcado();
        int fd;
        fd = $fopen("estado_sistema.txt", "w");
        for (int k = 0; k < 256; k++)
            $fdisplay(fd, "M %h %h", 32'h2000 + 4 * k, dut.mmio_inst.ram_inst.memory[k]);
        for (int k = 0; k < 300; k++)
            $fdisplay(fd, "V %0d %h", k, dut.vga_inputs_inst.u_video_memory.memory[k]);
        $fdisplay(fd, "LED %0d", dut.mmio_inst.led_inst.state_q);
        $fdisplay(fd, "DISPLAY %h", {dut.mmio_inst.sevenseg_inst.j2_wins_q,
                                     dut.mmio_inst.sevenseg_inst.j1_wins_q});
        $fclose(fd);
    endtask

    // --- Interprete del guion ---
    initial begin
        int fd, n, m, k, maximo;
        string cmd, archivo;
        fd_tramas = $fopen("tramas.txt", "w");
        fd_buzz   = $fopen("buzzer.txt", "w");
        if (!fd_tramas || !fd_buzz) $fatal(1, "No se pueden escribir los resultados");
        rst = 1'b1;
        repeat (20) @(posedge clk);
        @(negedge clk); rst = 1'b0;

        fd = $fopen("guion.txt", "r");
        if (!fd) $fatal(1, "No se encontro guion.txt");
        while (!$feof(fd)) begin
            if ($fscanf(fd, "%s", cmd) != 1) break;
            if (cmd == "ESPERA") begin
                void'($fscanf(fd, "%d", n));
                repeat (n) @(posedge clk);
            end else if (cmd == "BOTON") begin
                void'($fscanf(fd, "%d %d", m, n));
                @(negedge clk); inputs = m[6:0];
                repeat (n) @(posedge clk);
                @(negedge clk); inputs = 7'd0;
                repeat (n) @(posedge clk);
            end else if (cmd == "TX") begin
                void'($fscanf(fd, "%d", n));
                for (int i = 0; i < n; i++) begin
                    void'($fscanf(fd, "%d", k));
                    enviar_byte(k[7:0]);
                end
            end else if (cmd == "ESPERA_TRAMAS") begin
                void'($fscanf(fd, "%d %d", n, maximo));
                k = 0;
                while (tramas < n && k < maximo) begin @(posedge clk); k++; end
                comprobar(tramas >= n, $sformatf("llegan %0d tramas (hay %0d)", n, tramas));
            end else if (cmd == "FOTO") begin
                void'($fscanf(fd, "%s", archivo));
                foto(archivo);
            end else if (cmd == "VOLCADO") begin
                volcado();
            end else if (cmd == "FIN") begin
                break;
            end else begin
                $fatal(1, "Orden de guion desconocida: %s", cmd);
            end
        end
        $fclose(fd);
        $fclose(fd_tramas);
        $fclose(fd_buzz);
        comprobar(we_largos == 0, $sformatf("la escritura dura un ciclo (%0d escrituras)", escrituras_bus));
        comprobar(ciclos_en_falla == 0, "el CPU nunca entra en FAULT durante la partida");
        $display("CICLOS_SIMULADOS %0d", $time / 10);
        $display("RESUMEN tb_battleship_system: %0d comprobaciones, %0d fallos", n_ok + n_fallos, n_fallos);
        if (n_fallos != 0) $fatal(1, "El sistema no cumple las comprobaciones");
        $display("PASS tb_battleship_system");
        $finish;
    end
endmodule
