`timescale 1ns/1ps
module address_decoder_tb;
    logic [31:0] addr=0;
    logic ram_sel,uart_sel,input_sel,sevenseg_sel,led_sel,buzzer_sel,vga_sel;
    logic [9:0] ram_addr;
    logic [1:0] uart_addr,input_addr,sevenseg_addr,led_addr,buzzer_addr;
    logic [8:0] vga_addr;
    integer checks=0,errors=0;

    address_decoder dut(
        .addr_i(addr),.ram_sel_o(ram_sel),.uart_sel_o(uart_sel),
        .input_sel_o(input_sel),.sevenseg_sel_o(sevenseg_sel),
        .led_sel_o(led_sel),.buzzer_sel_o(buzzer_sel),.vga_sel_o(vga_sel),
        .ram_addr_o(ram_addr),.uart_addr_o(uart_addr),.input_addr_o(input_addr),
        .sevenseg_addr_o(sevenseg_addr),.led_addr_o(led_addr),
        .buzzer_addr_o(buzzer_addr),.vga_addr_o(vga_addr)
    );

    task automatic check_decode(
        input logic [31:0] address,
        input logic [6:0] expected_selects,
        input logic [9:0] expected_ram_addr,
        input logic [1:0] expected_uart_addr,
        input logic [8:0] expected_vga_addr,
        input string test_name
    );
        logic [6:0] selects;
        addr=address;#1;
        selects={vga_sel,buzzer_sel,led_sel,sevenseg_sel,input_sel,uart_sel,ram_sel};
        if(selects!==expected_selects)begin
            errors++;$error("%s: selects=%b expected=%b",test_name,selects,expected_selects);
        end else checks++;
        if(ram_addr!==expected_ram_addr)begin
            errors++;$error("%s: ram_addr=%0d expected=%0d",test_name,ram_addr,expected_ram_addr);
        end else checks++;
        if(uart_addr!==expected_uart_addr)begin
            errors++;$error("%s: uart_addr=%b expected=%b",test_name,uart_addr,expected_uart_addr);
        end else checks++;
        if(vga_addr!==expected_vga_addr)begin
            errors++;$error("%s: vga_addr=%0d expected=%0d",test_name,vga_addr,expected_vga_addr);
        end else checks++;
        if(input_addr!==0 || sevenseg_addr!==0 || led_addr!==0 || buzzer_addr!==0)begin
            errors++;$error("%s: una direccion local fija no es cero",test_name);
        end else checks++;
    endtask

    initial begin
        check_decode(32'h00002000,7'b0000001,10'd0,2'b00,9'd0,"inicio RAM");
        check_decode(32'h00002FFF,7'b0000001,10'd1023,2'b00,9'd0,"final RAM");
        check_decode(32'h00003000,7'b0000000,10'd0,2'b00,9'd0,"fuera RAM");
        check_decode(32'h00010040,7'b0000010,10'd0,2'b00,9'd0,"UART control");
        check_decode(32'h00010044,7'b0000010,10'd0,2'b01,9'd0,"UART TX");
        check_decode(32'h00010048,7'b0000010,10'd0,2'b10,9'd0,"UART RX");
        check_decode(32'h0001004C,7'b0000000,10'd0,2'b00,9'd0,"UART invalida");
        check_decode(32'h00010120,7'b0000100,10'd0,2'b00,9'd0,"inputs");
        check_decode(32'h00010130,7'b0001000,10'd0,2'b00,9'd0,"sevenseg");
        check_decode(32'h00010138,7'b0010000,10'd0,2'b00,9'd0,"LED");
        check_decode(32'h00010140,7'b0100000,10'd0,2'b00,9'd0,"buzzer");
        check_decode(32'h00011000,7'b1000000,10'd0,2'b00,9'd0,"inicio VGA");
        check_decode(32'h000117FC,7'b1000000,10'd0,2'b00,9'd511,"final VGA");
        check_decode(32'h00011800,7'b0000000,10'd0,2'b00,9'd0,"fuera VGA");
        check_decode(32'h00000000,7'b0000000,10'd0,2'b00,9'd0,"direccion cero");
        check_decode(32'hDEADBEEF,7'b0000000,10'd0,2'b00,9'd0,"no mapeada");

        if(errors==0)$display("address_decoder_tb: ALL TESTS PASSED");
        else $fatal(1,"address_decoder_tb: %0d errores en %0d checks",errors,checks);
        $finish;
    end
endmodule
