module uart_peripheral_tb;

    timeunit 1ns;
    timeprecision 1ps;

    localparam time CLK_PERIOD = 10ns;
    localparam time BIT_PERIOD = 8680ns;
    localparam time WATCHDOG_TIMEOUT = 2ms;

    localparam logic [1:0] ADDR_TX_DATA = 2'b00;
    localparam logic [1:0] ADDR_RX_DATA = 2'b01;
    localparam logic [1:0] ADDR_CONTROL = 2'b10;
    localparam logic [1:0] ADDR_RESERVED = 2'b11;

    localparam int MMIO_WAIT_CYCLES = 30_000;

    logic        clk_i = 1'b0;
    logic        rst_i = 1'b1;
    logic        write_enable_i = 1'b0;
    logic [1:0]  addr_i = ADDR_TX_DATA;
    logic [31:0] wdata_i = 32'b0;
    logic [31:0] rdata_o;
    logic        rx_i;
    logic        tx_o;

    assign rx_i = tx_o;

    always #(CLK_PERIOD / 2) clk_i = ~clk_i;

    uart_peripheral dut (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .write_enable_i (write_enable_i),
        .addr_i         (addr_i),
        .wdata_i        (wdata_i),
        .rdata_o        (rdata_o),
        .rx_i           (rx_i),
        .tx_o           (tx_o)
    );

    task automatic mmio_write (
        input logic [1:0]  address,
        input logic [31:0] data
    );
        begin
            @(negedge clk_i);
            addr_i         <= address;
            wdata_i        <= data;
            write_enable_i <= 1'b1;

            @(negedge clk_i);
            write_enable_i <= 1'b0;
            wdata_i        <= 32'b0;
        end
    endtask

    task automatic mmio_read (
        input  logic [1:0]  address,
        output logic [31:0] data
    );
        begin
            @(negedge clk_i);
            addr_i         <= address;
            write_enable_i <= 1'b0;
            #1ns;
            data = rdata_o;
        end
    endtask

    task automatic mmio_check (
        input logic [1:0]  address,
        input logic [31:0] expected,
        input string       test_name
    );
        logic [31:0] observed;
        begin
            mmio_read(address, observed);
            if (observed !== expected) begin
                $fatal(1,
                    "%s: se esperaba 0x%08h y se obtuvo 0x%08h",
                    test_name, expected, observed);
            end
        end
    endtask

    task automatic wait_until_send_clear;
        logic [31:0] control_value;
        bit          observed;
        begin
            observed = 1'b0;

            for (int cycle = 0; cycle < MMIO_WAIT_CYCLES; cycle++) begin
                mmio_read(ADDR_CONTROL, control_value);
                if (control_value[0] === 1'b0) begin
                    observed = 1'b1;
                    break;
                end
            end

            if (!observed) begin
                $fatal(1, "Timeout esperando que CONTROL[0] send regresara a 0");
            end
        end
    endtask

    task automatic wait_until_new_rx;
        logic [31:0] control_value;
        bit          observed;
        begin
            observed = 1'b0;

            for (int cycle = 0; cycle < MMIO_WAIT_CYCLES; cycle++) begin
                mmio_read(ADDR_CONTROL, control_value);
                if (control_value[1] === 1'b1) begin
                    observed = 1'b1;
                    break;
                end
            end

            if (!observed) begin
                $fatal(1, "Timeout esperando que CONTROL[1] new_rx pasara a 1");
            end
        end
    endtask

    initial begin : stimulus
        rst_i          = 1'b1;
        write_enable_i = 1'b0;
        addr_i         = ADDR_TX_DATA;
        wdata_i        = 32'b0;

        repeat (3) @(posedge clk_i);
        @(negedge clk_i);
        rst_i = 1'b0;

        mmio_check(ADDR_TX_DATA, 32'h0000_0000,
            "Reset: TX_DATA");
        mmio_check(ADDR_RX_DATA, 32'h0000_0000,
            "Reset: RX_DATA");
        mmio_check(ADDR_CONTROL, 32'h0000_0000,
            "Reset: CONTROL");
        mmio_check(ADDR_RESERVED, 32'h0000_0000,
            "Reset: RESERVED");

        if (tx_o !== 1'b1) begin
            $fatal(1, "Reset: tx_o no permanece en reposo lógico 1");
        end

        mmio_write(ADDR_TX_DATA, 32'h0000_0041);
        mmio_check(ADDR_TX_DATA, 32'h0000_0041,
            "TX_DATA: escritura de 0x41");

        mmio_write(ADDR_CONTROL, 32'h0000_0001);
        mmio_check(ADDR_CONTROL, 32'h0000_0001,
            "Transmisión 0x41: send no se activó");

        wait_until_send_clear();
        wait_until_new_rx();
        mmio_check(ADDR_CONTROL, 32'h0000_0002,
            "Loopback 0x41: estado final de CONTROL");
        mmio_check(ADDR_RX_DATA, 32'h0000_0041,
            "Loopback 0x41: RX_DATA");

        mmio_write(ADDR_CONTROL, 32'h0000_0002);
        mmio_check(ADDR_CONTROL, 32'h0000_0000,
            "W1C: limpieza de new_rx");
        mmio_check(ADDR_RX_DATA, 32'h0000_0041,
            "W1C: conservación de RX_DATA");

        mmio_write(ADDR_TX_DATA, 32'h0000_005A);
        mmio_write(ADDR_CONTROL, 32'h0000_0001);
        mmio_check(ADDR_CONTROL, 32'h0000_0001,
            "Transmisión 0x5A: send no se activó");

        wait_until_send_clear();
        wait_until_new_rx();
        mmio_check(ADDR_RX_DATA, 32'h0000_005A,
            "Loopback 0x5A: RX_DATA");
        mmio_check(ADDR_CONTROL, 32'h0000_0002,
            "Loopback 0x5A: estado final de CONTROL");

        mmio_write(ADDR_RX_DATA, 32'h0000_00A5);
        mmio_check(ADDR_RX_DATA, 32'h0000_005A,
            "RX_DATA: escritura MMIO ignorada");

        mmio_check(ADDR_RESERVED, 32'h0000_0000,
            "RESERVED: lectura inicial");
        mmio_write(ADDR_RESERVED, 32'hDEAD_BEEF);
        mmio_check(ADDR_TX_DATA, 32'h0000_005A,
            "RESERVED: conservación de TX_DATA");
        mmio_check(ADDR_RX_DATA, 32'h0000_005A,
            "RESERVED: conservación de RX_DATA");
        mmio_check(ADDR_CONTROL, 32'h0000_0002,
            "RESERVED: conservación de CONTROL");
        mmio_check(ADDR_RESERVED, 32'h0000_0000,
            "RESERVED: escritura ignorada");

        mmio_write(ADDR_TX_DATA, 32'hABCD_EF42);
        mmio_check(ADDR_TX_DATA, 32'h0000_0042,
            "TX_DATA: bits superiores de wdata_i ignorados");

        mmio_write(ADDR_CONTROL, 32'h0000_0002);
        mmio_check(ADDR_CONTROL, 32'h0000_0000,
            "Prueba ocupado: limpieza previa de new_rx");

        mmio_write(ADDR_CONTROL, 32'h0000_0001);
        mmio_check(ADDR_CONTROL, 32'h0000_0001,
            "Prueba ocupado: primera solicitud send");

        mmio_write(ADDR_CONTROL, 32'h0000_0001);
        mmio_check(ADDR_CONTROL, 32'h0000_0001,
            "Prueba ocupado: segunda solicitud debe ignorarse");

        wait_until_send_clear();
        wait_until_new_rx();
        mmio_check(ADDR_RX_DATA, 32'h0000_0042,
            "Prueba ocupado: byte recibido");
        mmio_check(ADDR_CONTROL, 32'h0000_0002,
            "Prueba ocupado: estado después de la trama válida");

        mmio_write(ADDR_CONTROL, 32'h0000_0002);
        mmio_check(ADDR_CONTROL, 32'h0000_0000,
            "Prueba ocupado: limpieza del único byte recibido");

        #(15 * BIT_PERIOD);

        mmio_check(ADDR_CONTROL, 32'h0000_0000,
            "Prueba ocupado: se detectó una transmisión adicional");
        mmio_check(ADDR_RX_DATA, 32'h0000_0042,
            "Prueba ocupado: RX_DATA cambió inesperadamente");

        $display("uart_peripheral_tb: todas las pruebas finalizaron correctamente");
        $finish;
    end

    initial begin : watchdog
        #WATCHDOG_TIMEOUT;
        $fatal(1, "uart_peripheral_tb: tiempo máximo de simulación excedido");
    end

endmodule
