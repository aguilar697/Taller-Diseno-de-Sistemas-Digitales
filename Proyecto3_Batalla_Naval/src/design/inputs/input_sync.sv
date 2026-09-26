module input_sync (
    input  logic clk_i,
    input  logic rst_i,
    input  logic async_i,
    output logic sync_o
);

    // Registros de las dos etapas del sincronizador.
    // La primera etapa recibe directamente la señal asíncrona y la segunda
    // entrega una versión estable al resto de la lógica síncrona.
    (* ASYNC_REG = "TRUE" *) logic sync_ff1_q;
    (* ASYNC_REG = "TRUE" *) logic sync_ff2_q;

    // Sincronizador de dos flip-flops.
    // El reset es síncrono y activo en alto.
    always_ff @(posedge clk_i) begin
        if (rst_i) begin
            sync_ff1_q <= 1'b0;
            sync_ff2_q <= 1'b0;
        end else begin
            sync_ff1_q <= async_i;
            sync_ff2_q <= sync_ff1_q;
        end
    end

    // La salida corresponde a la segunda etapa del sincronizador.
    assign sync_o = sync_ff2_q;

endmodule