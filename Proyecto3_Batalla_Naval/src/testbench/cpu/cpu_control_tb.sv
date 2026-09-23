`timescale 1ns/1ps
module cpu_control_tb;
    import cpu_pkg::*;
    logic clk=0,rst=1,legal=1,pcok=1,execok=1;
    logic[2:0] kind=0;
    logic ir,oper,exe,ld,pc,rf,access_mem,store,fault;
    integer checks=0;
    always #5 clk=~clk;
    cpu_control dut(.clk_i(clk),.rst_i(rst),.legal_i(legal),.pc_valid_i(pcok),.execute_valid_i(execok),
      .kind_i(kind),.ir_en_o(ir),.operands_en_o(oper),.execute_en_o(exe),.load_en_o(ld),
      .pc_en_o(pc),.rf_we_o(rf),.mem_access_o(access_mem),.store_o(store),.fault_o(fault));
    task automatic tick; @(posedge clk);#1;endtask
    task automatic expect_state(input integer state,input logic[7:0] enables);
        if(dut.state_q!==state[3:0] || {ir,oper,exe,ld,pc,rf,access_mem,store}!==enables)
            $fatal(1,"Control estado esperado=%0d real=%0d habilitaciones=%b",state,dut.state_q,{ir,oper,exe,ld,pc,rf,access_mem,store});
        checks++;
    endtask
    task automatic reset_cpu;
        @(negedge clk);rst=1;#1;
        if({ir,oper,exe,ld,pc,rf,access_mem,store}!==0)$fatal(1,"Reset no inhibe salidas");
        tick();@(negedge clk);rst=0;legal=1;pcok=1;execok=1;#1;
        expect_state(FETCH_REQ,0);if(fault)$fatal(1,"Reset no limpia FAULT");
    endtask
    task automatic reach_execute;
        tick();expect_state(FETCH_CAPTURE,8'h80);
        tick();expect_state(DECODE,8'h40);tick();expect_state(EXECUTE,8'h20);
    endtask
    initial begin
        for(integer k=0;k<6;k++) begin
            reset_cpu();kind=k;reach_execute();tick();
            case(k)
                K_LOAD:begin expect_state(LOAD_REQ,8'h02);tick();expect_state(LOAD_CAPTURE,8'h12);tick();expect_state(WRITEBACK,8'h04);tick();end
                K_STORE:begin expect_state(STORE,8'h03);tick();end
                K_BRANCH:begin end
                default:begin expect_state(WRITEBACK,8'h04);tick();end
            endcase
            expect_state(COMMIT,8'h08);tick();expect_state(FETCH_REQ,0);
        end
        reset_cpu();pcok=0;tick();expect_state(FAULT,0);
        repeat(3)begin tick();expect_state(FAULT,0);end
        reset_cpu();tick();legal=0;tick();tick();expect_state(FAULT,0);
        reset_cpu();reach_execute();execok=0;#1;tick();expect_state(FAULT,0);
        // Reinicio desde cada estado alcanzable, incluida una escritura pendiente.
        for(integer target=0;target<10;target++)begin
            reset_cpu();kind=(target==STORE)?K_STORE:K_LOAD;
            if(target==FAULT)pcok=0;
            while(dut.state_q!=target)tick();
            reset_cpu();
        end
        $display("PASS cpu_control_tb: %0d comprobaciones",checks);$finish;
    end
    initial begin #20000;$fatal(1,"TIMEOUT cpu_control_tb");end
endmodule
