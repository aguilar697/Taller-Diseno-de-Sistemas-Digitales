`timescale 1ns/1ps
module uart_rx_tb;
    localparam int CLK_FREQ_HZ = 100_000_000;
    localparam int BAUD_RATE   = 115_200;
    localparam int CLKS_PER_BIT = (CLK_FREQ_HZ + BAUD_RATE/2)/BAUD_RATE;
    localparam time CLK_PERIOD = 10ns;
    localparam time BIT_PERIOD = CLKS_PER_BIT * CLK_PERIOD;

    logic clk=0,rst=1,rx=1;
    logic [7:0] data;
    logic valid;
    integer errors=0,valid_count=0;

    always #(CLK_PERIOD/2) clk=~clk;

    uart_rx dut(
        .clk_i(clk),.rst_i(rst),.rx_i(rx),.data_o(data),.valid_o(valid)
    );

    always @(posedge clk) begin
        if(!rst && valid)valid_count++;
    end

    task automatic check(input logic condition,input string message);
        if(!condition)begin errors++;$error("%s",message);end
    endtask

    task automatic drive_byte(input logic [7:0] value);
        integer index;
        rx=0;#BIT_PERIOD;
        for(index=0;index<8;index++)begin
            rx=value[index];#BIT_PERIOD;
        end
        rx=1;#BIT_PERIOD;
    endtask

    task automatic send_and_check(input logic [7:0] value);
        integer previous_count;
        previous_count=valid_count;
        fork
            drive_byte(value);
            begin
                wait(valid);
                #1;
                check(data===value,$sformatf("byte recibido incorrecto: %h",value));
                @(posedge clk);#1;
                check(!valid,"valid debe durar un ciclo");
            end
        join
        check(valid_count==previous_count+1,"cantidad de pulsos valid incorrecta");
        #BIT_PERIOD;
    endtask

    initial begin
        repeat(3)@(posedge clk);#1;
        check(data===8'h00 && valid===1'b0,"reset incorrecto");
        @(negedge clk);rst=0;
        #BIT_PERIOD;

        send_and_check(8'h55);
        send_and_check(8'hA5);
        send_and_check(8'h00);
        send_and_check(8'hFF);

        if(errors==0)$display("uart_rx_tb: ALL TESTS PASSED");
        else $fatal(1,"uart_rx_tb: %0d errores",errors);
        $finish;
    end

    initial begin #1ms;$fatal(1,"TIMEOUT uart_rx_tb");end
endmodule
