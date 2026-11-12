`timescale 1ns / 1ps
// Verifica ACK válido/atrasado, prioridades, reset y no reutilización de identificadores.
// Las respuestas XADC son estímulos digitales; no se modifica ni instancia el IP aquí.
module tb_adc_concurrency;
    logic clk=0; always #5 clk=~clk;
    logic resetn=0, pwm=0, start=0, ack=0, eoc=0, drdy=0;
    logic [31:0] ack_id=0, token;
    logic [15:0] raw=0;
    logic convst,den,dwe,busy,valid,new_data,missed,overrun,timeout;
    logic [6:0] addr;
    logic [31:0] sample, saved_sample, saved_token;
    integer cases_passed=0;
    adc_control #(.TIMEOUT_CYCLES(20)) dut (
        .clk(clk),.aresetn(resetn),.pwm_trigger_i(pwm),.start_sw_i(start),
        .ack_sample_i(ack),.ack_id_i(ack_id),
        .eoc_i(eoc),.drdy_i(drdy),.do_i(raw),.convst_o(convst),.den_o(den),.daddr_o(addr),.dwe_o(dwe),
        .busy_o(busy),.valid_o(valid),.new_data_o(new_data),.sample_o(sample),.sample_token_o(token),
        .missed_trigger_o(missed),.overrun_o(overrun),.timeout_o(timeout)
    );
    // Las tareas conducen en flanco negativo para no competir con la lógica secuencial.
    task automatic reset_adc;
        @(negedge clk); resetn=0; start=0; pwm=0; ack=0; eoc=0; drdy=0; ack_id=0;
        repeat(3) @(negedge clk); resetn=1;
        @(negedge clk);
        if({valid,new_data,busy,timeout,overrun,missed}!==0 || sample!==0 || token!==0)
            $fatal(1,"Reset no cancela estado/muestras/errores");
    endtask
    task automatic send_ack(input logic[31:0] id);
        @(negedge clk); ack_id=id; ack=1;
        @(negedge clk); ack=0;
    endtask
    task automatic convert(input logic[15:0] value, input logic ack_with_drdy, input logic[31:0] id);
        @(negedge clk); start=1;
        @(negedge clk); start=0; eoc=1;
        @(negedge clk); eoc=0;
        wait(den===1);
        @(negedge clk); raw=value; drdy=1; ack=ack_with_drdy; ack_id=id;
        @(negedge clk); drdy=0; ack=0;
    endtask
    task automatic passed(input string name);
        cases_passed++;
        $display("CASO ACK %0d: %s PASS",cases_passed,name);
    endtask
    initial begin
        // Sin publicación válida, ningún identificador reconoce una muestra.
        reset_adc(); send_ack(1);
        if(new_data!==0 || valid!==0) $fatal(1,"ACK antes de primera muestra");
        passed("reset y ACK sin muestra");
        convert(16'h8000,0,0);
        send_ack(0); send_ack(2);
        if(new_data!==1 || token!==1) $fatal(1,"ACK cero/futuro afecto dato");
        passed("ACK invalido y futuro ignorados");

        // El ACK válido solo limpia new_data; SAMPLE y valid permanecen disponibles.
        send_ack(1);
        if(new_data!==0 || valid!==1 || sample!==32'h00010800) $fatal(1,"ACK valido incorrecto");
        passed("ACK valido");
        send_ack(1);
        if(new_data!==0 || sample!==32'h00010800) $fatal(1,"ACK duplicado altero muestra");
        passed("ACK duplicado idempotente");

        // Regresión crítica: leerID 2, publicarID 3 y reconocerID 2 debe preservar new_data deID 3.
        convert(16'ha000,0,0); saved_token=token;
        convert(16'h4000,0,0);
        send_ack(saved_token);
        if(new_data!==1 || sample!==32'h00030400 || token!==3)
            $fatal(1,"ACK_STALE_CLEARED_NEW_DATA");
        passed("ACK atrasado deID2 preservaID3");
        send_ack(3); convert(16'h2000,0,0); send_ack(3);
        if(new_data!==1 || token!==4) $fatal(1,"Duplicado consumio publicacion posterior");
        passed("ACK duplicado posterior no consume otra muestra");

        // Si se publica y reconoce el dato anterior en el mismo flanco, gana publicación.
        reset_adc(); convert(16'h8000,0,0); convert(16'ha000,1,1);
        if(new_data!==1 || token!==2 || overrun!==0) $fatal(1,"Prioridad publicacion/ACK valido");
        passed("publicacion simultanea con ACK valido anterior");
        convert(16'h4000,1,1);
        if(new_data!==1 || token!==3 || overrun!==1) $fatal(1,"ACK obsoleto oculto overrun");
        passed("publicacion simultanea con ACK atrasado");
        convert(16'h2000,1,4);
        if(new_data!==1 || token!==4) $fatal(1,"ACK del valor futuro consumio publicacion");
        passed("ACK de token futuro no anticipa publicacion");

        // La recuperación de timeout conserva dato y token; ACK no borra diagnóstico.
        saved_sample=sample; saved_token=token;
        @(negedge clk); pwm=1;
        @(negedge clk); pwm=0;
        repeat(24) @(negedge clk);
        if(timeout!==1 || busy!==0 || sample!==saved_sample || token!==saved_token)
            $fatal(1,"Timeout altero dato/token");
        send_ack(saved_token); convert(16'h1000,0,0);
        if(new_data!==1 || token!==5 || timeout!==1) $fatal(1,"Recuperacion o flags sticky");
        passed("timeout conserva token y permite recuperacion modelada");
        @(negedge clk); start=1;
        @(negedge clk); start=0;
        reset_adc(); send_ack(5);
        if(new_data!==0 || token!==0) $fatal(1,"Reset dejo ACK/operacion pendientes");
        passed("reset durante adquisicion");

        // Recorrer realmente ID 16 completo; no se precarga el contador para esta prueba.
        for(int i=1;i<=65537;i++) begin
            convert(16'h8000,0,0);
            if(i==65535 && (sample[31:16]!==16'hffff || token!==32'h0000ffff))
                $fatal(1,"Frontera ID16 incorrecta");
            if(i==65536) begin
                if(sample[31:16]!==0 || token!==32'h00010000) $fatal(1,"Wrap16 sin generacion");
                send_ack(32'hffff);
                if(new_data!==1) $fatal(1,"ACK previo al wrap consumio ID0");
                passed("wrap16 FFFF a0000 preserva generacion");
            end
        end
        send_ack(1);
        if(sample[31:16]!==1 || token!==32'h00010001 || new_data!==1)
            $fatal(1,"ACK ABA de primera generacion consumio ID1 nuevo");
        send_ack(32'h10001);
        if(new_data!==0) $fatal(1,"ACK valido despues del wrap no funciona");
        passed("mismo ID16 con distinta generacion rechaza ACK viejo");

        // Precarga solo del controlador digital para probar 2^32 sin simular miles de millones.
        // No se fuerza ninguna señal ni netlist del XADC Wizard.
        reset_adc();
        @(negedge clk); force dut.sample_id=16'hfffe; force dut.sample_token_o=32'hffff_fffe;
        @(negedge clk); release dut.sample_id; release dut.sample_token_o;
        convert(16'h8000,0,0);
        if(token!==32'hffffffff) $fatal(1,"Token maximo no disponible");
        send_ack(32'hffffffff);
        if(new_data!==0) $fatal(1,"Token maximo no reconocible");
        convert(16'ha000,0,0); send_ack(32'hffffffff);
        convert(16'h4000,0,0); send_ack(1);
        if(token!==0 || new_data!==1 || dut.ack_exhausted!==1)
            $fatal(1,"Agotamiento32 reutilizo un token antiguo");
        passed("agotamiento32 bloquea ACK sin detener conversiones");
        reset_adc(); convert(16'h8000,0,0); send_ack(1);
        if(token!==1 || new_data!==0) $fatal(1,"Nueva sesion no reinicia protocolo");
        passed("reset coordinado recupera capacidad de reconocimiento");
        if(cases_passed!=15) $fatal(1,"Faltan casos ACK");
        $display("ACK POR IDENTIFICADOR: 15/15 CASOS; TEST PASSED");
        $finish;
    end
    initial begin #20000000; $fatal(1,"Watchdog concurrencia"); end
endmodule
