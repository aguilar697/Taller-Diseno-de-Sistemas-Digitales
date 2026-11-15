// Bus maestro de prueba: admite separación de AW/W y espera en B/R.
logic clk=0, aresetn=0;
always #5 clk=~clk;
logic [5:0] awaddr=0, araddr=0;
logic [31:0] wdata=0, rdata;
logic [3:0] wstrb=0;
logic awvalid=0, awready, wvalid=0, wready, bvalid, bready=0;
logic arvalid=0, arready, rvalid, rready=0;
logic [1:0] bresp, rresp;
logic ah, al, bh, bl, trigger_adc, period_start;
integer checks=0;

pwm_system_axi dut (
    .s_axi_aclk(clk), .s_axi_aresetn(aresetn),
    .s_axi_awaddr(awaddr), .s_axi_awprot(3'b0),
    .s_axi_awvalid(awvalid), .s_axi_awready(awready),
    .s_axi_wdata(wdata), .s_axi_wstrb(wstrb), .s_axi_wvalid(wvalid), .s_axi_wready(wready),
    .s_axi_bresp(bresp), .s_axi_bvalid(bvalid), .s_axi_bready(bready),
    .s_axi_araddr(araddr), .s_axi_arprot(3'b0), .s_axi_arvalid(arvalid), .s_axi_arready(arready),
    .s_axi_rdata(rdata), .s_axi_rresp(rresp), .s_axi_rvalid(rvalid), .s_axi_rready(rready),
    .pwm_ah(ah), .pwm_al(al), .pwm_bh(bh), .pwm_bl(bl),
    .pwm_trigger_o(trigger_adc), .pwm_period_start_o(period_start)
);

task automatic check(input logic condition, input string message);
    begin
        if (condition !== 1'b1) $fatal(1,"CHECK_FAILED: %s",message);
        checks=checks+1;
    end
endtask

task automatic tick;
    begin @(posedge clk); #1; end
endtask

task automatic reset_dut;
    begin
        @(negedge clk); aresetn=0;
        awvalid=0; wvalid=0; arvalid=0; bready=0; rready=0;
        repeat(3) tick();
        check({ah,al,bh,bl,trigger_adc,period_start}===6'b0,"salidas durante reset");
        @(negedge clk); aresetn=1;
        tick();
    end
endtask

task automatic send_aw(input logic [5:0] address, input integer delay_clocks);
    integer timeout;
    begin
        repeat(delay_clocks) @(posedge clk);
        @(negedge clk); awaddr=address; awvalid=1;
        timeout=0;
        @(posedge clk);
        while (!awready && timeout<100) begin @(posedge clk); timeout=timeout+1; end
        check(awready,"timeout AW");
        @(negedge clk); awvalid=0;
    end
endtask

task automatic send_w(input logic [31:0] value, input logic [3:0] bytes,
                       input integer delay_clocks);
    integer timeout;
    begin
        repeat(delay_clocks) @(posedge clk);
        @(negedge clk); wdata=value; wstrb=bytes; wvalid=1;
        timeout=0;
        @(posedge clk);
        while (!wready && timeout<100) begin @(posedge clk); timeout=timeout+1; end
        check(wready,"timeout W");
        @(negedge clk); wvalid=0;
    end
endtask

task automatic response_b(input logic [1:0] expected, input integer hold_clocks);
    integer timeout;
    begin
        timeout=0;
        while (!bvalid && timeout<100) begin tick(); timeout=timeout+1; end
        check(bvalid && bresp===expected,"respuesta de escritura");
        repeat(hold_clocks) begin
            tick();
            check(bvalid && bresp===expected,"B estable bajo espera");
            check(!awready && !wready,"no aceptar otra escritura con B pendiente");
        end
        @(negedge clk); bready=1;
        @(posedge clk);
        @(negedge clk); bready=0;
        tick();
        check(!bvalid,"respuesta B consumida una sola vez");
    end
endtask

task automatic write_reg(input logic [5:0] address, input logic [31:0] value,
    input logic [3:0] bytes, input logic [1:0] expected,
    input integer aw_delay, input integer w_delay, input integer hold_clocks);
    begin
        fork
            send_aw(address,aw_delay);
            send_w(value,bytes,w_delay);
        join
        response_b(expected,hold_clocks);
    end
endtask

task automatic read_reg(input logic [5:0] address, input logic [31:0] expected,
    input logic [1:0] response, input integer hold_clocks);
    integer timeout;
    begin
        @(negedge clk); araddr=address; arvalid=1;
        timeout=0;
        @(posedge clk);
        while(!arready && timeout<100) begin @(posedge clk); timeout=timeout+1; end
        check(arready,"timeout AR");
        @(negedge clk); arvalid=0;
        timeout=0;
        while(!rvalid && timeout<100) begin tick(); timeout=timeout+1; end
        check(rvalid && rresp===response && rdata===expected,"respuesta de lectura");
        repeat(hold_clocks) begin
            tick();
            check(rvalid && rresp===response && rdata===expected,"R estable bajo espera");
        end
        @(negedge clk); rready=1;
        @(posedge clk);
        @(negedge clk); rready=0;
    end
endtask

// Se vigila incluso cuando el programa de estímulos espera una transacción AXI.
always @(posedge clk) begin
    #2;
    if (aresetn) begin
        if ((ah && al) || (bh && bl)) $fatal(1,"PWM_OVERLAP_DETECTED");
        if ((^{ah,al,bh,bl,trigger_adc,period_start})===1'bx)
            $fatal(1,"PWM_UNKNOWN_DETECTED");
    end
end

initial begin
    #50000000;
    $fatal(1,"TEST_TIMEOUT");
end
