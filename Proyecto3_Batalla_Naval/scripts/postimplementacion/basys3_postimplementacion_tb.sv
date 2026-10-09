`timescale 1ns/1ps

// Prueba de caja negra del netlist implementado. Conserva el reloj y baud
// físicos; no fuerza registros internos ni sustituye el MMCM o la ROM.
module basys3_postimplementacion_tb;
    localparam time BIT_UART = 8680ns;
    logic clk = 0;
    logic [15:0] sw = 0;
    logic rx = 1;
    wire tx;
    wire [15:0] led;
    wire [3:0] red, green, blue, an;
    wire [6:0] seg;
    wire hs, vs, dp, buzzer;
    integer comprobaciones = 0;
    logic prueba_terminada = 0;

    always #5ns clk = ~clk;
    basys3_top dut (
        .clk(clk), .sw(sw), .btnU(1'b0), .btnD(1'b0),
        .btnL(1'b0), .btnR(1'b0), .btnC(1'b0),
        .RsRx(rx), .RsTx(tx), .vgaRed(red), .vgaGreen(green),
        .vgaBlue(blue), .Hsync(hs), .Vsync(vs), .seg(seg), .dp(dp),
        .an(an), .led(led), .JA1(buzzer)
    );

    task automatic comprobar(input logic condicion, input string descripcion);
        if (condicion !== 1'b1) $fatal(1, "FALLO: %s", descripcion);
        comprobaciones++;
        $display("OK: %s", descripcion);
    endtask

    // Se muestrea en el centro de cada bit, lejos de sus transiciones.
    task automatic recibir_byte(output logic [7:0] dato);
        @(negedge tx);
        #(BIT_UART / 2);
        comprobar(tx === 1'b0, "bit de inicio UART");
        for (integer i = 0; i < 8; i++) begin
            #BIT_UART;
            dato[i] = tx;
        end
        #BIT_UART;
        comprobar(tx === 1'b1, "bit de parada UART");
    endtask

    task automatic esperar_byte(input logic [7:0] esperado);
        logic [7:0] observado;
        recibir_byte(observado);
        comprobar(observado === esperado,
            $sformatf("UART esperado=%02x observado=%02x", esperado, observado));
    endtask

    task automatic enviar_byte(input logic [7:0] dato);
        rx = 0;
        #BIT_UART;
        for (integer i = 0; i < 8; i++) begin
            rx = dato[i];
            #BIT_UART;
        end
        rx = 1;
        #BIT_UART;
    endtask

    initial begin
        // La inicialización global de las primitivas dura 100 ns. Se mantiene
        // RUN bajo después de ese intervalo y se libera entre flancos.
        #1002ns;
        sw[15] = 1;
        esperar_byte(8'ha5);
        esperar_byte(8'h86);
        esperar_byte(8'h02);
        esperar_byte(8'h00);
        esperar_byte(8'h00);
        comprobar(led[13:11] === 3'b001, "fase de colocacion");

        // PLACE_SHIP con identificador 255: debe devolver PLACE_RESULT,
        // accepted=0, reason=3, sin comenzar la batalla.
        fork
            begin
                enviar_byte(8'ha5); enviar_byte(8'h10); enviar_byte(8'h04);
                enviar_byte(8'hff); enviar_byte(8'h00);
                enviar_byte(8'h00); enviar_byte(8'h00);
            end
            begin
                esperar_byte(8'ha5); esperar_byte(8'h80); esperar_byte(8'h03);
                esperar_byte(8'hff); esperar_byte(8'h00); esperar_byte(8'h03);
            end
        join
        comprobar(led[13:11] === 3'b001, "colocacion invalida conserva fase");

        // SHOT antes de terminar la colocación: ERROR, tipo rechazado 0x11,
        // razón 2 (fase incorrecta). Comprueba la validación en ensamblador.
        fork
            begin
                enviar_byte(8'ha5); enviar_byte(8'h11); enviar_byte(8'h02);
                enviar_byte(8'h00); enviar_byte(8'h00);
            end
            begin
                esperar_byte(8'ha5); esperar_byte(8'h87); esperar_byte(8'h02);
                esperar_byte(8'h11); esperar_byte(8'h02);
            end
        join
        comprobar(led[13:11] === 3'b001, "disparo rechazado conserva fase");
        comprobar(dp === 1'b1, "punto decimal apagado");
        $display("PASS basys3_postimplementacion_tb: %0d comprobaciones", comprobaciones);
        prueba_terminada = 1;
        $finish;
    end

    initial begin
        // El firmware espera 120000 iteraciones al arrancar (más de 10 ms)
        // para permitir la estabilización real del filtro de entradas.
        #30ms;
        $fatal(1, "TIEMPO MAXIMO EXCEDIDO EN POSTIMPLEMENTACION");
    end

    // Avance periódico para distinguir una corrida larga de un bloqueo.
    initial forever begin
        #1ms;
        $display("POSTIMPLEMENTACION: tiempo simulado %0t", $time);
        $fflush();
    end
endmodule
