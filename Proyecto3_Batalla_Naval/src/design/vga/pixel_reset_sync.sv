module pixel_reset_sync (
    input  logic clk_pixel_i,
    input  logic rst_i,
    input  logic locked_i,
    output logic rst_pixel_o
);

    // -------------------------------------------------------------------------
    // Reset synchronization pipeline
    // -------------------------------------------------------------------------
    // El reset del dominio VGA debe permanecer activo mientras exista un
    // reset general o mientras el PLL todavía no esté bloqueado.
    //
    // La activación del reset es inmediata, mientras que su liberación se
    // sincroniza con clk_pixel_i mediante dos etapas.
    (* ASYNC_REG = "TRUE" *) logic [1:0] reset_pipe_q;

    logic reset_request;

    assign reset_request = rst_i | ~locked_i;

    // -------------------------------------------------------------------------
    // Pixel-domain reset synchronizer
    // -------------------------------------------------------------------------
    // Si se solicita reset, ambas etapas se fuerzan a '1'.
    //
    // Cuando desaparece la solicitud, los ceros avanzan por el pipeline en
    // cada flanco positivo del reloj de píxel. De esta forma rst_pixel_o solo
    // se desactiva de manera sincronizada con clk_pixel_i.
    always_ff @(posedge clk_pixel_i or posedge reset_request) begin
        if (reset_request) begin
            reset_pipe_q <= 2'b11;
        end else begin
            reset_pipe_q <= {reset_pipe_q[0], 1'b0};
        end
    end

    // La segunda etapa controla el reset utilizado por el dominio VGA.
    assign rst_pixel_o = reset_pipe_q[1];

endmodule