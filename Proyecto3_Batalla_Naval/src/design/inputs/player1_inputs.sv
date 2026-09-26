module player1_inputs #(
    parameter int unsigned DEBOUNCE_CYCLES = 1_000_000
) (
    // -------------------------------------------------------------------------
    // System
    // -------------------------------------------------------------------------
    input  logic        clk_i,
    input  logic        rst_i,

    // -------------------------------------------------------------------------
    // Physical inputs - Player 1
    // -------------------------------------------------------------------------
    input  logic        up_i,
    input  logic        down_i,
    input  logic        left_i,
    input  logic        right_i,
    input  logic        sel_i,
    input  logic        ok_i,
    input  logic        game_rst_i,

    // -------------------------------------------------------------------------
    // MMIO interface
    // -------------------------------------------------------------------------
    input  logic        input_write_enable_i,
    input  logic [1:0]  input_addr_i,
    input  logic [31:0] input_wdata_i,
    output logic [31:0] input_rdata_o
);

    // -------------------------------------------------------------------------
    // Input organization
    // -------------------------------------------------------------------------
    // Los siete controles se agrupan en un vector para utilizar la misma
    // cadena de sincronización y debounce en cada entrada.
    //
    // La posición de cada bit coincide con el formato visible por software:
    // [0] UP, [1] DOWN, [2] LEFT, [3] RIGHT,
    // [4] SEL, [5] OK, [6] GAME_RST.
    logic [6:0] async_levels;
    logic [6:0] sync_levels;
    logic [6:0] clean_levels;

    assign async_levels = {
        game_rst_i,
        ok_i,
        sel_i,
        right_i,
        left_i,
        down_i,
        up_i
    };

    // -------------------------------------------------------------------------
    // Synchronization and debounce
    // -------------------------------------------------------------------------
    // Se generan siete cadenas idénticas:
    //
    // entrada física -> sincronizador de 2 FF -> debounce -> nivel estable
    //
    // El generate únicamente replica hardware durante la elaboración;
    // no representa un ciclo o proceso ejecutado durante el funcionamiento.
    generate
        for (genvar i = 0; i < 7; i++) begin : gen_inputs

            input_sync u_input_sync (
                .clk_i   (clk_i),
                .rst_i   (rst_i),
                .async_i (async_levels[i]),
                .sync_o  (sync_levels[i])
            );

            debounce #(
                .DEBOUNCE_CYCLES(DEBOUNCE_CYCLES)
            ) u_debounce (
                .clk_i   (clk_i),
                .rst_i   (rst_i),
                .sync_i  (sync_levels[i]),
                .clean_o (clean_levels[i])
            );

        end
    endgenerate

    // -------------------------------------------------------------------------
    // MMIO read interface
    // -------------------------------------------------------------------------
    // El periférico posee un único registro válido en la dirección local 00.
    // Las demás direcciones retornan cero.
    //
    // Las escrituras se ignoran: input_write_enable_i e input_wdata_i forman
    // parte de la interfaz estándar del bus, pero no modifican ningún estado.
    always_comb begin
        input_rdata_o = 32'b0;

        case (input_addr_i)
            2'b00:   input_rdata_o = {25'b0, clean_levels};
            default: input_rdata_o = 32'b0;
        endcase
    end

endmodule