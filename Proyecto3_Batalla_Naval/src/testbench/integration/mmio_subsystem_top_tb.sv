`timescale 1ns/1ps
module mmio_subsystem_top_tb;
    localparam time CLK_PERIOD = 10ns;
    localparam int CLK_FREQ_HZ = 100_000_000;
    localparam int BAUD_RATE = 115_200;
    localparam int CLKS_PER_BIT = (CLK_FREQ_HZ + BAUD_RATE/2)/BAUD_RATE;
    localparam time BIT_PERIOD = CLKS_PER_BIT*CLK_PERIOD;

    localparam logic [31:0] RAM_BASE = 32'h00002000;
    localparam logic [31:0] RAM_LAST = 32'h00002FFC;
    localparam logic [31:0] UART_CONTROL = 32'h00010040;
    localparam logic [31:0] UART_TX_DATA = 32'h00010044;
    localparam logic [31:0] UART_RX_DATA = 32'h00010048;
    localparam logic [31:0] INPUT_ADDRESS = 32'h00010120;
    localparam logic [31:0] SEVENSEG_ADDRESS = 32'h00010130;
    localparam logic [31:0] LED_ADDRESS = 32'h00010138;
    localparam logic [31:0] BUZZER_ADDRESS = 32'h00010140;
    localparam logic [31:0] VGA_BASE = 32'h00011000;
    localparam logic [31:0] VGA_LAST = 32'h000117FC;

    logic clk_i=0;
    logic rst_i=1;
    logic [31:0] cpu_addr_i=0;
    logic [31:0] cpu_wdata_i=0;
    logic cpu_we_i=0;
    logic [31:0] cpu_rdata_o;

    logic uart_rx_i=1;
    logic uart_tx_o;
    logic [6:0] seg_o;
    logic [3:0] an_o;
    logic [1:0] led_o;
    logic buzzer_o;

    logic [31:0] input_rdata_i=0;
    logic [31:0] vga_rdata_i=0;
    logic [1:0] input_addr_o;
    logic [8:0] vga_addr_o;
    logic input_write_enable_o;
    logic vga_write_enable_o;

    logic [31:0] valor_modelo_entradas=32'h00000055;
    logic [31:0] modelo_vga_inicial=32'hA5A50000;
    logic [31:0] modelo_vga_final=32'h5A5A01FF;

    integer verificaciones=0;
    integer errores=0;

    always #(CLK_PERIOD/2) clk_i=~clk_i;

    mmio_subsystem_top #(
        .CLK_FREQ_HZ       (CLK_FREQ_HZ),
        .BAUD_RATE         (BAUD_RATE),
        .FRAME_REFRESH_HZ  (25_000_000),
        .HIT_HALF_PERIOD   (2),
        .MISS_HALF_PERIOD  (3),
        .SUNK_HALF_PERIOD  (4),
        .INVALID_HALF_PERIOD(5),
        .VICTORY_HALF_PERIOD(6)
    ) dut (
        .clk_i                   (clk_i),
        .rst_i                   (rst_i),
        .cpu_addr_i              (cpu_addr_i),
        .cpu_wdata_i             (cpu_wdata_i),
        .cpu_we_i                (cpu_we_i),
        .cpu_rdata_o             (cpu_rdata_o),
        .uart_rx_i               (uart_rx_i),
        .uart_tx_o               (uart_tx_o),
        .seg_o                   (seg_o),
        .an_o                    (an_o),
        .led_o                   (led_o),
        .buzzer_o                (buzzer_o),
        .input_rdata_i           (input_rdata_i),
        .vga_rdata_i             (vga_rdata_i),
        .input_addr_o            (input_addr_o),
        .vga_addr_o              (vga_addr_o),
        .input_write_enable_o    (input_write_enable_o),
        .vga_write_enable_o      (vga_write_enable_o)
    );

    // Modelos sincronos temporales para las interfaces de entradas y VGA.
    always_ff @(posedge clk_i) begin
        if(rst_i) begin
            input_rdata_i<=32'b0;
            vga_rdata_i<=32'b0;
        end else begin
            input_rdata_i<=(input_addr_o==2'b00) ? valor_modelo_entradas : 32'b0;
            case(vga_addr_o)
                9'd0:vga_rdata_i<=modelo_vga_inicial;
                9'd511:vga_rdata_i<=modelo_vga_final;
                default:vga_rdata_i<=32'b0;
            endcase
        end
    end

    task automatic verificar(input logic condicion,input string nombre_prueba);
        if(condicion!==1'b1)begin
            errores++;
            $error("%s",nombre_prueba);
        end else verificaciones++;
    endtask

    task automatic escritura_cpu(
        input logic [31:0] direccion,input logic [31:0] valor
    );
        @(negedge clk_i);
        cpu_addr_i=direccion;
        cpu_wdata_i=valor;
        cpu_we_i=1;
        @(posedge clk_i);#1;
        @(negedge clk_i);
        cpu_we_i=0;
    endtask

    task automatic lectura_cpu_verificar(
        input logic [31:0] direccion,input logic [31:0] esperado,
        input string nombre_prueba
    );
        logic [31:0] anterior;
        @(negedge clk_i);
        anterior=cpu_rdata_o;
        cpu_addr_i=direccion;
        cpu_we_i=0;
        #1;
        verificar(cpu_rdata_o===anterior,
                  {nombre_prueba," cambia solo despues del flanco"});
        @(posedge clk_i);#1;
        verificar(cpu_rdata_o===esperado,nombre_prueba);
    endtask

    task automatic verificar_habilitaciones_escritura_apagadas(
        input string nombre_prueba
    );
        verificar({vga_write_enable_o,input_write_enable_o,
                   dut.buzzer_write_enable,dut.led_write_enable,
                   dut.sevenseg_write_enable,dut.uart_write_enable,
                   dut.ram_write_enable}===7'b0000000,nombre_prueba);
    endtask

    task automatic capturar_byte_tx(input logic [7:0] esperado);
        integer indice_bit;
        wait(uart_tx_o===1'b0);
        #(BIT_PERIOD/2);
        verificar(uart_tx_o===1'b0,"UART TX bit de inicio");
        for(indice_bit=0;indice_bit<8;indice_bit++)begin
            #BIT_PERIOD;
            verificar(uart_tx_o===esperado[indice_bit],
                      $sformatf("UART TX bit de datos %0d",indice_bit));
        end
        #BIT_PERIOD;
        verificar(uart_tx_o===1'b1,"UART TX bit de parada");
    endtask

    task automatic enviar_byte_rx(input logic [7:0] valor);
        integer indice_bit;
        uart_rx_i=0;#BIT_PERIOD;
        for(indice_bit=0;indice_bit<8;indice_bit++)begin
            uart_rx_i=valor[indice_bit];#BIT_PERIOD;
        end
        uart_rx_i=1;#BIT_PERIOD;
    endtask

    task automatic verificar_conmutacion_buzzer(
        input logic [2:0] comando,input string nombre_prueba
    );
        logic anterior;
        logic conmuto;
        integer ciclo;
        escritura_cpu(BUZZER_ADDRESS,{29'b0,comando});
        lectura_cpu_verificar(BUZZER_ADDRESS,{29'b0,comando},
                              {nombre_prueba," lectura MMIO"});
        anterior=buzzer_o;
        conmuto=0;
        for(ciclo=0;ciclo<20;ciclo++)begin
            @(posedge clk_i);#1;
            if(buzzer_o!==anterior)conmuto=1;
            anterior=buzzer_o;
        end
        verificar(conmuto,nombre_prueba);
    endtask

    initial begin
        integer codigo_estado;

        repeat(3)@(posedge clk_i);#1;
        verificar(led_o===2'b00,"reset inicial LED");
        verificar(buzzer_o===1'b0,"reset inicial buzzer");
        verificar(uart_tx_o===1'b1,"reset inicial UART TX");
        verificar(!$isunknown({seg_o,an_o}),"reset inicial display sin X");
        verificar_habilitaciones_escritura_apagadas(
            "reset inicial inhibe escrituras");
        @(negedge clk_i);rst_i=0;

        $display("[PRUEBA] RAM");
        escritura_cpu(RAM_BASE,32'h11223344);
        escritura_cpu(RAM_BASE+32'h00000100,32'h55667788);
        escritura_cpu(RAM_LAST,32'hAABBCCDD);
        lectura_cpu_verificar(RAM_BASE,32'h11223344,"RAM inicio del rango");
        lectura_cpu_verificar(RAM_BASE+32'h00000100,32'h55667788,
                              "RAM direccion intermedia");
        lectura_cpu_verificar(RAM_LAST,32'hAABBCCDD,"RAM final del rango");
        escritura_cpu(RAM_BASE+32'h00000100,32'hCAFEBABE);
        lectura_cpu_verificar(RAM_BASE,32'h11223344,
                              "RAM independencia posicion inicial");
        lectura_cpu_verificar(RAM_BASE+32'h00000100,32'hCAFEBABE,
                              "RAM reemplazo posicion intermedia");
        lectura_cpu_verificar(RAM_LAST,32'hAABBCCDD,
                              "RAM independencia posicion final");

        $display("[PRUEBA] BUS MMIO");
        lectura_cpu_verificar(INPUT_ADDRESS,valor_modelo_entradas,
                              "modelo de entradas");
        @(negedge clk_i);cpu_addr_i=INPUT_ADDRESS;cpu_wdata_i=32'h12345678;
        cpu_we_i=1;#1;
        verificar(input_addr_o===2'b00,"direccion local de entradas");
        verificar(input_write_enable_o===1'b1,"write-enable de entradas");
        @(posedge clk_i);#1;@(negedge clk_i);cpu_we_i=0;

        @(negedge clk_i);cpu_addr_i=VGA_BASE;cpu_we_i=0;#1;
        verificar(vga_addr_o===9'd0,"VGA direccion local 0");
        @(posedge clk_i);#1;
        verificar(cpu_rdata_o===modelo_vga_inicial,"modelo VGA indice 0");

        @(negedge clk_i);cpu_addr_i=VGA_LAST;cpu_we_i=0;#1;
        verificar(vga_addr_o===9'd511,"VGA direccion local 511");
        @(posedge clk_i);#1;
        verificar(cpu_rdata_o===modelo_vga_final,"modelo VGA indice 511");

        @(negedge clk_i);cpu_addr_i=VGA_LAST;cpu_wdata_i=32'h89ABCDEF;
        cpu_we_i=1;#1;
        verificar(vga_write_enable_o===1'b1,"write-enable de VGA");
        verificar(vga_addr_o===9'd511,"VGA escritura en direccion local 511");
        @(posedge clk_i);#1;@(negedge clk_i);cpu_we_i=0;

        @(negedge clk_i);
        cpu_addr_i=32'hDEADBEEF;
        cpu_wdata_i=32'hFFFFFFFF;
        cpu_we_i=1;
        #1;
        verificar_habilitaciones_escritura_apagadas(
            "direccion no mapeada no habilita escrituras");
        @(posedge clk_i);#1;
        @(negedge clk_i);cpu_we_i=0;
        lectura_cpu_verificar(32'hDEADBEEF,32'h00000000,
                              "lectura de direccion no mapeada");
        lectura_cpu_verificar(RAM_BASE,32'h11223344,
                              "escritura invalida no modifica RAM");

        $display("[PRUEBA] DISPLAY");
        escritura_cpu(SEVENSEG_ADDRESS,32'h0000220C);
        lectura_cpu_verificar(SEVENSEG_ADDRESS,32'h0000220C,
                              "display J1=12 J2=34");
        repeat(8)begin
            @(posedge clk_i);#1;
            verificar(!$isunknown({seg_o,an_o}),"display sin valores X");
        end

        $display("[PRUEBA] LED");
        for(codigo_estado=0;codigo_estado<4;codigo_estado++)begin
            escritura_cpu(LED_ADDRESS,codigo_estado);
            verificar(led_o===codigo_estado[1:0],
                      $sformatf("LED estado %0d",codigo_estado));
            lectura_cpu_verificar(LED_ADDRESS,codigo_estado,
                                  $sformatf("LED lectura estado %0d",codigo_estado));
        end

        $display("[PRUEBA] BUZZER");
        verificar_conmutacion_buzzer(3'd1,"buzzer comando 1");
        verificar_conmutacion_buzzer(3'd2,"buzzer comando 2");
        verificar_conmutacion_buzzer(3'd3,"buzzer comando 3");
        verificar_conmutacion_buzzer(3'd4,"buzzer comando 4");
        verificar_conmutacion_buzzer(3'd5,"buzzer comando 5");
        escritura_cpu(BUZZER_ADDRESS,32'h00000000);
        verificar(buzzer_o===1'b0,"buzzer comando cero apaga salida");
        lectura_cpu_verificar(BUZZER_ADDRESS,32'h00000000,
                              "buzzer lectura comando cero");

        $display("[PRUEBA] UART TX");
        lectura_cpu_verificar(UART_CONTROL,32'h00000001,
                              "UART STATUS inicial");
        fork
            capturar_byte_tx(8'h55);
            begin
                escritura_cpu(UART_TX_DATA,32'h00000055);
                lectura_cpu_verificar(UART_TX_DATA,32'h00000055,
                                      "UART TX_DATA");
                lectura_cpu_verificar(UART_CONTROL,32'h00000000,
                                      "UART tx_ready durante transmision");
                #(BIT_PERIOD*11);
                lectura_cpu_verificar(UART_CONTROL,32'h00000001,
                                      "UART tx_ready al finalizar");
            end
        join

        $display("[PRUEBA] UART RX");
        enviar_byte_rx(8'hA5);
        lectura_cpu_verificar(UART_CONTROL,32'h00000003,"UART rx_valid");
        lectura_cpu_verificar(UART_RX_DATA,32'h000000A5,"UART RX_DATA");
        lectura_cpu_verificar(UART_CONTROL,32'h00000003,
                              "lectura RX_DATA no limpia rx_valid");
        escritura_cpu(UART_CONTROL,32'h00000002);
        lectura_cpu_verificar(UART_CONTROL,32'h00000001,
                              "CONTROL limpia rx_valid");

        $display("[PRUEBA] RESET");
        @(negedge clk_i);
        cpu_we_i=0;
        cpu_addr_i=32'b0;
        uart_rx_i=1;
        rst_i=1;
        @(posedge clk_i);#1;
        verificar(led_o===2'b00,"reset final LED");
        verificar(buzzer_o===1'b0,"reset final buzzer");
        verificar(uart_tx_o===1'b1,"reset final UART TX en reposo");
        verificar(!$isunknown({seg_o,an_o}),"reset final display sin X");
        verificar_habilitaciones_escritura_apagadas(
            "reset final inhibe escrituras");
        @(negedge clk_i);rst_i=0;
        lectura_cpu_verificar(SEVENSEG_ADDRESS,32'h00000000,
                              "reset final registro display");
        lectura_cpu_verificar(LED_ADDRESS,32'h00000000,
                              "reset final registro LED");
        lectura_cpu_verificar(BUZZER_ADDRESS,32'h00000000,
                              "reset final registro buzzer");
        lectura_cpu_verificar(UART_CONTROL,32'h00000001,
                              "reset final UART tx_ready=1 rx_valid=0");
        lectura_cpu_verificar(RAM_BASE,32'h11223344,
                              "reset no borra RAM");

        if(errores==0)begin
            $display("mmio_subsystem_top_tb:");
            $display("TODAS LAS PRUEBAS PASARON (%0d verificaciones)",
                     verificaciones);
            $display("========================================");
            $display("TODAS LAS PRUEBAS PASARON");
            $display("Total de verificaciones: %0d",verificaciones);
            $display("========================================");
        end else begin
            $fatal(1,"mmio_subsystem_top_tb: %0d errores en %0d verificaciones",
                   errores,verificaciones);
        end
        $finish;
    end

    initial begin
        #5ms;
        $fatal(1,"TIEMPO DE ESPERA AGOTADO mmio_subsystem_top_tb");
    end
endmodule
