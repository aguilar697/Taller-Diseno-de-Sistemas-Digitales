`timescale 1ns / 1ps
// Verifica el periférico completo con maestro AXI de prueba y modelo real XADC.
// Comprueba la secuencia de adquisición y ACK atrasados sin sustituir módulos externos.
module tb_adc_system_axi;
    `include "adc_axi_tb_tasks.svh"
    logic pwm_trigger = 0;
    logic [31:0] data, snapshot, token1, token2, token3;
    logic monitor_enable = 0;
    integer phase = 0, n_convst = 0, n_busy = 0, n_eoc = 0, n_den = 0, n_drdy = 0, n_sample = 0;
    time t_convst, t_drdy;
    adc_system_axi #(.ADDR_WIDTH(ADDR_WIDTH), .ADC_TIMEOUT_CYCLES(1024)) dut (
        .s_axi_aclk(clk), .s_axi_aresetn(resetn),
        .s_axi_awaddr(awaddr), .s_axi_awprot(awprot), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arprot(arprot), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready), .pwm_trigger_i(pwm_trigger), .vauxp6(1'b0), .vauxn6(1'b0)
    );
    assign start_observed = dut.start_sw;
    assign ack_observed = dut.ack_sample;

    // Monitores de orden y latencia sobre señales del diseño, sin forzarlas.
    always @(posedge dut.u_adc.convst) if (monitor_enable) begin
        if (phase!=0 && phase!=6) $fatal(1,"CONVST fuera de secuencia");
        phase=1; n_convst++; t_convst=$time;
    end
    always @(posedge dut.xadc_busy) if (monitor_enable) begin
        if (phase!=1) $fatal(1,"BUSY fuera de secuencia");
        phase=2; n_busy++;
    end
    always @(posedge dut.u_adc.eoc) if (monitor_enable) begin
        if (phase!=2) $fatal(1,"EOC fuera de secuencia");
        if (dut.u_adc.adc_channel!==5'h16) $fatal(1,"Canal no es VAUX6");
        phase=3; n_eoc++;
    end
    always @(posedge dut.u_adc.den) if (monitor_enable) begin
        if (phase!=3 || dut.u_adc.daddr!==7'h16 || dut.u_adc.dwe!==0)
            $fatal(1,"DEN/direccion DRP incorrectos");
        phase=4; n_den++;
    end
    always @(posedge dut.u_adc.drdy) if (monitor_enable) begin
        if (phase!=4) $fatal(1,"DRDY fuera de secuencia");
        phase=5; n_drdy++; t_drdy=$time;
    end
    always @(dut.sample) if (monitor_enable && dut.sample[31:16]!=0) begin
        if (phase!=5) $fatal(1,"Publicacion sin DRDY");
        phase=6; n_sample++;
        $display("LATENCIA ID=%0d CONVST_DRDY=%0d ns (%0d ciclos), CONVST_SAMPLE=%0d ns (%0d ciclos)",
            dut.sample[31:16],t_drdy-t_convst,(t_drdy-t_convst)/10,$time-t_convst,($time-t_convst)/10);
    end

    task automatic check_word(input logic[31:0] word, input logic[15:0] id);
        if ($isunknown(word) || word[31:16]!==id || word[15:12]!==0)
            $fatal(1,"Formato/ID incorrecto: %h",word);
        if (word[11:0]<12'he62 || word[11:0]>12'he6a)
            $fatal(1,"Estimulo0.9V inesperado: %h",word);
        $display("MUESTRA AXI: %h",word);
    endtask
    task automatic wait_sample(input logic[15:0] id);
        integer tries;
        tries=0;
        do begin
            read_tx(8,0,0,data);
            tries++;
            if (tries>1000) $fatal(1,"No llego muestra por AXI");
        end while(data[31:16]!==id);
        check_word(data,id);
    endtask

    assign ack_id_observed = dut.ack_id;
    initial begin
        // Inicialización del modelo y lectura de estado de reposo.
        reset_bus();
        repeat(5000) @(negedge clk);
        monitor_enable=1;
        read_tx(4,0,0,data);
        if(data!==0) $fatal(1,"STATUS inicial incorrecto");
        read_tx(12,0,0,data);
        if(data!==0) $fatal(1,"ERROR inicial incorrecto");
        // Primera conversión solicitada por software mediante START.
        write_tx(0,1,1,0,0,0,0);
        // Las lecturas AXI responden aun mientras el conversor sigue ocupado.
        read_tx(4,0,0,data);
        if(data[2]!==1'b1) $fatal(1,"No se observo ADC ocupado");
        wait_sample(1);
        read_tx(4,0,0,data);
        if(data!==3) $fatal(1,"STATUS tras START incorrecto: %h",data);
        read_tx(12,0,0,data);
        if(data!==0) $fatal(1,"Error nominal de adquisicion");
        // SAMPLE ya leído: obtener y reconocer exactamente su token.
        read_tx(16,0,0,token1);
        if(token1!==1) $fatal(1,"Token primera muestra");
        write_tx(16,token1,15,0,0,0,0);
        read_tx(4,0,0,data);
        if(data!==1) $fatal(1,"ACK no limpio new_data/conservo valid");

        // Congelar una respuesta SAMPLE mientras llega la segunda conversión real.
        begin_read(8);
        snapshot=rdata;
        @(negedge clk); pwm_trigger=1;
        @(negedge clk); pwm_trigger=0;
        wait(dut.sample[31:16]===16'd2);
        repeat(4) @(negedge clk);
        if(rdata!==snapshot || rresp!==0 || rvalid!==1) $fatal(1,"Respuesta SAMPLE cambio tras PWM");
        if(dut.new_data!==1) $fatal(1,"Lectura implico ACK no autorizado");
        @(negedge clk); rready=1;
        @(negedge clk); rready=0;
        // ACK_ID conserva el token 1 aunque ya exista muestra 2; un ACK tardío no la consume.
        read_tx(16,0,0,data);
        if(data!==token1) $fatal(1,"Token SAMPLE antiguo cambio al publicar");
        write_tx(16,token1,15,0,0,0,0);
        read_tx(4,0,0,data);
        if(data!==3) $fatal(1,"ACK atrasado deID1 consumio ID2");
        wait_sample(2);
        read_tx(4,0,0,data);
        if(data!==3) $fatal(1,"STATUS tras PWM incorrecto");
        read_tx(16,0,0,token2);
        if(token2!==2) $fatal(1,"Token segunda muestra");
        write_tx(16,token2,15,0,0,0,0);

        // Negativa práctica sin alterar IP: solicitud extra mientras busy.
        write_tx(0,1,1,0,0,0,0);
        write_tx(0,1,1,0,0,0,0);
        wait_sample(3);
        read_tx(12,0,4,data);
        if(data!==1) $fatal(1,"No detecto trigger rechazado: %h",data);
        read_tx(4,0,0,data);
        if(data!==19) $fatal(1,"STATUS diagnostico incorrecto: %h",data);
        if(n_convst!=3 || n_busy!=3 || n_eoc!=3 || n_den!=3 || n_drdy!=3 || n_sample!=3)
            $fatal(1,"Perdida/duplicacion de conversion");
        // La carrera original se comprueba también por AXI con el IP real en simulación.
        read_tx(16,0,0,token3);
        if(token3!==3) $fatal(1,"Token tercera muestra");
        write_tx(16,token2,15,0,5,5,0);
        read_tx(4,0,0,data);
        if(data!==19) $fatal(1,"ACK_STALE_CLEARED_NEW_DATA_AXI");
        write_tx(0,2,1,0,0,0,2);
        read_tx(4,0,0,data);
        if(data!==19) $fatal(1,"ACK antiguo consumio muestra");
        write_tx(16,token3,15,0,0,0,0);
        write_tx(16,token3,15,0,0,0,0);
        read_tx(4,0,0,data);
        if(data!==17) $fatal(1,"ACK valido/duplicado no cumple contrato");
        if(start_count!=3 || ack_count!=6 || dut.timeout!==0 || dut.overrun!==0)
            $fatal(1,"Comandos/errores inesperados");
        $display("AXI + XADC REAL EN SIMULACION: TEST PASSED; 3 conversiones; ACK_ID valido, atrasado y duplicado; timeout1024");
        $finish;
    end
endmodule
