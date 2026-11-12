`timescale 1ns / 1ps
// Verifica el protocolo AXI, el mapa fijo y el transporte atómico del token ACK.
// Los estados de adquisición se modelan; los casos de comparación están en tb_adc_concurrency.
module tb_adc_axi_lite;
    `include "adc_axi_tb_tasks.svh"
    logic [31:0] sample_i = 0;
    logic [31:0] sample_token_i=0, ack_id;
    logic [6:0] flags = 0;
    logic [31:0] data;
    integer before_start, before_ack, before_aw, before_w, before_b;
    integer cases_passed = 0;
    adc_axi_lite #(.ADDR_WIDTH(ADDR_WIDTH)) dut (
        .s_axi_aclk(clk), .s_axi_aresetn(resetn),
        .s_axi_awaddr(awaddr), .s_axi_awprot(awprot), .s_axi_awvalid(awvalid), .s_axi_awready(awready),
        .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
        .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
        .s_axi_araddr(araddr), .s_axi_arprot(arprot), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
        .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
        .sample_i(sample_i), .sample_token_i(sample_token_i), .valid_i(flags[0]), .new_data_i(flags[1]), .busy_i(flags[2]),
        .xadc_busy_i(flags[3]), .missed_trigger_i(flags[4]), .overrun_i(flags[5]), .timeout_i(flags[6]),
        .start_sw_o(start_observed), .ack_sample_o(ack_observed), .ack_id_o(ack_id)
    );
    task automatic passed(input integer number);
        cases_passed++;
        $display("CASO AXI %0d PASSED",number);
    endtask
    assign ack_id_observed = ack_id;
    initial begin
        // Caso 1: el reset cancela respuestas y comandos.
        reset_bus();
        read_tx(0,0,0,data);
        if (data !== 0 || start_count != 0 || ack_count != 0) $fatal(1,"Reposo incorrecto");
        passed(1);
        // Ejecución negativa separada: el monitor debe impedir un falso PASS.
        if ($test$plusargs("INJECT_X")) begin
            send_aw(6'b00x000,0);
            $fatal(1,"El monitor no detecto X");
        end
        // Caso 2: todas las combinaciones de estado.
        for (int i=0;i<128;i++) begin
            @(negedge clk); flags = i;
            read_tx(4,0,0,data);
            if (data !== i) $fatal(1,"STATUS incorrecto flags=%h",flags);
        end
        passed(2);
        // Caso 3: SAMPLE conserva 32 bits, incluido el ID.
        @(negedge clk); sample_i=32'hcafe_0abc;
        read_tx(8,0,0,data);
        if (data !== 32'hcafe_0abc) $fatal(1,"SAMPLE truncado");
        passed(3);
        // Caso 4: diagnóstico con las ocho combinaciones de error.
        for (int i=0;i<8;i++) begin
            @(negedge clk); flags = (i<<4);
            read_tx(12,0,0,data);
            if (data !== i) $fatal(1,"ERROR incorrecto");
        end
        passed(4);
        // Caso 5: START emite un solo pulso.
        before_start=start_count; before_ack=ack_count;
        write_tx(0,1,15,0,0,0,0);
        repeat(4) @(negedge clk);
        if (start_count != before_start+1 || ack_count != before_ack) $fatal(1,"START duplicado");
        passed(5);
        // Caso 6: ACK_ID transporta el token completo una sola vez.
        write_tx(16,32'h1234cafe,15,0,0,0,0);
        repeat(4) @(negedge clk);
        if (ack_count != before_ack+1 || start_count != before_start+1 || ack_id!==32'h1234cafe) $fatal(1,"ACK duplicado");
        passed(6);
        before_start=start_count; before_ack=ack_count;
        // Caso 7: WSTRB habilita únicamente el byte de START.
        for (int i=0;i<16;i++) begin
            write_tx(0,1,i,0,0,0,0);
            if (i[0]) before_start++;
            if (start_count != before_start || ack_count != before_ack) $fatal(1,"WSTRB incorrecto=%h",i);
        end
        // Los bits reservados se ignoran aunque todos los bytes estén habilitados.
        write_tx(0,32'hffff_fffc,15,0,0,0,0);
        if (start_count != before_start || ack_count != before_ack) $fatal(1,"Bits reservados producen comandos");
        passed(7);
        // Caso 8: AW y W pueden llegar separados y en cualquier orden.
        write_tx(0,1,1,0,7,0,0);
        write_tx(0,1,1,7,0,0,0);
        if (start_count != before_start+2) $fatal(1,"AW/W separados incorrectos");
        passed(8);
        // Caso 9: llegada simultánea de AW/W.
        before_start=start_count;
        write_tx(0,1,1,0,0,0,0);
        if (start_count != before_start+1) $fatal(1,"AW/W simultaneos incorrectos");
        passed(9);
        // Caso 10: BREADY detenido no repite el comando.
        before_start=start_count;
        write_tx(0,1,1,0,0,9,0);
        if (start_count != before_start+1) $fatal(1,"B stall duplico comando");
        passed(10);
        // Caso 11: RDATA se congela mientras RREADY está desactivado.
        @(negedge clk); sample_i=32'h1234_0567;
        fork
            read_tx(8,0,9,data);
            begin
                wait(rvalid===1'b1);
                repeat(4) begin @(negedge clk); sample_i=sample_i+32'h10001; end
            end
        join
        if (data !== 32'h1234_0567) $fatal(1,"SAMPLE no fue instantanea");
        passed(11);
        // Caso 12: offsets inválidos y no alineados devuelven SLVERR.
        for (int i=1;i<64;i++) if (i!=4 && i!=8 && i!=12 && i!=16) begin
            read_tx(i,2,0,data);
            if (data !== 0) $fatal(1,"Lectura erronea debe devolver0");
        end
        passed(12);
        before_start=start_count; before_ack=ack_count;
        // Caso 13: ninguna escrituraRO/inválida emite comandos.
        for (int i=1;i<64;i++) if(i!=16) write_tx(i,3,15,0,0,0,2);
        if (start_count != before_start || ack_count != before_ack) $fatal(1,"Write RO/invalid tuvo efectos");
        passed(13);
        // VALID sostenido: cada handshake es una transacción nueva; tres y solo tres.
        before_aw=aw_count; before_w=w_count; before_b=b_count; before_start=start_count;
        @(negedge clk); awaddr=0; wdata=1; wstrb=1; awvalid=1; wvalid=1; bready=1;
        while (b_count < before_b+3) begin
            @(negedge clk);
            if (aw_count >= before_aw+3) awvalid=0;
            if (w_count >= before_w+3) wvalid=0;
        end
        bready=0;
        repeat(4) @(negedge clk);
        if (aw_count!=before_aw+3 || w_count!=before_w+3 || start_count!=before_start+3)
            $fatal(1,"Burst continuo perdido/duplicado");
        passed(14);
        // AW parcial, W parcial, B y R pendientes: reset cancela cada caso.
        send_aw(0,0); reset_bus();
        send_w(1,1,0); reset_bus();
        fork send_aw(0,0); send_w(1,1,0); join
        wait(bvalid===1); reset_bus();
        begin_read(8); reset_bus();
        before_start=start_count;
        write_tx(0,1,1,0,3,0,0);
        if (start_count!=before_start+1) $fatal(1,"Recuperacion reset fallo");
        passed(15);
        // Caso 16: lectura y escritura son canales independientes.
        before_start=start_count; before_ack=ack_count;
        fork
            write_tx(0,1,1,0,0,3,0);
            begin @(negedge clk); sample_i=32'habcd_0123; end
            read_tx(8,0,3,data);
        join
        if (start_count!=before_start+1 || ack_count!=before_ack) $fatal(1,"Lectura/escritura concurrentes");
        if (data!==32'habcd_0123) $fatal(1,"Lectura concurrente incorrecta");
        passed(16);
        // El mismo monitor se comprueba con +INJECT_X en una ejecución negativa.
        if (!$isunknown(6'b00x000)) $fatal(1,"Detector de desconocidos no disponible");
        passed(17);
        // Caso 18: el resumen solo se emite tras comprobar los casos anteriores.
        if (cases_passed!=17) $fatal(1,"Faltan casos");
        passed(18);
        // Caso 19: ACK_ID pertenece a la instantánea SAMPLE, no a la muestra más reciente.
        @(negedge clk); sample_i=32'h1234_0800; sample_token_i=32'h0001_1234;
        read_tx(8,0,0,data);
        @(negedge clk); sample_i=32'h1234_0a00; sample_token_i=32'h0002_1234;
        read_tx(16,0,5,data);
        if(data!==32'h0001_1234) $fatal(1,"Token no corresponde a SAMPLE leido");
        passed(19);

        // Caso 20: ACK_ID exige 32 bits completos; WSTRB igual a cero no produce efectos.
        before_ack=ack_count;
        for(int mask=0;mask<16;mask++) begin
            write_tx(16,32'habcd1234,mask,0,0,3,(mask==0 || mask==15)?0:2);
            if(mask==15) before_ack++;
            if(ack_count!=before_ack) $fatal(1,"ACK parcial/duplicado");
        end
        write_tx(16,0,15,0,0,0,2);
        if(ack_count!=before_ack) $fatal(1,"ACK token0 aceptado");
        passed(20);

        // Caso 21: el comando antiguo se rechaza entero; tampoco inicia START+ACK.
        before_start=start_count; before_ack=ack_count;
        write_tx(0,2,1,0,0,0,2); write_tx(0,3,1,0,0,0,2);
        if(start_count!=before_start || ack_count!=before_ack) $fatal(1,"ACK antiguo aun tiene efecto");
        passed(21);

        // Caso 22: reset elimina el token capturado y escrituras ACK_ID parciales en vuelo.
        send_aw(16,0); reset_bus();
        send_w(32'h1234,15,0); reset_bus();
        read_tx(16,0,0,data);
        if(data!==0 || ack_id!==0) $fatal(1,"Reset conservo token/comando");
        before_ack=ack_count;
        write_tx(16,32'h1234,15,0,4,0,0);
        if(ack_count!=before_ack+1) $fatal(1,"ACK posterior areset duplicado");
        passed(22);

        // Caso 23: captura SAMPLE y write ACK_ID pueden estar pendientes a la vez.
        @(negedge clk); sample_i=32'h0002_0800; sample_token_i=2;
        before_ack=ack_count;
        fork
            read_tx(8,0,6,data);
            write_tx(16,1,15,0,2,6,0);
        join
        if(data!==32'h00020800 || ack_count!=before_ack+1 || ack_id!==1)
            $fatal(1,"Token alterado por lectura concurrente");
        read_tx(16,0,0,data);
        if(data!==2) $fatal(1,"Instantanea token concurrente incorrecta");
        passed(23);

        // Caso 24: ACK_ID conserva orden y payload con AW/W separados y backpressure.
        before_ack=ack_count;
        write_tx(16,32'h00010000,15,0,7,8,0);
        write_tx(16,32'h00010001,15,7,0,8,0);
        if(ack_count!=before_ack+2 || ack_id!==32'h00010001) $fatal(1,"ACK_ID perdio orden/datos");
        passed(24);
        if(cases_passed!=24) $fatal(1,"Faltan casos AXI");
        $display("AXI: 24/24 CASOS; TEST PASSED");
        $finish;
    end
endmodule
