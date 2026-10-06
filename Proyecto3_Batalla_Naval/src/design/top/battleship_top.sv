// Top global estructural del Proyecto 3.
module battleship_top #(
    parameter ROM_INIT_FILE = ""
)(
    input  logic       clk_i,
    input  logic       rst_i,

    input  logic       up_i,
    input  logic       down_i,
    input  logic       left_i,
    input  logic       right_i,
    input  logic       sel_i,
    input  logic       ok_i,
    input  logic       game_rst_i,

    input  logic       uart_rx_i,
    output logic       uart_tx_o,

    output logic [3:0] vga_red_o,
    output logic [3:0] vga_green_o,
    output logic [3:0] vga_blue_o,
    output logic       vga_hsync_o,
    output logic       vga_vsync_o,

    output logic [6:0] seg_o,
    output logic [3:0] an_o,
    output logic [1:0] led_o,
    output logic       buzzer_o
);
    logic [31:0] prog_address;
    logic [31:0] prog_rdata;

    logic [31:0] data_address;
    logic [31:0] data_wdata;
    logic [31:0] data_rdata;
    logic        data_write_enable;

    logic [31:0] input_rdata;
    logic [31:0] vga_rdata;
    logic [1:0]  input_addr;
    logic [8:0]  vga_addr;
    logic        input_write_enable;
    logic        vga_write_enable;

    logic [11:0] vga_rgb;

    // TODO: sincronizar la entrada de reset antes de la validacion fisica final.
    // Por ahora rst_i se usa directamente en todo el dominio de 100 MHz. El
    // subsistema VGA gestiona internamente el reset de su dominio de pixel.

    cpu cpu_inst (
        .clk_i         (clk_i),
        .rst_i         (rst_i),
        .ProgAddress_o (prog_address),
        .ProgIn_i      (prog_rdata),
        .DataAddress_o (data_address),
        .DataOut_o     (data_wdata),
        .DataIn_i      (data_rdata),
        .we_o          (data_write_enable)
    );

    program_rom #(
        .INIT_FILE (ROM_INIT_FILE)
    ) program_rom_inst (
        .clk_i   (clk_i),
        .addr_i  (prog_address),
        .rdata_o (prog_rdata)
    );

    mmio_subsystem_top mmio_inst (
        .clk_i                (clk_i),
        .rst_i                (rst_i),
        .cpu_addr_i           (data_address),
        .cpu_wdata_i          (data_wdata),
        .cpu_we_i             (data_write_enable),
        .cpu_rdata_o          (data_rdata),
        .uart_rx_i            (uart_rx_i),
        .uart_tx_o            (uart_tx_o),
        .seg_o                (seg_o),
        .an_o                 (an_o),
        .led_o                (led_o),
        .buzzer_o             (buzzer_o),
        .input_rdata_i        (input_rdata),
        .vga_rdata_i          (vga_rdata),
        .input_addr_o         (input_addr),
        .vga_addr_o           (vga_addr),
        .input_write_enable_o (input_write_enable),
        .vga_write_enable_o   (vga_write_enable)
    );

    subsystem2_vga_inputs vga_inputs_inst (
        .clk_100_i           (clk_i),
        .rst_i               (rst_i),
        .up_i                (up_i),
        .down_i              (down_i),
        .left_i              (left_i),
        .right_i             (right_i),
        .sel_i               (sel_i),
        .ok_i                (ok_i),
        .game_rst_i          (game_rst_i),
        .input_write_enable_i(input_write_enable),
        .input_addr_i        (input_addr),
        .input_wdata_i       (data_wdata),
        .input_rdata_o       (input_rdata),
        .vga_write_enable_i  (vga_write_enable),
        .vga_addr_i          (vga_addr),
        .vga_wdata_i         (data_wdata),
        .vga_rdata_o         (vga_rdata),
        .vga_hsync_o         (vga_hsync_o),
        .vga_vsync_o         (vga_vsync_o),
        .vga_rgb_o           (vga_rgb)
    );

    assign vga_red_o   = vga_rgb[11:8];
    assign vga_green_o = vga_rgb[7:4];
    assign vga_blue_o  = vga_rgb[3:0];
endmodule
