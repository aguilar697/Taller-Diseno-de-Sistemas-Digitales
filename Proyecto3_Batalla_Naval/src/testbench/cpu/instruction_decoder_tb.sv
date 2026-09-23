`timescale 1ns/1ps
module instruction_decoder_tb;
    logic[31:0] ins;
    logic legal,bs;
    logic[2:0] kind,fmt;
    logic[3:0] op;
    logic[1:0] asel,wb;
    logic el,eb;
    integer ek,ef,eo,ea,ew,checks=0;
    instruction_decoder dut(.instruction_i(ins),.legal_o(legal),.kind_o(kind),.imm_format_o(fmt),
        .alu_op_o(op),.alu_a_sel_o(asel),.result_sel_o(wb),.alu_b_sel_o(bs));
    // Recorre todas las combinaciones de campos de decodificacion, incluidas extensiones no soportadas.
    initial begin
        for(integer opc=0;opc<128;opc++)
        for(integer f3=0;f3<8;f3++)
        for(integer f7=0;f7<128;f7++) begin
            ins={f7[6:0],5'd7,5'd5,f3[2:0],5'd3,opc[6:0]};
            el=0;eb=0;ek=0;ef=0;eo=0;ea=0;ew=0;
            if(opc=='h33 || opc=='h13)begin
                eb=(opc=='h13);
                case(f3)
                    0:eo=(opc=='h33 && f7==32)?1:0;
                    1:eo=5;2:eo=8;3:eo=9;4:eo=4;
                    5:eo=(f7==32)?7:6;6:eo=3;7:eo=2;
                endcase
                if(opc=='h33)el=(f7==0 || (f7==32 && (f3==0 || f3==5)));
                else el=((f3!=1 && f3!=5) || (f7==0) || (f3==5 && f7==32));
            end
            if(opc=='h03)begin el=(f3==2);ek=1;eb=1;ew=1;end
            if(opc=='h23)begin el=(f3==2);ek=2;eb=1;ef=1;end
            if(opc=='h63)begin el=(f3==0 || f3==1 || f3==4 || f3==5);ek=3;ef=2;end
            if(opc=='h6f)begin el=1;ek=4;ef=4;ew=2;end
            if(opc=='h67)begin el=(f3==0);ek=5;eb=1;ew=2;end
            if(opc=='h37 || opc=='h17)begin el=1;ef=3;ea=(opc=='h37)?2:1;eb=1;end
            if(!el)begin ek=0;ef=0;eo=0;ea=0;eb=0;ew=0;end
            #1;
            if(legal!==el || kind!==ek[2:0] || fmt!==ef[2:0] || op!==eo[3:0] ||
               asel!==ea[1:0] || bs!==eb || wb!==ew[1:0])$fatal(1,"Decoder ins=%h",ins);
            checks++;
        end
        $display("PASS instruction_decoder_tb: %0d codificaciones",checks);$finish;
    end
    initial begin #200000;$fatal(1,"TIMEOUT instruction_decoder_tb");end
endmodule
