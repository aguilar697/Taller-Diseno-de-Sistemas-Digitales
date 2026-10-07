// ROM de instrucciones: conserva el programa que ejecuta el CPU.
// Capacidad 2048 palabras x 32 bits = 8192 bytes = 8 KiB.
// Lectura síncrona, sin puerto de escritura y sin borrado por reset del CPU.
module program_rom #(
    // Archivo hexadecimal de palabras. La integración pasa program.hex;
    // una cadena vacía permite utilizar una ROM de NOP en pruebas.
    parameter INIT_FILE = ""
)(
    input logic clk_i,
    input logic [31:0] addr_i,
    output logic [31:0] rdata_o
);
    // NOP = ADDI x0,x0,0: no cambia registros y permite continuar con PC+4.
    localparam logic [31:0] NOP=32'h00000013;
    logic [31:0] memory [0:2047];
    integer index;
    // INICIALIZACIÓN: completa posiciones con NOP y carga la imagen indicada.
    // $readmemh interpreta hexadecimal, no código ensamblador. En el flujo
    // FPGA el archivo determina el contenido inicial de memoria del bitstream;
    // no se abre un archivo en tiempo de ejecución ni se recarga con reset.
    initial begin
        for (index=0; index<2048; index=index+1) memory[index]=NOP;
        if (INIT_FILE != "") $readmemh(INIT_FILE, memory);
    end
    // LECTURA REGISTRADA: cambiar addr_i entre flancos no cambia rdata_o.
    // El CPU presenta PC en FETCH_REQ y captura la palabra en FETCH_CAPTURE.
    // Antes del primer flanco rdata_o puede ser desconocido; no hay reset aquí.
    always_ff @(posedge clk_i) begin
        // Dirección en bytes: [31:13]=0 exige rango 0x0000-0x1FFF;
        // [1:0]=0 exige alineación a cuatro bytes; [12:2] es el índice 0-2047.
        // Ejemplos: 0x0004 -> palabra 1; 0x1FFC -> última palabra (2047).
        if (addr_i[31:13]==0 && addr_i[1:0]==0) rdata_o<=memory[addr_i[12:2]];
        // Fuera de rango o desalineada devuelve NOP. Además el CPU valida PC
        // y entra en FAULT: este NOP no autoriza ejecutar una dirección inválida.
        else rdata_o<=NOP;
    end
endmodule
