`timescale 1ns/1ps
module mmio_subsystem_integration_tb;
    localparam time CLK_PERIOD = 10ns;
    localparam int CLK_FREQ_HZ = 100_000_000;
    localparam int BAUD_RATE = 115_200;
    localparam int CLKS_PER_BIT = (CLK_FREQ_HZ + BAUD_RATE/2)/BAUD_RATE;
    localparam time BIT_PERIOD = CLKS_PER_BIT*CLK_PERIOD;

    localparam logic [31:0] RAM_BASE = 32'h00002000;
    localparam logic [31:0] UART_CONTROL = 32'h00010040;
    localparam logic [31:0] UART_TX_DATA = 32'h00010044;
    localparam logic [31:0] UART_RX_DATA = 32'h00010048;
    localparam logic [31:0] INPUT_ADDRESS = 32'h00010120;
    localparam logic [31:0] SEVENSEG_ADDRESS = 32'h00010130;
    localparam logic [31:0] LED_ADDRESS = 32'h00010138;
    localparam logic [31:0] BUZZER_ADDRESS = 32'h00010140;
    localparam logic [31:0] VGA_BASE = 32'h00011000;
    localparam logic [31:0] VGA_LAST = 32'h000117FC;

    logic clk=0,rst=1;
    logic [31:0] cpu_addr=0,cpu_wdata=0,cpu_rdata;
    logic cpu_we=0;

    logic [31:0] peripheral_wdata;
    logic [9:0] ram_addr;
    logic [1:0] uart_addr,input_addr,sevenseg_addr,led_addr,buzzer_addr;
    logic [8:0] vga_addr;
    logic ram_we,uart_we,input_we,sevenseg_we,led_we,buzzer_we,vga_we;
    logic [31:0] ram_rdata,uart_rdata,input_rdata;
    logic [31:0] sevenseg_rdata,led_rdata,buzzer_rdata,vga_rdata;

    logic uart_rx=1,uart_tx;
    logic [6:0] seg;
    logic [3:0] an;
    logic [1:0] led;
    logic buzzer;

    logic [31:0] valor_modelo_entradas=32'h00000055;
    logic [31:0] modelo_vga_inicial=32'hA5A50000;
    logic [31:0] modelo_vga_final=32'h5A5A01FF;

    integer verificaciones=0,errores=0;

    always #(CLK_PERIOD/2) clk=~clk;

    data_bus bus_dut(
        .clk_i(clk),.rst_i(rst),.cpu_addr_i(cpu_addr),
        .cpu_wdata_i(cpu_wdata),.cpu_we_i(cpu_we),.cpu_rdata_o(cpu_rdata),
        .ram_rdata_i(ram_rdata),.uart_rdata_i(uart_rdata),
        .input_rdata_i(input_rdata),.sevenseg_rdata_i(sevenseg_rdata),
        .led_rdata_i(led_rdata),.buzzer_rdata_i(buzzer_rdata),
        .vga_rdata_i(vga_rdata),.peripheral_wdata_o(peripheral_wdata),
        .ram_addr_o(ram_addr),.uart_addr_o(uart_addr),
        .input_addr_o(input_addr),.sevenseg_addr_o(sevenseg_addr),
        .led_addr_o(led_addr),.buzzer_addr_o(buzzer_addr),
        .vga_addr_o(vga_addr),.ram_write_enable_o(ram_we),
        .uart_write_enable_o(uart_we),.input_write_enable_o(input_we),
        .sevenseg_write_enable_o(sevenseg_we),.led_write_enable_o(led_we),
        .buzzer_write_enable_o(buzzer_we),.vga_write_enable_o(vga_we)
    );

    data_ram ram_dut(
        .clk_i(clk),.write_enable_i(ram_we),.addr_i(ram_addr),
        .wdata_i(peripheral_wdata),.rdata_o(ram_rdata)
    );

    uart_peripheral uart_dut(
        .clk_i(clk),.rst_i(rst),.write_enable_i(uart_we),
        .addr_i(uart_addr),.wdata_i(peripheral_wdata),
        .rdata_o(uart_rdata),.uart_rx_i(uart_rx),.uart_tx_o(uart_tx)
    );

    sevenseg_peripheral #(
        .CLK_FREQ_HZ(40),.FRAME_REFRESH_HZ(10)
    ) sevenseg_dut(
        .clk_i(clk),.rst_i(rst),.write_enable_i(sevenseg_we),
        .addr_i(sevenseg_addr),.wdata_i(peripheral_wdata),
        .rdata_o(sevenseg_rdata),.seg_o(seg),.an_o(an)
    );

    led_peripheral led_dut(
        .clk_i(clk),.rst_i(rst),.write_enable_i(led_we),
        .addr_i(led_addr),.wdata_i(peripheral_wdata),
        .rdata_o(led_rdata),.led_o(led)
    );

    buzzer_peripheral #(
        .HIT_HALF_PERIOD(2),.MISS_HALF_PERIOD(3),.SUNK_HALF_PERIOD(4),
        .INVALID_HALF_PERIOD(5),.VICTORY_HALF_PERIOD(6)
    ) buzzer_dut(
        .clk_i(clk),.rst_i(rst),.write_enable_i(buzzer_we),
        .addr_i(buzzer_addr),.wdata_i(peripheral_wdata),
        .rdata_o(buzzer_rdata),.buzzer_o(buzzer)
    );

    // Modelos sincronos de las interfaces cuyos modulos RTL aun no existen.
    always_ff @(posedge clk) begin
        if(rst) begin
            input_rdata<=32'b0;
            vga_rdata<=32'b0;
        end else begin
            input_rdata<=(input_addr==2'b00) ? valor_modelo_entradas : 32'b0;
            case(vga_addr)
                9'd0:vga_rdata<=modelo_vga_inicial;
                9'd511:vga_rdata<=modelo_vga_final;
                default:vga_rdata<=32'b0;
            endcase
        end
    end

    task automatic verificar(input logic condicion,input string nombre_prueba);
        if(condicion!==1'b1)begin
            errores++;
            $error("%s",nombre_prueba);
        end else verificaciones++;
    endtask

    task automatic escritura_cpu(input logic [31:0] direccion,input logic [31:0] valor);
        @(negedge clk);
        cpu_addr=direccion;
        cpu_wdata=valor;
        cpu_we=1;
        @(posedge clk);#1;
        @(negedge clk);
        cpu_we=0;
    endtask

    task automatic lectura_cpu_verificar(
        input logic [31:0] direccion,input logic [31:0] esperado,
        input string nombre_prueba
    );
        logic [31:0] anterior;
        @(negedge clk);
        anterior=cpu_rdata;
        cpu_addr=direccion;
        cpu_we=0;
        #1;
        verificar(cpu_rdata===anterior,{nombre_prueba," cambia solo en posedge"});
        @(posedge clk);#1;
        verificar(cpu_rdata===esperado,nombre_prueba);
    endtask

    task automatic verificar_habilitaciones_escritura_apagadas(input string nombre_prueba);
        verificar({vga_we,buzzer_we,led_we,sevenseg_we,input_we,uart_we,ram_we}
                  ===7'b0000000,nombre_prueba);
    endtask

    task automatic capturar_byte_tx(input logic [7:0] esperado);
        integer indice_bit;
        wait(uart_tx===1'b0);
        #(BIT_PERIOD/2);
        verificar(uart_tx===1'b0,"UART TX bit de inicio");
        for(indice_bit=0;indice_bit<8;indice_bit++)begin
            #BIT_PERIOD;
            verificar(uart_tx===esperado[indice_bit],
                      $sformatf("UART TX bit de datos %0d",indice_bit));
        end
        #BIT_PERIOD;
        verificar(uart_tx===1'b1,"UART TX bit de parada");
    endtask

    task automatic enviar_byte_rx(input logic [7:0] valor);
        integer indice_bit;
        uart_rx=0;#BIT_PERIOD;
        for(indice_bit=0;indice_bit<8;indice_bit++)begin
            uart_rx=valor[indice_bit];#BIT_PERIOD;
        end
        uart_rx=1;#BIT_PERIOD;
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
        anterior=buzzer;
        conmuto=0;
        for(ciclo=0;ciclo<20;ciclo++)begin
            @(posedge clk);#1;
            if(buzzer!==anterior)conmuto=1;
            anterior=buzzer;
        end
        verificar(conmuto,nombre_prueba);
    endtask

    initial begin
        integer codigo_estado;

        repeat(3)@(posedge clk);#1;
        verificar(led===2'b00,"reset LED");
        verificar(buzzer===1'b0,"reset buzzer");
        verificar(uart_tx===1'b1,"reset UART TX en reposo");
        verificar(!$isunknown({seg,an}),"reset display sin X");
        verificar_habilitaciones_escritura_apagadas("reset inhibe escrituras");

        @(negedge clk);rst=0;
        lectura_cpu_verificar(UART_CONTROL,32'h00000001,"UART STATUS tras reset");
        lectura_cpu_verificar(SEVENSEG_ADDRESS,32'h00000000,"reset seven-segment");
        lectura_cpu_verificar(LED_ADDRESS,32'h00000000,"reset registro LED");
        lectura_cpu_verificar(BUZZER_ADDRESS,32'h00000000,"reset registro buzzer");

        // RAM: extremos, direccion intermedia e independencia.
        escritura_cpu(RAM_BASE,32'h11223344);
        escritura_cpu(RAM_BASE+32'h100,32'h55667788);
        escritura_cpu(32'h00002FFC,32'hAABBCCDD);
        lectura_cpu_verificar(RAM_BASE,32'h11223344,"RAM direccion inicial");
        lectura_cpu_verificar(RAM_BASE+32'h100,32'h55667788,"RAM direccion intermedia");
        lectura_cpu_verificar(32'h00002FFC,32'hAABBCCDD,"RAM direccion final");
        escritura_cpu(RAM_BASE+32'h100,32'hCAFEBABE);
        lectura_cpu_verificar(RAM_BASE,32'h11223344,"RAM independencia posicion inicial");
        lectura_cpu_verificar(RAM_BASE+32'h100,32'hCAFEBABE,"RAM reemplazo intermedio");
        lectura_cpu_verificar(32'h00002FFC,32'hAABBCCDD,"RAM independencia posicion final");

        // Display con enteros binarios: J1=12 y J2=34.
        escritura_cpu(SEVENSEG_ADDRESS,32'h0000220C);
        lectura_cpu_verificar(SEVENSEG_ADDRESS,32'h0000220C,"seven-segment lectura MMIO");
        repeat(8)begin
            @(posedge clk);#1;
            verificar(!$isunknown({seg,an}),"seven-segment salidas sin X");
        end

        // LED: todas las codificaciones del registro.
        for(codigo_estado=0;codigo_estado<4;codigo_estado++)begin
            escritura_cpu(LED_ADDRESS,codigo_estado);
            verificar(led===codigo_estado[1:0],$sformatf("LED estado %0d",codigo_estado));
            lectura_cpu_verificar(LED_ADDRESS,codigo_estado,
                                  $sformatf("LED lectura estado %0d",codigo_estado));
        end

        // Buzzer: cada comando util produce tono y el comando cero lo apaga.
        verificar_conmutacion_buzzer(3'd1,"buzzer impacto");
        verificar_conmutacion_buzzer(3'd2,"buzzer fallo");
        verificar_conmutacion_buzzer(3'd3,"buzzer hundido");
        verificar_conmutacion_buzzer(3'd4,"buzzer invalido");
        verificar_conmutacion_buzzer(3'd5,"buzzer victoria");
        escritura_cpu(BUZZER_ADDRESS,32'h00000000);
        verificar(buzzer===1'b0,"buzzer comando cero apaga salida");
        lectura_cpu_verificar(BUZZER_ADDRESS,32'h00000000,"buzzer lectura apagado");

        // UART TX: estado, registro de dato, ocupado y trama 8N1.
        lectura_cpu_verificar(UART_CONTROL,32'h00000001,"UART TX ready inicial");
        fork
            capturar_byte_tx(8'h55);
            begin
                escritura_cpu(UART_TX_DATA,32'h00000055);
                lectura_cpu_verificar(UART_TX_DATA,32'h00000055,"UART TX_DATA");
                lectura_cpu_verificar(UART_CONTROL,32'h00000000,"UART TX ocupado");
                #(BIT_PERIOD*11);
                lectura_cpu_verificar(UART_CONTROL,32'h00000001,"UART TX ready final");
            end
        join

        // UART RX: dato, flag persistente y reconocimiento W1C.
        enviar_byte_rx(8'hA5);
        lectura_cpu_verificar(UART_CONTROL,32'h00000003,"UART rx_valid");
        lectura_cpu_verificar(UART_RX_DATA,32'h000000A5,"UART RX_DATA");
        lectura_cpu_verificar(UART_CONTROL,32'h00000003,"UART lectura no limpia rx_valid");
        escritura_cpu(UART_CONTROL,32'h00000002);
        lectura_cpu_verificar(UART_CONTROL,32'h00000001,"UART limpia rx_valid");

        // Modelos sincronos de entradas y memoria VGA.
        lectura_cpu_verificar(INPUT_ADDRESS,valor_modelo_entradas,"modelo de entradas");

        @(negedge clk);cpu_addr=VGA_BASE;cpu_we=0;#1;
        verificar(vga_addr===9'd0,"VGA direccion local 0");
        @(posedge clk);#1;
        verificar(cpu_rdata===modelo_vga_inicial,"modelo VGA indice 0");

        @(negedge clk);cpu_addr=VGA_LAST;cpu_we=0;#1;
        verificar(vga_addr===9'd511,"VGA direccion local 511");
        @(posedge clk);#1;
        verificar(cpu_rdata===modelo_vga_final,"modelo VGA indice 511");

        // Una direccion invalida no habilita ningun destino y lee cero.
        @(negedge clk);
        cpu_addr=32'hDEADBEEF;
        cpu_wdata=32'hFFFFFFFF;
        cpu_we=1;
        #1;
        verificar_habilitaciones_escritura_apagadas("direccion invalida sin write enable");
        @(posedge clk);#1;
        @(negedge clk);cpu_we=0;
        lectura_cpu_verificar(32'hDEADBEEF,32'h00000000,"lectura no mapeada");

        if(errores==0)
            $display("mmio_subsystem_integration_tb: TODAS LAS PRUEBAS PASARON (%0d verificaciones)",verificaciones);
        else
            $fatal(1,"mmio_subsystem_integration_tb: %0d errores en %0d verificaciones",
                   errores,verificaciones);
        $finish;
    end

    initial begin #5ms;$fatal(1,"TIEMPO DE ESPERA AGOTADO mmio_subsystem_integration_tb");end
endmodule
