`timescale 1ns / 1ps

// Verifica los controles físicos de ambos tops después del sincronizador
// y del filtro de rebotes. La interfaz MMIO conserva su formato original.
module basys3_controls_tb;
    logic clk = 1'b0;
    logic [15:0] sw = 16'h0000;
    logic btnU = 0, btnD = 0, btnL = 0, btnR = 0, btnC = 0;
    wire [15:0] led, led_s2;
    wire dp;
    int checks = 0;

    always #5 clk = ~clk;

    basys3_top dut (
        .clk(clk), .sw(sw), .btnU(btnU), .btnD(btnD),
        .btnL(btnL), .btnR(btnR), .btnC(btnC), .RsRx(1'b1),
        .led(led), .dp(dp)
    );

    subsystem2_basys3_test_top dut_s2 (
        .clk(clk), .sw(sw), .btnU(btnU), .btnD(btnD),
        .btnL(btnL), .btnR(btnR), .btnC(btnC), .led(led_s2)
    );

    // Solo se acelera el debounce en estas instancias de simulación.
    // Los módulos del diseño mantienen su configuración física de 10 ms.
    defparam dut.system_inst.INPUT_DEBOUNCE_CYCLES = 4;
    defparam dut_s2.u_subsystem2.INPUT_DEBOUNCE_CYCLES = 4;

    task automatic comprobar(input bit condition, input string message);
        checks++;
        if (!condition) $fatal(1, "%s (t=%0t)", message, $time);
    endtask

    task automatic esperar_filtro;
        repeat (16) @(posedge clk);
        #1;
    endtask

    // Orden del periférico: UP, DOWN, LEFT, RIGHT, SEL, OK, GAME_RST.
    task automatic aplicar(input logic [6:0] levels);
        @(negedge clk);
        btnU = levels[0]; btnD = levels[1];
        btnL = levels[2]; btnR = levels[3];
        sw[0] = levels[4]; sw[1] = levels[5]; btnC = levels[6];
        esperar_filtro();
        comprobar(dut.system_inst.vga_inputs_inst.u_player1_inputs.clean_levels === levels,
                  "Asignación física incorrecta en el sistema completo");
        comprobar(led_s2[6:0] === levels,
                  "Asignación física incorrecta en el top de prueba del Subsistema 2");
        comprobar(led[6:0] === levels, "Indicadores de navegación incorrectos");
    endtask

    initial begin
        esperar_filtro();
        comprobar(dut.rst === 1'b1, "Reset general inicial");
        comprobar(led[15] === 1'b0, "LED15 apagado durante reset");
        comprobar(led_s2[15:14] === 2'b0, "Reset apaga RUN y finalización de VRAM en S2");
        comprobar(dp === 1'b1, "Punto decimal apagado");
        comprobar({led[14], led[10:7]} === 5'b0, "LEDs no asignados apagados");
        @(negedge clk); sw[15] = 1;
        @(posedge clk); #1;
        comprobar(dut.rst === 1'b1, "Liberación del reset espera dos flancos");
        comprobar(dut_s2.rst === 1'b1, "S2 mantiene reset durante el primer flanco");
        @(posedge clk); #1;
        comprobar(dut.rst === 1'b0, "Reset liberado en el segundo flanco");
        comprobar(dut_s2.rst === 1'b0, "S2 libera reset en el segundo flanco");
        esperar_filtro();
        comprobar(led[15] === 1'b1, "LED15 encendido sin solicitud de reset");
        comprobar(led_s2[15] === 1'b1, "SW15 habilita RUN en el top de S2");
        repeat (310) @(posedge clk);
        #1;
        comprobar(led_s2[14] === 1'b1, "LED14 indica VRAM inicializada en el top de S2");

        force dut.game_phase_led = 2'b00;
        #1; comprobar(led[13:11] === 3'b001, "LED11 indica colocacion");
        force dut.game_phase_led = 2'b01;
        #1; comprobar(led[13:11] === 3'b010, "LED12 indica batalla");
        force dut.game_phase_led = 2'b10;
        #1; comprobar(led[13:11] === 3'b100, "LED13 indica resultado");
        force dut.game_phase_led = 2'b11;
        #1; comprobar(led[13:11] === 3'b000, "Fase reservada apaga indicadores");
        release dut.game_phase_led;

        // Una activación breve de SW0 no debe producir una rotación válida.
        @(negedge clk); sw[0] = 1;
        @(negedge clk); sw[0] = 0;
        esperar_filtro();
        comprobar(dut.system_inst.vga_inputs_inst.u_player1_inputs.clean_levels === 7'b0,
                  "El filtro debe rechazar un pulso breve en SW0");
        comprobar(led_s2[6:0] === 7'b0, "El top de prueba también filtra SW0");

        for (int bit_index = 0; bit_index < 7; bit_index++) begin
            aplicar(7'b1 << bit_index);
            aplicar(7'b0);
        end
        aplicar(7'h7f);
        aplicar(7'b0);

        // La solicitud de partida por BTNC no es un reset del hardware.
        aplicar(7'h40);
        comprobar(dut.rst === 1'b0, "GAME_RST no reinicia el hardware");
        comprobar(led[15] === 1'b1, "GAME_RST conserva el indicador de funcionamiento");
        @(negedge clk); sw[15] = 0;
        @(posedge clk); #1;
        comprobar(dut.rst === 1'b0, "Activación del reset espera dos flancos");
        comprobar(dut_s2.rst === 1'b0, "S2 sincroniza la solicitud de reset");
        @(posedge clk); #1;
        comprobar(dut.rst === 1'b1, "Reset activado en el segundo flanco");
        comprobar(dut_s2.rst === 1'b1, "S2 activa reset en el segundo flanco");
        esperar_filtro();
        comprobar(dut.system_inst.vga_inputs_inst.u_player1_inputs.clean_levels === 7'b0,
                  "Reset limpia las entradas filtradas del sistema");
        comprobar(led_s2[6:0] === 7'b0, "Reset limpia los indicadores del Subsistema 2");
        comprobar(led[15] === 1'b0, "Reset apaga LED15");
        comprobar(led_s2[15:14] === 2'b0, "Reset limpia RUN y finalización de VRAM en S2");
        $display("PASS basys3_controls_tb: %0d comprobaciones", checks);
        $finish;
    end

    initial begin
        #100_000;
        $fatal(1, "Tiempo máximo excedido en la prueba de controles físicos");
    end
endmodule
