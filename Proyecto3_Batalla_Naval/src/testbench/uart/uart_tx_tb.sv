`timescale 1ns/1ps
module uart_tx_tb;
    localparam int CLK_FREQ_HZ = 100_000_000;
    localparam int BAUD_RATE   = 115_200;
    localparam int CLKS_PER_BIT = (CLK_FREQ_HZ + BAUD_RATE/2)/BAUD_RATE;
    localparam time CLK_PERIOD = 10ns;
    localparam time BIT_PERIOD = CLKS_PER_BIT * CLK_PERIOD;

    logic clk=0,rst=1,start=0;
    logic [7:0] data=0;
    logic tx,ready;
    integer errors=0;

    always #(CLK_PERIOD/2) clk=~clk;

    uart_tx dut(
        .clk_i(clk),.rst_i(rst),.start_i(start),.data_i(data),
        .tx_o(tx),.ready_o(ready)
    );

    task automatic check(input logic condition,input string message);
        if(!condition)begin errors++;$error("%s",message);end
    endtask

    task automatic check_byte(input logic [7:0] value);
        integer index;
        wait(ready);
        @(negedge clk);data=value;start=1;
        @(posedge clk);#1;
        check(!ready,"ready no baja al iniciar");
        fork
            begin @(negedge clk);start=0;end
        join_none

        #(BIT_PERIOD/2-1ns);
        check(tx===1'b0,"bit de inicio incorrecto");
        for(index=0;index<8;index++)begin
            #BIT_PERIOD;
            check(tx===value[index],$sformatf("dato bit %0d incorrecto",index));
            check(!ready,"ready se activo durante los datos");
        end
        #BIT_PERIOD;
        check(tx===1'b1,"bit de parada incorrecto");
        #(BIT_PERIOD/2+2ns);
        wait(ready);
        check(tx===1'b1,"TX no vuelve a reposo");
    endtask

    initial begin
        repeat(3)@(posedge clk);#1;
        check(tx===1'b1 && ready===1'b1,"salidas durante reset");
        @(negedge clk);rst=0;
        @(posedge clk);#1;
        check(tx===1'b1 && ready===1'b1,"reposo despues de reset");

        check_byte(8'h55);
        check_byte(8'hA5);
        check_byte(8'h00);
        check_byte(8'hFF);

        if(errors==0)$display("uart_tx_tb: ALL TESTS PASSED");
        else $fatal(1,"uart_tx_tb: %0d errores",errors);
        $finish;
    end

    initial begin #1ms;$fatal(1,"TIMEOUT uart_tx_tb");end
endmodule
