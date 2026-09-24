`timescale 1ns/1ps
module sevenseg_peripheral_tb;
    logic clk=0,rst=1,write_enable=0;
    logic [1:0] addr=0;
    logic [31:0] wdata=0,rdata;
    logic [6:0] seg;
    logic [3:0] an;
    integer checks=0,errors=0;

    always #5 clk=~clk;

    sevenseg_peripheral #(.CLK_FREQ_HZ(40),.FRAME_REFRESH_HZ(10)) dut(
        .clk_i(clk),.rst_i(rst),.write_enable_i(write_enable),.addr_i(addr),
        .wdata_i(wdata),.rdata_o(rdata),.seg_o(seg),.an_o(an)
    );

    function automatic logic [6:0] expected_seg(input logic [3:0] digit);
        case(digit)
            0:expected_seg=7'b1000000;1:expected_seg=7'b1111001;
            2:expected_seg=7'b0100100;3:expected_seg=7'b0110000;
            4:expected_seg=7'b0011001;5:expected_seg=7'b0010010;
            6:expected_seg=7'b0000010;7:expected_seg=7'b1111000;
            8:expected_seg=7'b0000000;9:expected_seg=7'b0010000;
            default:expected_seg=7'b1111111;
        endcase
    endfunction

    task automatic check(input logic condition,input string test_name);
        if(!condition)begin errors++;$error("%s",test_name);end else checks++;
    endtask

    task automatic write_score(input logic [7:0] j1,input logic [7:0] j2);
        @(negedge clk);addr=0;wdata={16'b0,j2,j1};write_enable=1;
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

    task automatic check_scan(
        input logic [3:0] j1_tens,input logic [3:0] j1_units,
        input logic [3:0] j2_tens,input logic [3:0] j2_units
    );
        logic [3:0] seen;
        logic [3:0] expected_digit;
        seen=0;
        repeat(8)begin
            @(posedge clk);#1;
            case(an)
                4'b1110:begin seen[0]=1;expected_digit=j2_units;end
                4'b1101:begin seen[1]=1;expected_digit=j2_tens;end
                4'b1011:begin seen[2]=1;expected_digit=j1_units;end
                4'b0111:begin seen[3]=1;expected_digit=j1_tens;end
                default:begin expected_digit=4'hF;errors++;$error("anodo invalido %b",an);end
            endcase
            check(seg===expected_seg(expected_digit),"patron de segmentos incorrecto");
        end
        check(seen==4'b1111,"no se multiplexaron los cuatro digitos");
    endtask

    initial begin
        repeat(2)@(posedge clk);#1;
        check(rdata===32'h00000000,"reset no limpia marcador");
        @(negedge clk);rst=0;

        write_score(8'd12,8'd34);
        check_sync_read(2'b00,32'h00000000,32'h0000220C,"lectura MMIO 12 34");
        check_scan(4'd1,4'd2,4'd3,4'd4);

        check_sync_read(2'b11,32'h0000220C,32'h00000000,"direccion reservada");
        check_sync_read(2'b00,32'h00000000,32'h0000220C,"regreso a marcador");

        @(negedge clk);wdata=32'h00005678;write_enable=0;
        @(posedge clk);#1;
        check(rdata===32'h0000220C,"write_enable cero modifico marcador");

        write_score(8'd5,8'd6);
        check_sync_read(2'b00,32'h0000220C,32'h00000605,"nueva escritura");

        write_score(8'd99,8'd99);
        check_sync_read(2'b00,32'h00000605,32'h00006363,"lectura MMIO 99 99");
        check_scan(4'd9,4'd9,4'd9,4'd9);

        write_score(8'd100,8'd255);
        check_sync_read(2'b00,32'h00006363,32'h0000FF64,
                        "lectura conserva valores mayores que 99");
        check_scan(4'd9,4'd9,4'd9,4'd9);

        if(errors==0)$display("sevenseg_peripheral_tb: ALL TESTS PASSED");
        else $fatal(1,"sevenseg_peripheral_tb: %0d errores en %0d checks",errors,checks);
        $finish;
    end

    initial begin #5000;$fatal(1,"TIMEOUT sevenseg_peripheral_tb");end
endmodule
