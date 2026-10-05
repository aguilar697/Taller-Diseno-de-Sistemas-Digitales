// Wrapper estructural para integrar el bus MMIO, la RAM y los perifericos.
module mmio_subsystem_top #(
    parameter int unsigned CLK_FREQ_HZ = 100_000_000,
    parameter int unsigned BAUD_RATE = 115_200,
    parameter int unsigned FRAME_REFRESH_HZ = 1_000,
    parameter int unsigned HIT_HALF_PERIOD = 50_000,
    parameter int unsigned MISS_HALF_PERIOD = 125_000,
    parameter int unsigned SUNK_HALF_PERIOD = 71_429,
    parameter int unsigned INVALID_HALF_PERIOD = 200_000,
    parameter int unsigned VICTORY_HALF_PERIOD = 33_333
)(
    input  logic        clk_i,
    input  logic        rst_i,
    input  logic [31:0] cpu_addr_i,
    input  logic [31:0] cpu_wdata_i,
    input  logic        cpu_we_i,
    output logic [31:0] cpu_rdata_o,

    input  logic        uart_rx_i,
    output logic        uart_tx_o,

    output logic [6:0]  seg_o,
    output logic [3:0]  an_o,
    output logic [1:0]  led_o,
    output logic        buzzer_o,

    input  logic [31:0] input_rdata_i,
    input  logic [31:0] vga_rdata_i,
    output logic [1:0]  input_addr_o,
    output logic [8:0]  vga_addr_o,
    output logic        input_write_enable_o,
    output logic        vga_write_enable_o
);
    logic [31:0] peripheral_wdata;

    logic [9:0] ram_addr;
    logic [1:0] uart_addr;
    logic [1:0] sevenseg_addr;
    logic [1:0] led_addr;
    logic [1:0] buzzer_addr;

    logic ram_write_enable;
    logic uart_write_enable;
    logic sevenseg_write_enable;
    logic led_write_enable;
    logic buzzer_write_enable;

    logic [31:0] ram_rdata;
    logic [31:0] uart_rdata;
    logic [31:0] sevenseg_rdata;
    logic [31:0] led_rdata;
    logic [31:0] buzzer_rdata;

    data_bus bus_inst (
        .clk_i                   (clk_i),
        .rst_i                   (rst_i),
        .cpu_addr_i              (cpu_addr_i),
        .cpu_wdata_i             (cpu_wdata_i),
        .cpu_we_i                (cpu_we_i),
        .cpu_rdata_o             (cpu_rdata_o),
        .ram_rdata_i             (ram_rdata),
        .uart_rdata_i            (uart_rdata),
        .input_rdata_i           (input_rdata_i),
        .sevenseg_rdata_i        (sevenseg_rdata),
        .led_rdata_i             (led_rdata),
        .buzzer_rdata_i          (buzzer_rdata),
        .vga_rdata_i             (vga_rdata_i),
        .peripheral_wdata_o      (peripheral_wdata),
        .ram_addr_o              (ram_addr),
        .uart_addr_o             (uart_addr),
        .input_addr_o            (input_addr_o),
        .sevenseg_addr_o         (sevenseg_addr),
        .led_addr_o              (led_addr),
        .buzzer_addr_o           (buzzer_addr),
        .vga_addr_o              (vga_addr_o),
        .ram_write_enable_o      (ram_write_enable),
        .uart_write_enable_o     (uart_write_enable),
        .input_write_enable_o    (input_write_enable_o),
        .sevenseg_write_enable_o (sevenseg_write_enable),
        .led_write_enable_o      (led_write_enable),
        .buzzer_write_enable_o   (buzzer_write_enable),
        .vga_write_enable_o      (vga_write_enable_o)
    );

    data_ram ram_inst (
        .clk_i          (clk_i),
        .write_enable_i (ram_write_enable),
        .addr_i         (ram_addr),
        .wdata_i        (peripheral_wdata),
        .rdata_o        (ram_rdata)
    );

    uart_peripheral #(
        .CLK_FREQ_HZ (CLK_FREQ_HZ),
        .BAUD_RATE   (BAUD_RATE)
    ) uart_inst (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .write_enable_i (uart_write_enable),
        .addr_i         (uart_addr),
        .wdata_i        (peripheral_wdata),
        .rdata_o        (uart_rdata),
        .uart_rx_i      (uart_rx_i),
        .uart_tx_o      (uart_tx_o)
    );

    sevenseg_peripheral #(
        .CLK_FREQ_HZ     (CLK_FREQ_HZ),
        .FRAME_REFRESH_HZ(FRAME_REFRESH_HZ)
    ) sevenseg_inst (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .write_enable_i (sevenseg_write_enable),
        .addr_i         (sevenseg_addr),
        .wdata_i        (peripheral_wdata),
        .rdata_o        (sevenseg_rdata),
        .seg_o          (seg_o),
        .an_o           (an_o)
    );

    led_peripheral led_inst (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .write_enable_i (led_write_enable),
        .addr_i         (led_addr),
        .wdata_i        (peripheral_wdata),
        .rdata_o        (led_rdata),
        .led_o          (led_o)
    );

    buzzer_peripheral #(
        .HIT_HALF_PERIOD    (HIT_HALF_PERIOD),
        .MISS_HALF_PERIOD   (MISS_HALF_PERIOD),
        .SUNK_HALF_PERIOD   (SUNK_HALF_PERIOD),
        .INVALID_HALF_PERIOD(INVALID_HALF_PERIOD),
        .VICTORY_HALF_PERIOD(VICTORY_HALF_PERIOD)
    ) buzzer_inst (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .write_enable_i (buzzer_write_enable),
        .addr_i         (buzzer_addr),
        .wdata_i        (peripheral_wdata),
        .rdata_o        (buzzer_rdata),
        .buzzer_o       (buzzer_o)
    );
endmodule
