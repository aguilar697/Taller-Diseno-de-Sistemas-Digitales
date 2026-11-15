// Infraestructura compartida de testbench, nunca fuente sintetizable.
localparam int ADDR_WIDTH = 6;
logic clk = 0;
always #5 clk = ~clk;
logic resetn = 0;
logic [ADDR_WIDTH-1:0] awaddr = 0, araddr = 0;
logic [2:0] awprot = 0, arprot = 0;
logic awvalid = 0, awready, wvalid = 0, wready;
logic [31:0] wdata = 0;
logic [3:0] wstrb = 0;
logic [1:0] bresp, rresp;
logic bvalid, bready = 0, arvalid = 0, arready, rvalid, rready = 0;
logic [31:0] rdata;
logic start_observed, ack_observed;
logic [31:0] ack_id_observed;
integer start_count = 0, ack_count = 0, aw_count = 0, w_count = 0, b_count = 0;
integer ar_count = 0, r_count = 0;
logic old_bstall = 0, old_rstall = 0;
logic [1:0] old_bresp, old_rresp;
logic [31:0] old_rdata;

// Comprobaciones sobre el bus en cada flanco de aceptación, no solo al final.
always @(posedge clk) begin
    if (resetn) begin
        if ($isunknown({awvalid,wvalid,arvalid,bready,rready,awready,wready,arready,bvalid,rvalid,start_observed,ack_observed}))
            $fatal(1, "UNKNOWN_BUS_DETECTED: handshake desconocido");
        if (awvalid && $isunknown({awaddr,awprot}))
            $fatal(1, "UNKNOWN_BUS_DETECTED: AW desconocido");
        if (wvalid && $isunknown({wdata,wstrb}))
            $fatal(1, "UNKNOWN_BUS_DETECTED: W desconocido");
        if (arvalid && $isunknown({araddr,arprot}))
            $fatal(1, "UNKNOWN_BUS_DETECTED: AR desconocido");
        if ((bvalid && $isunknown(bresp)) || (rvalid && $isunknown({rdata,rresp})))
            $fatal(1, "UNKNOWN_BUS_DETECTED: respuesta desconocida");
        if (ack_observed && $isunknown(ack_id_observed))
            $fatal(1,"UNKNOWN_BUS_DETECTED: token ACK desconocido");
        if (old_bstall && (!bvalid || bresp !== old_bresp))
            $fatal(1, "Respuesta B inestable bajo backpressure");
        if (old_rstall && (!rvalid || rdata !== old_rdata || rresp !== old_rresp))
            $fatal(1, "Respuesta R inestable bajo backpressure");
        if (start_observed) start_count = start_count + 1;
        if (ack_observed) ack_count = ack_count + 1;
        if (awvalid && awready) aw_count = aw_count + 1;
        if (wvalid && wready) w_count = w_count + 1;
        if (bvalid && bready) b_count = b_count + 1;
        if (arvalid && arready) ar_count = ar_count + 1;
        if (rvalid && rready) r_count = r_count + 1;
        old_bstall = bvalid && !bready;
        old_rstall = rvalid && !rready;
        old_bresp = bresp; old_rresp = rresp; old_rdata = rdata;
    end else begin
        old_bstall = 0; old_rstall = 0;
    end
end

// Reset de maestro/esclavo: una transacción cancelada no se reanuda con datos antiguos.
task automatic reset_bus;
    @(negedge clk);
    resetn = 0; awvalid = 0; wvalid = 0; arvalid = 0; bready = 0; rready = 0;
    repeat (4) @(negedge clk);
    if ({bvalid,rvalid,start_observed,ack_observed,awready,wready,arready} !== 7'b0 || rdata !== 0 || bresp !== 0 || rresp !== 0)
        $fatal(1, "Reset dejo respuestas o comandos activos");
    resetn = 1;
    @(negedge clk);
endtask

// AW y W se conducen por separado para ensayar cualquier orden de llegada.
task automatic send_aw(input logic [ADDR_WIDTH-1:0] addr, input integer delay_cycles);
    repeat (delay_cycles) @(negedge clk);
    @(negedge clk); awaddr = addr; awvalid = 1;
    do @(posedge clk); while (awready !== 1'b1);
    @(negedge clk); awvalid = 0;
endtask

task automatic send_w(input logic [31:0] data, input logic [3:0] strb, input integer delay_cycles);
    repeat (delay_cycles) @(negedge clk);
    @(negedge clk); wdata = data; wstrb = strb; wvalid = 1;
    do @(posedge clk); while (wready !== 1'b1);
    @(negedge clk); wvalid = 0;
endtask

// Ejecuta un write completo; BREADY permanece bajo durante la espera solicitada.
task automatic write_tx(input logic [ADDR_WIDTH-1:0] addr, input logic [31:0] data,
    input logic [3:0] strb, input integer aw_delay, input integer w_delay,
    input integer stall_cycles, input logic [1:0] expected_resp);
    fork
        send_aw(addr, aw_delay);
        send_w(data, strb, w_delay);
    join
    while (bvalid !== 1'b1) @(negedge clk);
    if (bresp !== expected_resp) $fatal(1, "BRESP incorrecta addr=%h resp=%h", addr,bresp);
    repeat (stall_cycles) begin
        @(negedge clk);
        if (bvalid !== 1'b1 || bresp !== expected_resp) $fatal(1,"B cambio durante espera");
    end
    @(negedge clk); bready = 1;
    @(negedge clk); bready = 0;
endtask

// Acepta AR dejando la respuesta pendiente para poder comprobar concurrencia.
task automatic begin_read(input logic [ADDR_WIDTH-1:0] addr);
    @(negedge clk); araddr = addr; arvalid = 1;
    do @(posedge clk); while (arready !== 1'b1);
    @(negedge clk); arvalid = 0;
    while (rvalid !== 1'b1) @(negedge clk);
endtask

// Consume la instantánea solo después de verificar estabilidad durante backpressure.
task automatic read_tx(input logic [ADDR_WIDTH-1:0] addr,
    input logic [1:0] expected_resp, input integer stall_cycles, output logic [31:0] result);
    logic [31:0] held;
    begin_read(addr);
    held = rdata;
    if (rresp !== expected_resp || $isunknown(rdata)) $fatal(1,"Lectura invalida addr=%h",addr);
    repeat (stall_cycles) begin
        @(negedge clk);
        if (rdata !== held || rresp !== expected_resp || rvalid !== 1'b1)
            $fatal(1,"R cambio durante espera");
    end
    result = rdata;
    @(negedge clk); rready = 1;
    @(negedge clk); rready = 0;
endtask

initial begin
    #2000000;
    $fatal(1,"Watchdog global del testbench AXI");
end
