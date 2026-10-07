`timescale 1ns / 1ps

// Comprueba el arranque con SEL y OK ya activos usando el debounce físico.
// Esos niveles iniciales no deben interpretarse como jugadas nuevas.
module boot_switches_tb;
    logic clk = 1'b0;
    logic rst = 1'b1;
    logic sel = 1'b1, ok = 1'b1;
    wire tx;
    int checks = 0;
    int boot_cycles = 0;

    always #5 clk = ~clk;
    always @(posedge clk) if (!rst) boot_cycles++;

    battleship_top #(
        .ROM_INIT_FILE("program.hex"),
        .INPUT_DEBOUNCE_CYCLES(1_000_000)
    ) dut (
        .clk_i(clk), .rst_i(rst),
        .up_i(1'b0), .down_i(1'b0), .left_i(1'b0), .right_i(1'b0),
        .sel_i(sel), .ok_i(ok), .game_rst_i(1'b0),
        .uart_rx_i(1'b1), .uart_tx_o(tx)
    );

    task automatic comprobar(input bit condition, input string message);
        checks++;
        if (!condition) $fatal(1, "%s (t=%0t)", message, $time);
    endtask

    task automatic comprobar_sin_jugadas;
        comprobar(dut.mmio_inst.ram_inst.memory['hBA] === 32'b0,
                  "SEL y OK iniciales no avanzan el barco de J1");
        comprobar(dut.mmio_inst.ram_inst.memory['hBB] === 32'b0,
                  "SEL inicial no cambia la orientación");
        comprobar(dut.mmio_inst.ram_inst.memory['h88] === 32'b0,
                  "OK inicial no coloca el primer barco");
    endtask

    initial begin
        repeat (20) @(posedge clk);
        @(negedge clk); rst = 1'b0;
        // BTN_PREV está en 0x22F0. Su primera escritura fija los niveles iniciales.
        wait (dut.data_write_enable && dut.data_address == 32'h0000_22F0);
        comprobar(boot_cycles >= 1_000_000, "La inicialización espera el debounce de 10 ms");
        comprobar(dut.data_wdata === 32'h0000_0030,
                  "El programa captura SEL y OK ya filtrados al arrancar");
        @(negedge tx);
        repeat (250_000) @(posedge clk);
        #1;
        comprobar_sin_jugadas();
        @(negedge clk); sel = 0; ok = 0;
        repeat (1_100_000) @(posedge clk);
        #1;
        comprobar(dut.mmio_inst.ram_inst.memory['hBC] === 32'b0,
                  "El programa actualiza BTN_PREV al liberar los switches");
        comprobar_sin_jugadas();
        comprobar(dut.cpu_inst.control.fault_q === 1'b0, "El CPU continúa sin FAULT");
        $display("PASS boot_switches_tb: %0d comprobaciones", checks);
        $finish;
    end

    initial begin
        #40_000_000;
        $fatal(1, "Tiempo máximo excedido durante el arranque");
    end
endmodule
