`timescale 1ns/1ps
module cpu_datapath_tb;
    import cpu_pkg::*; import cpu_tb_pkg::*;
    logic clk=0,rst=1;
    logic [31:0] prog_in=0,data_in=0,pa,da,wd,ins;
    logic [2:0] kind,fmt; logic [3:0] op; logic[1:0] asel,wbsel;
    logic bs,legal,pcok,execok;
    logic ir=0,oper=0,exe=0,ld=0,pc=0,rf=0,access_mem=0,store=0;
    integer checks=0;
    always #5 clk=~clk;
    instruction_decoder decode(.instruction_i(ins),.legal_o(legal),.kind_o(kind),.imm_format_o(fmt),
        .alu_op_o(op),.alu_a_sel_o(asel),.result_sel_o(wbsel),.alu_b_sel_o(bs));
    cpu_datapath dut(.clk_i(clk),.rst_i(rst),.ProgIn_i(prog_in),.DataIn_i(data_in),.kind_i(kind),
        .imm_format_i(fmt),.alu_op_i(op),.alu_a_sel_i(asel),.result_sel_i(wbsel),.alu_b_sel_i(bs),
        .ir_en_i(ir),.operands_en_i(oper),.execute_en_i(exe),.load_en_i(ld),.pc_en_i(pc),.rf_we_i(rf),
        .mem_access_i(access_mem),.store_i(store),.ProgAddress_o(pa),.DataAddress_o(da),.DataOut_o(wd),
        .instruction_o(ins),.pc_valid_o(pcok),.execute_valid_o(execok));
    task automatic tick;@(posedge clk);#1;endtask
    task automatic prepare(input logic[31:0] instruction);
        @(negedge clk);prog_in=instruction;ir=1;tick();
        @(negedge clk);ir=0;oper=1;tick();
        @(negedge clk);oper=0;#1;if(!legal)$fatal(1,"Estimulo ilegal en datapath");
    endtask
    task automatic execute_write(input logic[31:0] instruction,input integer rd,input logic[31:0] expected);
        prepare(instruction);if(!execok)$fatal(1,"Ejecucion inesperadamente invalida");
        exe=1;tick();@(negedge clk);exe=0;rf=1;tick();
        if(rd!=0 && dut.registers.registers[rd]!==expected)$fatal(1,"Datapath rd=%0d",rd);
        @(negedge clk);rf=0;pc=1;tick();@(negedge clk);pc=0;checks++;
    endtask
    initial begin
        tick();@(negedge clk);rst=0;
        execute_write(enc_i(12,0,0,1),1,12);
        execute_write(enc_i(-4,1,0,2),2,8);
        execute_write(enc_r(0,2,1,0,3),3,20);
        execute_write(enc_u(2,20),20,32'h2000);
        prepare(enc_s(4,3,20));exe=1;tick();@(negedge clk);exe=0;access_mem=1;store=1;#1;
        if(da!==32'h2004 || wd!==20)$fatal(1,"STORE no conserva rs2/direccion");checks++;
        // Reset debe ocultar las salidas incluso con habilitaciones externas activas.
        rst=1;#1;if(da!==0 || wd!==0)$fatal(1,"Datos activos durante reset");rst=0;
        access_mem=0;store=0;#1;if(da!==0 || wd!==0)$fatal(1,"Datos activos fuera de acceso");
        prepare(enc_i(4,20,2,4,'h03));exe=1;tick();@(negedge clk);exe=0;data_in=32'hdeadbeef;ld=1;
        tick();@(negedge clk);ld=0;rf=1;tick();
        if(dut.registers.registers[4]!==32'hdeadbeef)$fatal(1,"Retorno de carga");checks++;
        @(negedge clk);rf=0;
        prepare(enc_s(2,3,20));if(execok)$fatal(1,"Acepta STORE desalineado");checks++;
        prepare(enc_b(2,1,0,0));if(!execok)$fatal(1,"Valida destino de branch no tomado");checks++;
        prepare(enc_b(2,0,0,0));if(execok)$fatal(1,"Acepta branch tomado desalineado");checks++;
        // Sin pc_en, ni una nueva entrada de programa ni el reloj deben mover el PC.
        prog_in=32'hffffffff;repeat(3)tick();if(pa!==16)$fatal(1,"PC cambia sin habilitacion");
        @(negedge clk);rst=1;ir=1;exe=1;rf=1;pc=1;tick();
        if(pa!==0 || ins!==0 || !pcok)$fatal(1,"Prioridad de reset en datapath");
        $display("PASS cpu_datapath_tb: %0d casos y reset/retencion",checks);$finish;
    end
    initial begin #10000;$fatal(1,"TIMEOUT cpu_datapath_tb");end
endmodule
