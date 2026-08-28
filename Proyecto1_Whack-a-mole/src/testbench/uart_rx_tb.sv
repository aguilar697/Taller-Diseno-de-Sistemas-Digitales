//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 15.08.2026 20:16:28
// Design Name: 
// Module Name: uart_rx_tb
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


`timescale 1ns / 1ps

module uart_rx_tb;

    // Parámetros de prueba
    localparam int CLK_FREQ  = 100_000_000;
    localparam int BAUD_RATE = 1_000_000;

    localparam time CLK_PERIOD = 10ns;
    localparam time BIT_PERIOD = 1us;

    // Señales del testbench
    logic clk;
    logic reset;
    logic serial_data;

    logic [7:0] data;
    logic data_valid;


    // Instancia del módulo que estamos probando
    uart_rx #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .reset(reset),
        .serial_data(serial_data),
        .data(data),
        .data_valid(data_valid)
    );


        // Generación del reloj de 100 MHz
    initial begin
        clk = 1'b0;

        forever #(CLK_PERIOD / 2)
            clk = ~clk;
    end


    // Tarea para enviar un byte UART
    task automatic send_uart_byte(input logic [7:0] value);
        integer i;

        begin

            // Start bit
            serial_data = 1'b0;
            #(BIT_PERIOD);

            // 8 bits de datos, LSB primero
            for (i = 0; i < 8; i = i + 1) begin
                serial_data = value[i];
                #(BIT_PERIOD);
            end

            // Stop bit
            serial_data = 1'b1;
            #(BIT_PERIOD);

        end
    endtask


    // Secuencia principal de prueba
initial begin
    integer j;

    // Valores iniciales
    serial_data = 1'b1;
    reset       = 1'b1;

    // Reset inicial
    #100ns;
    reset = 1'b0;

    #100ns;

    // Probar las 8 posiciones: 0 a 7
    for (j = 0; j < 8; j = j + 1) begin

        fork

            begin
                send_uart_byte(j[7:0]);
            end

            begin
                @(posedge data_valid);

                if (data == j[7:0])
                    $display(
                        "PRUEBA CORRECTA: se recibio 0x%02h",
                        data
                    );
                else
                    $error(
                        "ERROR: se esperaba 0x%02h y se recibio 0x%02h",
                        j[7:0],
                        data
                    );
            end

        join

        // Pequeña pausa entre tramas
        #(BIT_PERIOD);

    end

    $display("TODAS LAS PRUEBAS FINALIZARON");

    #1us;

    $finish;

end

endmodule