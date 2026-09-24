`timescale 1ns/1ps
module uart_peripheral_tb;
    localparam int CLK_FREQ_HZ = 100_000_000;
    localparam int BAUD_RATE   = 115_200;
    localparam int CLKS_PER_BIT = (CLK_FREQ_HZ + BAUD_RATE/2)/BAUD_RATE;
    localparam time CLK_PERIOD = 10ns;
    localparam time BIT_PERIOD = CLKS_PER_BIT * CLK_PERIOD;

    logic clk=0,rst=1,write_enable=0;
    logic [1:0] addr=0;
    logic [31:0] wdata=0,rdata;
    logic uart_rx=1,uart_tx;
    integer errors=0;

    always #(CLK_PERIOD/2) clk=~clk;

    uart_peripheral dut(
        .clk_i(clk),.rst_i(rst),.write_enable_i(write_enable),
        .addr_i(addr),.wdata_i(wdata),.rdata_o(rdata),
        .uart_rx_i(uart_rx),.uart_tx_o(uart_tx)
    );

    task automatic check(input logic condition,input string message);
        if(!condition)begin errors++;$error("%s",message);end
    endtask

    task automatic mmio_write(input logic [1:0] address,input logic [31:0] value);
        @(negedge clk);addr=address;wdata=value;write_enable=1;
        @(posedge clk);#1;
        @(negedge clk);write_enable=0;
    endtask

    task automatic check_sync_read(
        input logic [1:0] address,input logic [31:0] previous_value,
        input logic [31:0] expected_value,input string test_name
    );
        addr=address;#1;
        check(rdata===previous_value,{test_name," cambio antes del flanco"});
        @(posedge clk);#1;
        check(rdata===expected_value,{test_name," valor despues del flanco"});
    endtask

    task automatic drive_rx_byte(input logic [7:0] value);
        integer index;
        uart_rx=0;#BIT_PERIOD;
        for(index=0;index<8;index++)begin
            uart_rx=value[index];#BIT_PERIOD;
        end
        uart_rx=1;#BIT_PERIOD;
    endtask

    task automatic check_tx_byte(input logic [7:0] value);
        integer index;
        wait(uart_tx==0);
        #(BIT_PERIOD/2);
        check(uart_tx===1'b0,"TX start incorrecto");
        for(index=0;index<8;index++)begin
            #BIT_PERIOD;
            check(uart_tx===value[index],$sformatf("TX bit %0d incorrecto",index));
        end
        #BIT_PERIOD;
        check(uart_tx===1'b1,"TX stop incorrecto");
    endtask

    initial begin
        repeat(3)@(posedge clk);#1;
        check(rdata===32'b0,"rdata durante reset");
        check(uart_tx===1'b1,"TX no esta en reposo durante reset");
        @(negedge clk);rst=0;
        check_sync_read(2'b00,32'h00000000,32'h00000001,
                        "CONTROL despues de reset");

        fork
            check_tx_byte(8'h55);
            begin
                mmio_write(2'b01,32'h00000055);
                check_sync_read(2'b00,32'h00000000,32'h00000000,
                                "CONTROL durante TX");
                wait(rdata[0]===1'b1);
            end
        join

        fork
            check_tx_byte(8'hA5);
            begin
                mmio_write(2'b01,32'h000000A5);
                check_sync_read(2'b00,32'h00000055,32'h00000000,
                                "CONTROL segunda TX");
                mmio_write(2'b01,32'h000000FF);
                addr=2'b00;
                wait(rdata[0]===1'b1);
                #BIT_PERIOD;
                check(uart_tx===1'b1,"escritura con TX ocupado inicio otra trama");
            end
        join

        drive_rx_byte(8'h3C);
        addr=2'b00;
        wait(rdata[1]===1'b1);
        check_sync_read(2'b10,32'h00000003,32'h0000003C,
                        "CONTROL a RX_DATA");
        check_sync_read(2'b00,32'h0000003C,32'h00000003,
                        "RX_DATA a CONTROL");

        mmio_write(2'b10,32'h00000099);
        check_sync_read(2'b10,32'h0000003C,32'h0000003C,
                        "escritura ignorada en RX_DATA");

        check_sync_read(2'b00,32'h0000003C,32'h00000003,
                        "lectura RX_DATA no limpia rx_valid");
        mmio_write(2'b00,32'h00000002);
        check_sync_read(2'b00,32'h00000003,32'h00000001,
                        "W1C limpia rx_valid");

        mmio_write(2'b11,32'hFFFFFFFF);
        check(rdata===32'h00000000,"direccion reservada no devuelve cero");
        check_sync_read(2'b00,32'h00000000,32'h00000001,
                        "escritura reservada no modifica status");

        if(errors==0)$display("uart_peripheral_tb: ALL TESTS PASSED");
        else $fatal(1,"uart_peripheral_tb: %0d errores",errors);
        $finish;
    end

    initial begin #2ms;$fatal(1,"TIMEOUT uart_peripheral_tb");end
endmodule
