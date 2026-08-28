`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 14.08.2026 15:09:02
// Design Name: 
// Module Name: uart_rx
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


module uart_rx #(
    parameter int CLK_FREQ  = 100_000_000,      // la función ¨parameter¨ es para definir un valor que es configurable
    parameter int BAUD_RATE = 9600
)(
    //Puertos
    input  logic       clk,                     //reloj de la FPGA
    input  logic       reset,                   //reinicia el receptor
    input  logic       serial_data,             //es la señal física que llegará desde el circuito discreto

    output logic [7:0] data,                    //byte completo recibido
    output logic       data_valid               //esta señal nos permite avisarle al resto del sistema
);
    //Señales internas del reloj
    logic rx_meta;                              //primera etapa del sincronizador
    logic rx_sync;                              //segunda etapa
    
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;         //(¨localparam¨ es una constante interna del modúlo) aqui definimos los cloks por bit
    
    typedef enum logic [1:0] {                  //¨typedef¨ es para crear un nuevo tipo de dato
    IDLE,
    START,
    DATA,
    STOP
} state_t;

state_t state;                                  //se observa el estado

    integer clk_count;                          //cuenta los ciclos de 100 MHz para saber cuándo tomar una muestra del bit UART
    logic [2:0] bit_index;                      //lleva la cuenta
    logic [7:0] rx_shift;                       //es donde vamos guardando el byte recibido
    
    // Sincronizador de dos etapas
    always_ff @(posedge clk) begin              //¨always_ff¨ indica que estamos describiendo lógica secuencial con flip-flops y ¨posedge clk¨ indica que se ejecute cada vez que haya un flanco positivo
    if (reset) begin                            //si reset es 1 ponemos el valor inicial conocido   
        rx_meta <= 1'b1;                        //esto es el valor inicial y es 1 bit cuyo valor es 1
        rx_sync <= 1'b1;
    end
    else begin                                  //si no ocurre el caso anterior entonces se procede normal
        rx_meta <= serial_data;
        rx_sync <= rx_meta;
    end
end

    //FSM del receptor UART
    always_ff @(posedge clk) begin
    if (reset) begin                            //cuando es verdadero iniciar el proceso de reiniciar
        state      <= IDLE;
        clk_count  <= 0;
        bit_index  <= 0;
        rx_shift   <= 0;
        data       <= 0;
        data_valid <= 0;
    end
    else begin
        data_valid <= 0;                        //queremos que data_valid sea un pulso de un solo ciclo

        case (state)                            //dependiendo del estado actual de la FSM

            IDLE: begin                         //Ejecuta esta lógica cuando la FSM esté en el estado IDLE
                clk_count <= 0;
                bit_index <= 0;

                if (rx_sync == 1'b0) begin      //espera un cambio en el bit para poder revisar START
                    state <= START;
                end
            end
            
            START: begin                        //Ejecuta esta lógica cuando la FSM esté en el estado START
                if (clk_count == (CLKS_PER_BIT / 2) - 1) begin          //esperamos medio tiempo de bit, porque queremos leer cerca del centro porque ahí la señal es más estable
                clk_count <= 0;

                if (rx_sync == 1'b0) begin      //espera un cambio en el bit para poder revisar DATA
                    state <= DATA;
            end
            
                else begin
                    state <= IDLE;              //consideramos que no es valida entonces se regresa a esperar
                end
            end
                 else begin
                    clk_count <= clk_count + 1; //mientras todavía no haya pasado medio bit, incrementamos el contador
                 end
            end
            
            DATA: begin                         //esta etapa se encarga de recibir los datos
    if (clk_count == CLKS_PER_BIT - 1) begin    //esperamos un tiempo de bit completo
        clk_count <= 0;

        rx_shift[bit_index] <= rx_sync;         //guardamos el bit que estamos viendo

        if (bit_index == 3'd7) begin            //si recibimos el bit 7
            bit_index <= 0;
            state <= STOP;
        end
        else begin
            bit_index <= bit_index + 1;         //esto es si todavia no se ha recibido el bit 7
        end
    end
    else begin
        clk_count <= clk_count + 1;
    end
end
            STOP: begin                         //aquí ya recibimos los 8 bits de datos y estamos esperando el bit de parada
    if (clk_count == CLKS_PER_BIT - 1) begin    //esperamos un tiempo de bit completo desde la última muestra de D7
        clk_count <= 0;                         //cuando llega el momento se reinicia el contador

        if (rx_sync == 1'b1) begin              //si la línea está en 1, el stop bit es válido
            data       <= rx_shift;             //esto copia el byte completo recibido hacia la salida data
            data_valid <= 1'b1;                 //aqui le dice al sitema que ya llegó un byte válido
        end

        state <= IDLE;                          //regresamos a esperar la siguiente trama
    end
    else begin
        clk_count <= clk_count + 1;
    end
end

            default: begin
                state <= IDLE;                  //si por alguna razón state toma un valor inesperado, la FSM vuelve a IDLE
            end

        endcase
    end
end

endmodule