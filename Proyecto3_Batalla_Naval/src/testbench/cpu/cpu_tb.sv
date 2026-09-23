`timescale 1ns/1ps
// Prueba del nucleo con ROM real y modelo sincrono de la plataforma de datos.
// El modelo arquitectonico avanza al completar una instruccion, sin reproducir la FSM.
module cpu_tb;
    import cpu_pkg::*; import cpu_tb_pkg::*;
    logic clk=0,rst=1;
    logic[31:0] pa,pi,da,wd,di=0;logic we;
    logic[31:0] ram[0:1023], reference_ram[0:1023], reference_regs[0:31];
    logic[31:0] reference_pc, last_store_addr, last_store_data;
    integer writes=0,reference_writes=0,retired=0,programs=0,cycles=0,cursor=0;
    integer seed=32'h3100922;
    logic[28:0] coverage=0;
    cpu dut(.clk_i(clk),.rst_i(rst),.ProgAddress_o(pa),.ProgIn_i(pi),
        .DataAddress_o(da),.DataOut_o(wd),.DataIn_i(di),.we_o(we));
    program_rom rom(.clk_i(clk),.addr_i(pa),.rdata_o(pi));
    always #5 clk=~clk;
    // No hay efectos por lectura. El registro MMIO de prueba devuelve una constante.
    always @(posedge clk) begin
        if(da[31:12]==20'h00002)di<=ram[da[11:2]];
        else if(da==32'h10040)di<=32'h51;
        else di<=0;
        if(we)begin
            if(rst || da[1:0]!=0)$fatal(1,"Escritura externa invalida");
            writes=writes+1;last_store_addr=da;last_store_data=wd;
            if(da[31:12]==20'h00002)ram[da[11:2]]=wd;
        end
    end
    task automatic fresh;
        @(negedge clk);rst=1;
        for(integer n=0;n<2048;n++)rom.memory[n]=0; // Sentinela ilegal tras el programa.
        for(integer n=0;n<1024;n++)begin ram[n]=32'h10000000+n;reference_ram[n]=ram[n];end
        for(integer n=0;n<32;n++)reference_regs[n]=0;
        reference_pc=0;writes=0;reference_writes=0;cursor=0;cycles=0;
        repeat(2)@(negedge clk);
    endtask
    task automatic emit(input logic[31:0] instruction);
        rom.memory[cursor]=instruction;cursor++;
    endtask
    task automatic check_commit;
        logic[31:0] inst,a,b,value,next_address,address;
        integer opcode,f3,f7,rd,rs1,rs2,imm,expected_cycles,idx;
        logic write_rd,taken;
        inst=rom.memory[reference_pc/4];opcode=inst[6:0];f3=inst[14:12];f7=inst[31:25];
        rd=inst[11:7];rs1=inst[19:15];rs2=inst[24:20];a=reference_regs[rs1];b=reference_regs[rs2];
        imm=$signed(inst)>>>20;next_address=reference_pc+4;write_rd=1;value=0;expected_cycles=6;
        case(opcode)
            'h33:begin
                case(f3)
                    0:begin value=(f7==32)?a-b:a+b;idx=(f7==32)?8:0;end
                    1:begin value=a<<(b%32);idx=1;end
                    2:begin value=($signed(a)<$signed(b));idx=2;end
                    3:begin value=(a<b);idx=3;end
                    4:begin value=a^b;idx=4;end
                    5:begin if(f7==32)value=$signed(a)>>>(b%32);else value=a>>(b%32);idx=(f7==32)?9:5;end
                    6:begin value=a|b;idx=6;end
                    7:begin value=a&b;idx=7;end
                endcase
                coverage[idx]=1;
            end
            'h13:begin
                idx=10+f3;
                case(f3)
                    0:value=a+imm;1:value=a<<rs2;2:value=($signed(a)<imm);
                    3:value=(a<$unsigned(imm));4:value=a^imm;
                    5:begin if(f7==32)value=$signed(a)>>>rs2;else value=a>>rs2;if(f7==32)idx=18;end
                    6:value=a|imm;7:value=a&imm;
                endcase
                coverage[idx]=1;
            end
            'h37:begin value=inst & 32'hfffff000;coverage[19]=1;end
            'h17:begin value=reference_pc+(inst & 32'hfffff000);coverage[20]=1;end
            'h03:begin
                address=a+imm;expected_cycles=8;coverage[21]=1;
                if(address[31:12]==20'h00002)value=reference_ram[(address-'h2000)/4];
                else if(address=='h10040)value='h51;else value=0;
            end
            'h23:begin
                imm=($signed(inst)>>>25)*32+rd;address=a+imm;write_rd=0;coverage[22]=1;
                reference_writes++;
                if(last_store_addr!==address || last_store_data!==b)$fatal(1,"STORE difiere PC=%h",reference_pc);
                if(address[31:12]==20'h00002)begin
                    reference_ram[(address-'h2000)/4]=b;
                    if(ram[(address-'h2000)/4]!==b)$fatal(1,"RAM no actualizada");
                end
            end
            'h63:begin
                imm=(inst[31]?-4096:0)+inst[7]*2048+inst[30:25]*32+inst[11:8]*2;
                write_rd=0;expected_cycles=5;
                case(f3)
                    0:begin taken=(a==b);coverage[23]=1;end
                    1:begin taken=(a!=b);coverage[24]=1;end
                    4:begin taken=($signed(a)<$signed(b));coverage[25]=1;end
                    5:begin taken=($signed(a)>=$signed(b));coverage[26]=1;end
                    default:$fatal(1,"Branch no soportado en referencia");
                endcase
                if(taken)next_address=reference_pc+imm;
            end
            'h6f:begin
                imm=(inst[31]?-1048576:0)+inst[19:12]*4096+inst[20]*2048+inst[30:21]*2;
                value=reference_pc+4;next_address=reference_pc+imm;coverage[27]=1;
            end
            'h67:begin value=reference_pc+4;next_address=(a+imm)&32'hfffffffe;coverage[28]=1;end
            default:$fatal(1,"Retiro de instruccion ilegal PC=%h",reference_pc);
        endcase
        if(cycles!=expected_cycles)$fatal(1,"Latencia PC=%h got=%0d expected=%0d",reference_pc,cycles,expected_cycles);
        if(write_rd && rd!=0)reference_regs[rd]=value;
        if(writes!=reference_writes)$fatal(1,"Escritura repetida o inesperada PC=%h",reference_pc);
        for(integer n=1;n<32;n++)
            if(dut.datapath.registers.registers[n]!==reference_regs[n])
                $fatal(1,"Registro x%0d PC=%h got=%h expected=%h",n,reference_pc,dut.datapath.registers.registers[n],reference_regs[n]);
        reference_pc=next_address;retired++;cycles=0;
    endtask
    task automatic run_program;
        integer clocks;logic committing;
        @(negedge clk);rst=0;clocks=0;
        while(!dut.fault && clocks<30000)begin
            @(posedge clk);clocks++;cycles++;committing=(dut.control.state_q==COMMIT);
            if(committing)check_commit();
            #1;
            if(committing && pa!==reference_pc)$fatal(1,"PC got=%h expected=%h",pa,reference_pc);
        end
        if(!dut.fault)$fatal(1,"Programa no termina por sentinela");
        if(writes!=reference_writes)$fatal(1,"Efecto lateral antes de FAULT");
        repeat(5)begin @(posedge clk);#1;if(we || pa!==reference_pc)$fatal(1,"FAULT no retiene estado");end
        programs++;
    endtask
    initial begin
        // Codificaciones conocidas: comprueba tambien los generadores del estimulo.
        if(enc_i(1,0,0,1)!==32'h00100093 || enc_s(0,1,2)!==32'h00112023 || enc_j(0,0)!==32'h0000006f)
            $fatal(1,"Codificador de estimulos incorrecto");
        fresh();emit(enc_i(-1,0,0,1));emit(enc_i(1,0,0,2));emit(enc_u(2,20));
        emit(enc_u('h80000,3));emit(enc_u('h12345,4,'h17));
        for(integer f=0;f<8;f++)emit(enc_r(0,2,1,f,5));
        emit(enc_r(32,2,1,0,6));emit(enc_r(32,2,3,5,7));
        for(integer f=0;f<8;f++)emit(enc_i((f==1 || f==5)?31:-17,1,f,8));
        emit(enc_i('h41f,3,5,9));emit(enc_i(123,0,0,0)); // Escritura descartada en x0.
        emit(enc_s(0,8,20));emit(enc_i(0,20,2,10,'h03));
        emit(enc_i(4,20,0,21));emit(enc_s(-4,9,21));emit(enc_i(-4,21,2,11,'h03));
        // Cada bifurcacion se ejecuta tomada y no tomada; se prueban offsets negativos en el bucle.
        emit(enc_b(8,1,1,0));emit(enc_i(77,0,0,12));emit(enc_b(8,2,1,0));
        emit(enc_b(8,2,1,1));emit(enc_i(77,0,0,12));emit(enc_b(8,1,1,1));
        emit(enc_b(8,2,1,4));emit(enc_i(77,0,0,12));emit(enc_b(8,1,2,4));
        emit(enc_b(8,1,2,5));emit(enc_i(77,0,0,12));emit(enc_b(8,2,1,5));
        emit(enc_i(3,0,0,13));emit(enc_i(-1,13,0,13));emit(enc_b(-4,0,13,1));
        emit(enc_b(2,2,1,0)); // Destino desalineado descartado: no debe fallar.
        emit(enc_j(8,10));emit(enc_i(999,0,0,12));
        emit(enc_i(17,10,0,11)); // Objetivo impar: JALR borra bit 0.
        emit(enc_i(0,11,0,11,'h67));emit(enc_i(999,0,0,12));emit(enc_i(42,0,0,12));
        emit(enc_u('h10,22));emit(enc_i('h40,22,0,22));
        emit(enc_s(0,12,22));emit(enc_s(0,12,22));emit(enc_i(0,22,2,14,'h03));
        emit(enc_i(0,0,2,15,'h03)); // Lectura no mapeada.
        run_program();
        // Secuencia reproducible: dependencias entre registros y trafico de RAM.
        fresh();emit(enc_u(2,20));
        for(integer n=0;n<500;n++)begin
            case(n%5)
                0:emit(enc_i($random(seed),n%16,0,1+n%16));
                1:emit(enc_r(0,(n+3)%16,n%16,n%8,1+n%16));
                2:emit(enc_s(4*(n%64),n%16,20));
                3:emit(enc_i(4*((n-1)%64),20,2,1+n%16,'h03));
                4:emit(enc_i((n%2)?'h41f:0,n%16,5,1+n%16));
            endcase
        end
        run_program();
        // Fallos: codificaciones no soportadas, accesos y destinos incorrectos.
        for(integer n=0;n<8;n++)begin
            fresh();emit(enc_i(2,0,0,1));
            case(n)
                0:emit(32'h02000033); // M extension.
                1:emit(enc_i(0,1,2,2,'h03));
                2:emit(enc_s(0,1,1));
                3:emit(enc_j(2,2));
                4:emit(enc_i(0,1,0,2,'h67));
                5:emit(enc_b(2,0,0,0));
                6:emit(enc_j(8192,2));
                7:emit(enc_i('h800,0,1,2));
            endcase
            run_program();if(reference_pc!==4)$fatal(1,"Fallo no ocurre en instruccion esperada");
            if(dut.datapath.registers.registers[2]!==0)$fatal(1,"Fallo escribio rd");
        end
        // Ultima instruccion de ROM: debe ejecutarse, luego fallar al buscar 0x2000.
        fresh();emit(enc_j(8188,0));rom.memory[2047]=enc_i(7,0,0,1);run_program();
        if(reference_pc!==8192)$fatal(1,"Limite superior de ROM");
        // Reset real del nucleo desde todos los estados; STORE no debe producir escritura.
        for(integer target=0;target<10;target++)begin
            fresh();emit(enc_u(2,20));
            if(target==STORE)emit(enc_s(0,20,20));else emit(enc_i(0,20,2,1,'h03));
            @(negedge clk);rst=0;
            while(dut.control.state_q!=target)begin @(posedge clk);#1;end
            @(negedge clk);rst=1;#1;if(we)$fatal(1,"Reset no cancela escritura");
            @(posedge clk);#1;
            if(pa!==0 || dut.fault || dut.control.state_q!=FETCH_REQ)$fatal(1,"Reset incompleto");
            for(integer n=1;n<32;n++)if(dut.datapath.registers.registers[n]!==0)$fatal(1,"Reset de registros");
        end
        if(coverage!==29'h1fffffff)$fatal(1,"Instrucciones sin cobertura: %h",~coverage);
        $display("PASS cpu_tb: %0d instrucciones, %0d programas, 29 operaciones y reset en 10 estados",retired,programs);
        $finish;
    end
    initial begin #2000000;$fatal(1,"TIMEOUT cpu_tb");end
endmodule
