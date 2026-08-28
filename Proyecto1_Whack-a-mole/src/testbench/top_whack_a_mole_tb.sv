`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 08/18/2026 09:28:45 PM
// Design Name: 
// Module Name: top_whack_a_mole_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// Testbench de integracion del sistema completo. A diferencia de los
// testbenches anteriores (que probaban un modulo aislado), este
// ejercita los 11 modulos ya conectados entre si: genera una trama
// UART real para simular el circuito discreto, presiona botones a
// traves del debounce real, y corre una partida completa (aciertos,
// fallos, GAME OVER y reinicio automatico).
//
// Todos los parametros de tiempo se sobreescriben con valores
// pequenos unicamente para que la simulacion corra en un tiempo
// razonable; la logica interna instanciada es exactamente la misma
// que se sintetizara para la Basys 3.
//
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module top_whack_a_mole_tb;

    localparam time CLK_PERIOD = 10ns;

    // Frecuencia de tick acelerada (1 MHz = tick cada 1 us) para que
    // ventanas de turno de "1500 ms" tarden 1500 us de simulacion en
    // vez de 1.5 segundos reales.
    localparam int TICK_HZ_TEST = 1_000_000;

    // Baudios acelerados, igual que en uart_rx_tb.sv.
    localparam int BAUD_RATE_TEST = 1_000_000;
    localparam time BIT_PERIOD    = 1us;

    localparam int DEBOUNCE_TICKS_TEST  = 3;
    localparam int REQUEST_HOLD_MS_TEST = 2;
    localparam int GAME_OVER_MS_TEST    = 3;

    logic       clk;
    logic       reset_btn;
    logic [7:0] hit_buttons;
    logic       serial_data;

    logic       mole_request;
    logic [6:0] seg;
    logic [3:0] an;
    logic       game_status_led;

    top_whack_a_mole #(
        .CLK_FREQ        (100_000_000),
        .BAUD_RATE       (BAUD_RATE_TEST),
        .TICK_HZ         (TICK_HZ_TEST),
        .DEBOUNCE_TICKS  (DEBOUNCE_TICKS_TEST),
        .REQUEST_HOLD_MS (REQUEST_HOLD_MS_TEST),
        .GAME_OVER_MS    (GAME_OVER_MS_TEST)
    ) dut (
        .clk             (clk),
        .reset_btn       (reset_btn),
        .hit_buttons     (hit_buttons),
        .serial_data     (serial_data),
        .mole_request    (mole_request),
        .seg             (seg),
        .an              (an),
        .game_status_led (game_status_led)
    );

    // Acceso directo a senales internas del DUT para verificar el
    // resultado sin depender unicamente de los pines externos.
    wire [6:0] hits_probe   = dut.hits;
    wire [6:0] misses_probe = dut.misses;
    wire [1:0] consecutive_misses_probe = dut.consecutive_misses;

    initial begin
        clk = 1'b0;
        forever #(CLK_PERIOD / 2) clk = ~clk;
    end

    task automatic step_clk();
        @(posedge clk);
        #1;
    endtask

    // Envia un byte por la linea serial simulando al circuito
    // discreto (formato 8N1, igual que en uart_rx_tb.sv).
    task automatic send_uart_byte(input logic [7:0] value);
        integer i;
        begin
            serial_data = 1'b0;             // start bit
            #(BIT_PERIOD);
            for (i = 0; i < 8; i = i + 1) begin
                serial_data = value[i];      // 8 bits de datos, LSB primero
                #(BIT_PERIOD);
            end
            serial_data = 1'b1;             // stop bit
            #(BIT_PERIOD);
        end
    endtask

    // Simula al jugador presionando un boton: lo sostiene el tiempo
    // suficiente para que buttons_frontend lo acepte como estable y
    // despues lo suelta.
    task automatic press_button(input int idx);
        integer i;
        begin
            hit_buttons[idx] = 1'b1;
            for (i = 0; i < DEBOUNCE_TICKS_TEST + 1; i = i + 1)
                #(1_000_000_000 / TICK_HZ_TEST * 1ns);
            hit_buttons[idx] = 1'b0;
            for (i = 0; i < DEBOUNCE_TICKS_TEST + 1; i = i + 1)
                #(1_000_000_000 / TICK_HZ_TEST * 1ns);
        end
    endtask

    // Espera hasta que mole_request se active y luego hasta que se
    // desactive.
    //
    // Nota: no usamos fork/join_any/disable fork aqui porque Icarus
    // Verilog tiene un problema conocido con ese patron cuando la
    // misma tarea se invoca varias veces en la simulacion (provoca un
    // aborto interno del simulador). En su lugar confiamos en el
    // watchdog global de la simulacion.
    task automatic wait_for_request_cycle();
        // mole_request puede ya estar en alto en el momento en que
        // llamamos esta tarea (por ejemplo, justo despues del reset,
        // ya que sube casi de inmediato). Si esperaramos ciegamente
        // un @(posedge mole_request), nos quedariamos colgados
        // esperando una subida que ya paso. Por eso revisamos el
        // nivel actual antes de decidir si hay que esperar la subida.
        if (!mole_request)
            @(posedge mole_request);
        @(negedge mole_request);
    endtask

    // Watchdog global: si la secuencia principal de pruebas no ha
    // terminado en este tiempo, algo se colgo.
    initial begin
        #5ms;
        $error("FALLO: watchdog global - la simulacion no termino a tiempo, algo se quedo esperando un evento que nunca ocurrio");
        $finish;
    end

    initial begin

        hit_buttons = 8'd0;
        serial_data = 1'b1;

        reset_btn = 1'b1;
        step_clk();
        step_clk();
        reset_btn = 1'b0;
        step_clk();

        //----------------------------------------------------------------------
        // Test 1: tras el reset, mole_request debe completar un ciclo
        // completo de solicitud (sube y luego baja)
        //----------------------------------------------------------------------
        wait_for_request_cycle();
        $display("PASS: mole_request completo su primer ciclo tras el reset");

        //----------------------------------------------------------------------
        // Test 2: enviamos la posicion 3 por UART y presionamos el
        // boton correcto (hit_buttons[3]) - debe registrarse un HIT
        //
        // Nota de diseno del testbench: a partir de aqui NO usamos
        // wait_for_request_cycle() despues de cada boton, porque
        // REQUEST_HOLD_MS_TEST (2 ticks) es mas corto que el tiempo
        // que tarda press_button() en sostener y soltar el boton (mas
        // de 2*(DEBOUNCE_TICKS_TEST+1) ticks). Esto significa que,
        // para cuando press_button() termina, la FSM ya completo todo
        // el ciclo EVALUATE->CHECK->REQUEST->WAIT_UART y mole_request
        // ya subio y bajo *mientras* todavia estabamos presionando el
        // boton. Si esperaramos un @(posedge mole_request) despues,
        // nos quedariamos colgados esperando una subida que ya paso
        // (este fue exactamente el error que encontramos la primera
        // vez que corrimos esta simulacion). En su lugar, simplemente
        // esperamos un margen fijo y verificamos el resultado
        // directamente en los contadores.
        //----------------------------------------------------------------------
        send_uart_byte(8'd3);
        #1us;
        press_button(3);
        #3us;

        if (hits_probe == 7'd1 && misses_probe == 7'd0)
            $display("PASS: HIT valido incrementa hits a 1 sin afectar misses");
        else
            $error("FALLO: se esperaba hits=1 misses=0, se obtuvo hits=%0d misses=%0d",
                   hits_probe, misses_probe);

        //----------------------------------------------------------------------
        // Test 3: enviamos la posicion 5 pero presionamos un boton
        // incorrecto (hit_buttons[2]) - debe registrarse un MISS
        //----------------------------------------------------------------------
        send_uart_byte(8'd5);
        #1us;
        press_button(2);
        #3us;

        if (misses_probe == 7'd1 && consecutive_misses_probe == 2'd1)
            $display("PASS: WRONG_HIT incrementa misses y consecutive_misses a 1");
        else
            $error("FALLO: se esperaba misses=1 consecutive_misses=1, se obtuvo misses=%0d consecutive_misses=%0d",
                   misses_probe, consecutive_misses_probe);

        //----------------------------------------------------------------------
        // Test 4 y 5 combinados: dos WRONG_HIT mas deben completar 3
        // fallos consecutivos, activar GAME OVER, y el sistema debe
        // reiniciarse automaticamente por completo.
        //
        // Nota de diseno del testbench: aqui NO intentamos cazar en
        // vivo el flanco de subida y bajada de game_status_led. El
        // ciclo completo de GAME OVER (GAME_OVER_MS_TEST = 3 us) mas
        // el reinicio caben dentro de la propia duracion de
        // press_button() (8 us), asi que para cuando esa tarea
        // regresa, game_status_led ya pudo haber subido y bajado por
        // completo -- el mismo tipo de carrera que ya vimos con
        // mole_request. En vez de perseguir flancos que quiza ya
        // ocurrieron, esperamos un margen fijo generoso y verificamos
        // el estado final: si hits y misses volvieron a 0, eso solo
        // pudo pasar via el reinicio automatico (new_game_pulse), lo
        // cual confirma indirectamente pero con total certeza que
        // todo el ciclo GAME OVER -> reinicio ocurrio correctamente.
        //----------------------------------------------------------------------
        send_uart_byte(8'd1);
        #1us;
        press_button(7);              // boton incorrecto de nuevo (2do fallo)
        #3us;

        send_uart_byte(8'd6);
        #1us;
        press_button(0);              // boton incorrecto de nuevo (3er fallo -> GAME OVER)

        #10us;

        if (!game_status_led && hits_probe == 7'd0 && misses_probe == 7'd0)
            $display("PASS: GAME OVER se activo y la partida se reinicio automaticamente (hits=0, misses=0, LED apagado)");
        else
            $error("FALLO: se esperaba game_status_led=0 hits=0 misses=0 tras el ciclo de GAME OVER, se obtuvo game_status_led=%0b hits=%0d misses=%0d",
                   game_status_led, hits_probe, misses_probe);

        //----------------------------------------------------------------------
        // Test 6: tras el reinicio automatico, el sistema debe seguir
        // funcionando con normalidad. En vez de intentar cazar el
        // pulso de mole_request (que, por la misma razon que arriba,
        // ya pudo haberse consumido por completo durante los 10us de
        // margen de la prueba anterior), la confirmacion mas directa
        // y solida es simplemente enviar un nuevo byte UART y
        // verificar que el sistema lo acepta con normalidad -- si
        // estuviera atascado en cualquier otro estado, mole_position
        // nunca cambiaria al valor nuevo.
        //----------------------------------------------------------------------
        send_uart_byte(8'd4);
        #1us;

        if (dut.mole_position == 3'd4)
            $display("PASS: tras el reinicio automatico, el sistema acepta un nuevo topo con normalidad");
        else
            $error("FALLO: el sistema no acepto el nuevo topo tras el reinicio (mole_position=%0d, se esperaba 4)",
                   dut.mole_position);

        $display("---------------------------------------------------");
        $display("TODAS LAS PRUEBAS top_whack_a_mole FINALIZARON");
        $display("---------------------------------------------------");

        #10us;
        $finish;
    end

endmodule
