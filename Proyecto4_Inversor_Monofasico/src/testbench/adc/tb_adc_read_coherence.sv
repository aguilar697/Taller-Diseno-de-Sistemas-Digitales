`timescale 1ns / 1ps
// Reproduce lecturas SAMPLE/ACK_ID separadas por publicaciones del XADC real simulado.
// El maestro usa transacciones AXI completas; las observaciones internas no fuerzan el IP.
module tb_adc_read_coherence;
    `include "adc_axi_tb_tasks.svh"
    logic [31:0] word_read, token_read, state_read, response_read;
    logic [31:0] cpu_word=0, cpu_expected_token=0;
    logic cpu_ack_active=0, bad_ack_seen=0;
    integer cases_passed=0, ack_before_reset;
    adc_system_axi #(.ADDR_WIDTH(ADDR_WIDTH), .ADC_TIMEOUT_CYCLES(1024)) dut (
        .s_axi_aclk(clk), .s_axi_aresetn(resetn),
        .s_axi_awaddr(awaddr), .s_axi_awprot(awprot), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arprot(arprot), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .pwm_trigger_i(1'b0), .vauxp6(1'b0), .vauxn6(1'b0)
    );
    assign start_observed=dut.start_sw;
    assign ack_observed=dut.ack_sample;
    assign ack_id_observed=dut.ack_id;

    // Scoreboard independiente: el ACK debe pertenecer al dato que procesó el maestro.
    // Se registra el fallo y se comprueba después del write, sin impedir el efecto del ACK.
    always @(posedge clk) begin
        if(!resetn) bad_ack_seen=0;
        else if(cpu_ack_active && ack_observed) begin
            if(ack_id_observed!==cpu_expected_token ||
               ack_id_observed[15:0]!==cpu_word[31:16]) bad_ack_seen=1;
            if(dut.u_adc.u_adc_control.ack_matches && dut.sample!==cpu_word)
                bad_ack_seen=1;
        end
    end

    task automatic passed(input string label);
        cases_passed++;
        $display("CASO LECTURA %0d: %s PASS",cases_passed,label);
    endtask
    task automatic initialize_model;
        cpu_ack_active=0;
        reset_bus();
        repeat(5000) @(negedge clk);
    endtask
    task automatic publish(input logic[15:0] expected_id);
        logic [31:0] status;
        integer tries;
        write_tx(0,1,1,0,0,0,0);
        tries=0;
        // Se consulta STATUS, nunca SAMPLE: la espera no debe renovar el snapshot probado.
        do begin
            read_tx(4,0,0,status);
            tries++;
            if(tries>1000 || status[6]!==0) $fatal(1,"No se completo conversion nominal");
        end while(status[2]!==0 || status[0]!==1);
        if(dut.sample[31:16]!==expected_id || dut.sample[15:12]!==0)
            $fatal(1,"Publicacion inesperada");
    endtask
    task automatic check_pending(input logic expected);
        read_tx(4,0,0,state_read);
        if(state_read[1]!==expected) $fatal(1,"Notificacion pendiente incorrecta");
    endtask
    task automatic processor_ack(input logic[31:0] processed_word,
        input logic[31:0] expected_token,input logic[31:0] bus_token);
        @(negedge clk);
        cpu_word=processed_word; cpu_expected_token=expected_token; cpu_ack_active=1;
        write_tx(16,bus_token,15,0,0,3,0);
        @(negedge clk); cpu_ack_active=0;
        if(bad_ack_seen) begin
            $display("UNSAFE_PAIR: processed_id=%0d ack=%h live_id=%0d new_data=%0b",
                cpu_word[31:16],bus_token,dut.sample[31:16],dut.new_data);
            $fatal(1,"READ_PAIR_ACKED_UNPROCESSED_SAMPLE");
        end
    endtask

    initial begin
        // Caso1: ACK_ID no sigue al conversor y vale0 hasta capturar SAMPLE.
        initialize_model();
        read_tx(16,0,0,token_read);
        if(token_read!==0) $fatal(1,"Snapshot inicial no es cero");
        publish(1);
        read_tx(16,0,0,token_read);
        if(token_read!==0) $fatal(1,"Publicar renovo snapshot sin leer SAMPLE");
        read_tx(8,0,0,word_read); read_tx(16,0,0,token_read);
        processor_ack(word_read,1,token_read); check_pending(0);
        passed("snapshot inicial y ACK valido");

        // Caso2: lectura SAMPLE2 completada, publicacion3, lectura ACK_ID y write del token.
        publish(2);
        read_tx(8,0,0,word_read);
        if(word_read[31:16]!==2) $fatal(1,"No se leyo ID2");
        publish(3);
        read_tx(16,0,0,token_read);
        $display("ESCENARIO ID2_ID3: SAMPLE_ID=%0d LIVE_ID=%0d ACK_ID=%h",
            word_read[31:16],dut.sample[31:16],token_read);
        processor_ack(word_read,2,token_read);
        check_pending(1);
        if(token_read!==2) $fatal(1,"ACK_ID cambio al publicarse ID3");
        read_tx(12,0,0,response_read);
        if(response_read[1]!==1) $fatal(1,"Sobrescritura no diagnosticada");
        passed("SAMPLE2 publicacion3 ACK_ID2 preserva new_data3");

        // Caso3: publicar entre la ultima lectura y ACK tampoco consume el dato posterior.
        read_tx(8,0,0,word_read); read_tx(16,0,0,token_read);
        if(word_read[31:16]!==3 || token_read!==3) $fatal(1,"Pareja ID3 incorrecta");
        publish(4);
        processor_ack(word_read,3,token_read); check_pending(1);
        passed("publicacion posterior a lectura de token");

        // Caso4: varias sobrescrituras no actualizan el token capturado para SAMPLE4.
        read_tx(8,0,0,word_read);
        publish(5); publish(6);
        read_tx(16,0,0,token_read);
        processor_ack(word_read,4,token_read); check_pending(1);
        if(token_read!==4 || dut.sample[31:16]!==6) $fatal(1,"Snapshot perdio identidad");
        passed("multiples publicaciones entre lecturas");

        // Caso5: respuesta SAMPLE detenida durante publicacion; palabra y token siguen juntos.
        begin_read(8); word_read=rdata;
        // R sigue ocupado: iniciar por AW/W y observar publicacion sin abrir otra lectura.
        write_tx(0,1,1,0,0,0,0);
        wait(dut.sample[31:16]===16'd7);
        @(negedge clk);
        if(rvalid!==1 || rdata!==word_read) $fatal(1,"RDATA cambio bajo backpressure");
        @(negedge clk); rready=1;
        @(negedge clk); rready=0;
        read_tx(16,0,0,token_read);
        processor_ack(word_read,6,token_read); check_pending(1);
        passed("snapshot con RREADY detenido");

        // Caso6: ACK de la muestra vigente y duplicado conservan SAMPLE/valid.
        read_tx(8,0,0,word_read); read_tx(16,0,0,token_read);
        processor_ack(word_read,7,token_read); check_pending(0);
        processor_ack(word_read,7,token_read); check_pending(0);
        if(dut.sample!==word_read || dut.valid!==1) $fatal(1,"ACK altero dato/validez");
        passed("lectura coherente y ACK valido/duplicado");

        // Caso7: otro lector de SAMPLE cambia el snapshot; el contrato exige exclusion.
        read_tx(8,0,0,word_read);
        publish(8);
        read_tx(8,0,0,response_read); // Segundo lector: no se permite en la pareja del primero.
        read_tx(16,0,0,token_read);
        if(word_read[31:16]!==7 || token_read!==8) $fatal(1,"Prueba de lector intercalado invalida");
        // No reconocer una pareja mezclada; recuperar una pareja nueva bajo exclusion.
        check_pending(1);
        read_tx(8,0,0,word_read); read_tx(16,0,0,token_read);
        processor_ack(word_read,8,token_read); check_pending(0);
        passed("intercalacion requiere serializar lectores");

        // Caso8: reset entre SAMPLE y ACK_ID invalida snapshot y cancela el consumo viejo.
        read_tx(8,0,0,word_read);
        initialize_model();
        read_tx(16,0,0,token_read);
        if(token_read!==0) $fatal(1,"Reset conservo snapshot anterior");
        publish(1);
        read_tx(16,0,0,token_read);
        if(token_read!==0) $fatal(1,"Primera publicacion restauro snapshot viejo");
        check_pending(1);
        passed("reset entre lecturas devuelve token invalido");

        // Caso9: reset despues de obtener token cancela el ACK por contrato de sesion.
        read_tx(8,0,0,word_read); read_tx(16,0,0,token_read);
        if(token_read!==1) $fatal(1,"Pareja previa areset incorrecta");
        ack_before_reset=ack_count;
        initialize_model(); publish(1);
        // El token numerico se repite tras reset; el maestro descarta la operacion vieja.
        token_read=0; word_read=0;
        if(ack_count!=ack_before_reset) $fatal(1,"Se emitio ACK cancelado por reset");
        check_pending(1);
        read_tx(8,0,0,word_read); read_tx(16,0,0,token_read);
        processor_ack(word_read,1,token_read); check_pending(0);
        passed("reset cancela token previo y exige pareja de nueva sesion");

        if(cases_passed!=9 || bad_ack_seen) $fatal(1,"Faltan casos o se reconocio otra muestra");
        $display("LECTURA COHERENTE AXI: 9/9 CASOS; TEST PASSED");
        $finish;
    end
endmodule
