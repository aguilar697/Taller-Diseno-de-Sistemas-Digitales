`timescale 1ns / 1ps
module tb_pwm_axi;
    `include "pwm_axi_tb.svh"
    integer j;

    initial begin
        reset_dut();
        read_reg(0,0,0,4); read_reg(4,0,0,0);
        read_reg(8,0,0,0); read_reg(12,0,0,0);
        write_reg(0,1,15,2,0,0,0); // No arrancar sin tiempo muerto.
        read_reg(0,0,0,0);
        write_reg(8,100,15,0,0,5,6); // AW antes de W; respuesta retenida.
        write_reg(12,5000,15,0,7,0,2); // W antes de AW.
        read_reg(8,100,0,3); read_reg(12,5000,0,3);
        write_reg(4,32'h7fff,15,0,0,0,0);
        read_reg(4,27853,0,0);
        write_reg(4,32'h8000,15,0,0,0,0);
        read_reg(4,32'h9333,0,0); // Extremo negativo saturado, sin extensión en lectura.
        write_reg(4,0,15,0,0,0,0);
        write_reg(4,32'h40,1,0,0,0,0);
        write_reg(4,32'hc000,2,0,0,0,0);
        read_reg(4,32'hc040,0,0);
        write_reg(4,32'hffff0000,12,0,0,0,0);
        read_reg(4,32'hc040,0,0);
        write_reg(8,32'hffffffff,0,0,0,0,0);
        read_reg(8,100,0,0);
        // Direcciones completas: un offset superior no se puede aliasar a CONTROL.
        for(j=1;j<4;j=j+1) begin
            write_reg(6'(j),0,15,2,0,0,0);
            read_reg(6'(j),0,2,2);
        end
        write_reg(16,0,15,2,0,0,0); read_reg(32,0,2,0);
        write_reg(0,6,15,2,0,0,0); // Frecuencia 11 inválida en reposo.
        write_reg(0,32'hffff0000,12,0,0,0,0);
        read_reg(0,0,0,0);
        // La coherencia se valida al habilitar, incluidos límites y desbordamientos.
        write_reg(8,32'hffffffff,15,0,0,0,0);
        write_reg(0,1,15,2,0,0,0);
        write_reg(8,100,15,0,0,0,0);
        write_reg(12,10000,15,0,0,0,0);
        write_reg(0,1,15,2,0,0,0);
        write_reg(12,5000,15,0,0,0,0);
        write_reg(4,0,15,0,0,0,0);
        write_reg(0,32'hffff0001,15,0,0,0,3);
        read_reg(0,9,0,0);
        write_reg(8,100,15,2,0,0,0);
        write_reg(12,0,15,2,0,0,0);
        write_reg(8,123,0,0,0,0,0);
        write_reg(0,3,15,2,0,0,0); // Cambiar frecuencia en operación.
        read_reg(0,9,0,0);
        write_reg(0,6,15,0,0,0,0); // Apagado prevalece sobre frecuencia inválida.
        read_reg(0,0,0,0);
        check({ah,al,bh,bl,trigger_adc}===0,"apagado sin esperar fin del periodo");
        write_reg(0,4,15,0,0,0,0); // 25 kHz.
        write_reg(12,2000,15,0,0,0,0);
        write_reg(8,201,15,0,0,0,0);
        write_reg(0,5,15,2,0,0,0); // 300 < 201 + MIN_ON=100.
        write_reg(8,200,15,0,0,0,0);
        write_reg(0,5,15,0,0,0,0); // Igualdad admitida.
        write_reg(0,0,15,0,0,0,0); read_reg(0,4,0,0);

        // Reset entre canales: la dirección anterior no sobrevive a otra sesión.
        send_aw(8,0);
        reset_dut();
        send_w(77,15,0);
        repeat(5) begin tick(); check(!bvalid,"W sin AW tras reset"); end
        send_aw(12,0); response_b(0,0);
        read_reg(8,0,0,0); read_reg(12,77,0,0);
        // Cancelar una respuesta B pendiente y una lectura R pendiente.
        fork send_aw(8,0); send_w(100,15,0); join
        while(!bvalid) tick();
        @(negedge clk); araddr=8; arvalid=1;
        @(posedge clk); @(negedge clk); arvalid=0;
        while(!rvalid) tick();
        reset_dut();
        check(!bvalid && !rvalid,"reset cancela respuestas");
        read_reg(8,0,0,0);
        // Repetición de transacciones con separaciones deterministas diferentes.
        for(j=0;j<100;j=j+1) begin
            write_reg(4,32'(j*37),15,0,j%4,(j+2)%5,j%3);
            read_reg(4,32'(j*37),0,j%4);
        end

        // Escritura aceptada exactamente al volver a cero: se usa la pareja anterior.
        write_reg(8,100,15,0,0,0,0);
        write_reg(12,5000,15,0,0,0,0);
        write_reg(4,0,15,0,0,0,0);
        write_reg(0,1,15,0,0,0,0);
        while(dut.core.phase_q!=9998) tick();
        @(negedge clk); awaddr=4; awvalid=1; wdata=16384; wstrb=15; wvalid=1;
        @(posedge clk); @(negedge clk); awvalid=0; wvalid=0;
        tick();
        check(period_start && dut.core.active_reference_q===0,"colision referencia/valle");
        check(dut.reference===16'sd16384,"nueva referencia pendiente");
        response_b(0,0);
        while(!period_start) tick();
        check(dut.core.active_reference_q===16'sd16384,"aplicacion en siguiente valle");

        if($test$plusargs("INJECT_ERROR")) begin
            // Se fuerza una violación solo en el TB; el monitor normal debe detectarla.
            force dut.pwm_ah=1'b1;
            force dut.pwm_al=1'b1;
            repeat(3) tick();
            $fatal(1,"ERROR_INJECTION_NOT_DETECTED");
        end
        write_reg(0,0,15,0,0,0,0);
        $display("TEST PASSED tb_pwm_axi checks=%0d",checks);
        $finish;
    end
endmodule
