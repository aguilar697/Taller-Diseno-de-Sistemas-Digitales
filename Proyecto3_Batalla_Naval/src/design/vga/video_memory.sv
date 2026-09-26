module video_memory (
    // -------------------------------------------------------------------------
    // CPU port - 100 MHz domain
    // -------------------------------------------------------------------------
    input  logic        clk_100_i,
    input  logic        rst_i,
    input  logic        vga_write_enable_i,
    input  logic [8:0]  vga_addr_i,
    input  logic [31:0] vga_wdata_i,
    output logic [31:0] vga_rdata_o,

    // -------------------------------------------------------------------------
    // VGA port - 25 MHz domain
    // -------------------------------------------------------------------------
    input  logic        clk_pixel_i,
    input  logic [8:0]  tile_addr_i,
    output logic [31:0] tile_word_o
);

    // -------------------------------------------------------------------------
    // Video memory organization
    // -------------------------------------------------------------------------
    // La memoria reserva 512 palabras de 32 bits.
    //
    // 0 ... 299   -> tiles visibles de la pantalla 20 x 15
    // 300 ... 511 -> posiciones reservadas
    localparam int unsigned MEMORY_DEPTH  = 512;
    localparam int unsigned VISIBLE_TILES = 300;

    // Se solicita implementación mediante memoria de bloque cuando sea posible.
    (* ram_style = "block" *)
    logic [31:0] memory [0:MEMORY_DEPTH-1];

    // -------------------------------------------------------------------------
    // Port A - CPU synchronous read/write
    // -------------------------------------------------------------------------
    // Las operaciones del CPU ocurren en el dominio de 100 MHz.
    //
    // Solo los índices 0..299 pueden modificar la memoria.
    // Una lectura de la región reservada devuelve cero.
    //
    // El reset limpia únicamente el registro de salida. No se borra toda la
    // BRAM durante reset, evitando convertir el reset en lógica de borrado de
    // cientos de palabras.
    always_ff @(posedge clk_100_i) begin
        if (rst_i) begin
            vga_rdata_o <= 32'b0;
        end else begin

            if (vga_addr_i < VISIBLE_TILES) begin

                // Escritura válida en una posición visible.
                if (vga_write_enable_i) begin
                    memory[vga_addr_i] <= vga_wdata_i;
                end

                // Lectura síncrona del contenido almacenado.
                vga_rdata_o <= memory[vga_addr_i];

            end else begin

                // La región 300..511 está reservada.
                // Sus escrituras se ignoran y sus lecturas retornan cero.
                vga_rdata_o <= 32'b0;

            end
        end
    end

    // -------------------------------------------------------------------------
    // Port B - VGA synchronous read-only port
    // -------------------------------------------------------------------------
    // El renderer solicita un tile utilizando el reloj de píxel.
    // El dato aparece después del flanco correspondiente de clk_pixel_i.
    //
    // Aunque el renderer normalmente solo solicita tiles visibles, también
    // protegemos este puerto frente a índices reservados.
    always_ff @(posedge clk_pixel_i) begin
        if (tile_addr_i < VISIBLE_TILES) begin
            tile_word_o <= memory[tile_addr_i];
        end else begin
            tile_word_o <= 32'b0;
        end
    end

endmodule