module protocol_rx_controller_tb;

    timeunit 1ns;
    timeprecision 1ps;

    localparam time CLK_PERIOD       = 10ns;
    localparam time BIT_PERIOD       = 8680ns;
    localparam time WATCHDOG_TIMEOUT = 2ms;

    localparam logic [1:0] ADDR_RX_DATA = 2'b01;
    localparam logic [1:0] ADDR_CONTROL = 2'b10;

    localparam int EVENT_WAIT_CYCLES = 30_000;

    logic        clk_i = 1'b0;
    logic        rst_i = 1'b1;
    logic        bus_grant_i = 1'b1;
    logic        rx_i = 1'b1;
    logic        tx_o;

    logic        mmio_write_enable;
    logic [1:0]  mmio_addr;
    logic [31:0] mmio_wdata;
    logic [31:0] mmio_rdata;

    logic [7:0]  letter_o;
    logic        letter_valid_o;

    int unsigned valid_pulse_count = 0;
    int unsigned ack_count = 0;
    int unsigned rx_data_read_count = 0;

    always #(CLK_PERIOD / 2) clk_i = ~clk_i;

    uart_peripheral uart_peripheral_dut (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .write_enable_i (mmio_write_enable),
        .addr_i         (mmio_addr),
        .wdata_i        (mmio_wdata),
        .rdata_o        (mmio_rdata),
        .rx_i           (rx_i),
        .tx_o           (tx_o)
    );

    protocol_rx_controller protocol_rx_controller_dut (
        .clk_i          (clk_i),
        .rst_i          (rst_i),
        .bus_grant_i    (bus_grant_i),
        .write_enable_o (mmio_write_enable),
        .addr_o         (mmio_addr),
        .wdata_o        (mmio_wdata),
        .rdata_i        (mmio_rdata),
        .letter_o       (letter_o),
        .letter_valid_o (letter_valid_o)
    );

    task automatic send_uart_byte (input logic [7:0] data);
        begin
            rx_i = 1'b1;
            #(BIT_PERIOD);

            rx_i = 1'b0;
            #(BIT_PERIOD);

            for (int bit_index = 0; bit_index < 8; bit_index++) begin
                rx_i = data[bit_index];
                #(BIT_PERIOD);
            end

            rx_i = 1'b1;
            #(BIT_PERIOD);
        end
    endtask

    task automatic wait_for_valid_count (input int unsigned expected_count);
        bit observed;
        begin
            observed = 1'b0;

            for (int cycle = 0; cycle < EVENT_WAIT_CYCLES; cycle++) begin
                if (valid_pulse_count >= expected_count) begin
                    observed = 1'b1;
                    break;
                end
                @(posedge clk_i);
            end

            if (!observed) begin
                $fatal(1, "Timeout esperando el pulso esperado de letter_valid_o");
            end
        end
    endtask

    task automatic wait_for_ack_count (input int unsigned expected_count);
        bit observed;
        begin
            observed = 1'b0;

            for (int cycle = 0; cycle < EVENT_WAIT_CYCLES; cycle++) begin
                if (ack_count >= expected_count) begin
                    observed = 1'b1;
                    break;
                end
                @(posedge clk_i);
            end

            if (!observed) begin
                $fatal(1, "Timeout esperando la escritura W1C esperada");
            end
        end
    endtask

    task automatic check_new_rx_cleared (input string test_name);
        bit observed;
        begin
            observed = 1'b0;

            for (int cycle = 0; cycle < 20; cycle++) begin
                @(negedge clk_i);
                if (!mmio_write_enable &&
                    (mmio_addr == ADDR_CONTROL) &&
                    (mmio_rdata[1] === 1'b0)) begin
                    observed = 1'b1;
                    break;
                end
            end

            if (!observed) begin
                $fatal(1, "%s: new_rx no fue limpiado por RX_ACK", test_name);
            end
        end
    endtask

    initial begin : letter_valid_monitor
        time pulse_start;

        forever begin
            @(posedge letter_valid_o);
            pulse_start = $time;

            case (valid_pulse_count)
                0: begin
                    if (letter_o !== 8'h41) begin
                        $fatal(1,
                            "Primer pulso válido: se esperaba 0x41 y se obtuvo 0x%02h",
                            letter_o);
                    end
                end

                1: begin
                    if (letter_o !== 8'h5A) begin
                        $fatal(1,
                            "Segundo pulso válido: se esperaba 0x5A y se obtuvo 0x%02h",
                            letter_o);
                    end
                end

                default: begin
                    $fatal(1, "Se observó un pulso adicional de letter_valid_o");
                end
            endcase

            @(negedge letter_valid_o);

            if (($time - pulse_start) != CLK_PERIOD) begin
                $fatal(1,
                    "letter_valid_o duró %0t; se esperaba exactamente %0t",
                    $time - pulse_start, CLK_PERIOD);
            end

            valid_pulse_count++;
        end
    end

    initial begin : ack_monitor
        time pulse_start;

        forever begin
            @(posedge mmio_write_enable);
            pulse_start = $time;
            #1ps;

            if ((mmio_addr !== ADDR_CONTROL) ||
                (mmio_wdata !== 32'h0000_0002)) begin
                $fatal(1,
                    "Escritura MMIO inesperada: addr=%b wdata=0x%08h",
                    mmio_addr, mmio_wdata);
            end

            @(negedge mmio_write_enable);

            if (($time - pulse_start) != CLK_PERIOD) begin
                $fatal(1,
                    "RX_ACK duró %0t; se esperaba exactamente %0t",
                    $time - pulse_start, CLK_PERIOD);
            end

            ack_count++;
        end
    end

    always @(negedge clk_i) begin : rx_data_read_monitor
        if (!rst_i && !mmio_write_enable && (mmio_addr == ADDR_RX_DATA)) begin
            case (rx_data_read_count)
                0: begin
                    if (mmio_rdata !== 32'h0000_0041) begin
                        $fatal(1,
                            "Primera lectura RX_DATA: se esperaba 0x41 y se obtuvo 0x%08h",
                            mmio_rdata);
                    end
                end

                1: begin
                    if (mmio_rdata !== 32'h0000_0061) begin
                        $fatal(1,
                            "Segunda lectura RX_DATA: se esperaba 0x61 y se obtuvo 0x%08h",
                            mmio_rdata);
                    end
                end

                2: begin
                    if (mmio_rdata !== 32'h0000_005A) begin
                        $fatal(1,
                            "Tercera lectura RX_DATA: se esperaba 0x5A y se obtuvo 0x%08h",
                            mmio_rdata);
                    end
                end

                default: begin
                    $fatal(1, "Se observó una lectura adicional inesperada de RX_DATA");
                end
            endcase

            rx_data_read_count++;
        end
    end

    initial begin : stimulus
        int unsigned valid_count_before_invalid;

        rst_i = 1'b1;
        rx_i  = 1'b1;

        repeat (3) @(posedge clk_i);
        @(negedge clk_i);

        if (letter_o !== 8'h00) begin
            $fatal(1, "Reset: letter_o no fue limpiado");
        end

        if (letter_valid_o !== 1'b0) begin
            $fatal(1, "Reset: letter_valid_o no fue limpiado");
        end

        if (rx_i !== 1'b1) begin
            $fatal(1, "Reset: rx_i no permanece en reposo lógico 1");
        end

        rst_i = 1'b0;

        send_uart_byte(8'h41);
        wait_for_valid_count(1);
        wait_for_ack_count(1);
        check_new_rx_cleared("Letra válida 0x41");

        if (letter_o !== 8'h41) begin
            $fatal(1, "Letra válida 0x41: letter_o contiene 0x%02h", letter_o);
        end

        valid_count_before_invalid = valid_pulse_count;

        send_uart_byte(8'h61);
        wait_for_ack_count(2);
        check_new_rx_cleared("Byte inválido 0x61");

        if (rx_data_read_count != 2) begin
            $fatal(1, "Byte inválido 0x61 no fue leído desde RX_DATA");
        end

        if (valid_pulse_count != valid_count_before_invalid) begin
            $fatal(1, "Byte inválido 0x61 generó letter_valid_o");
        end

        if (letter_o !== 8'h41) begin
            $fatal(1, "Byte inválido 0x61 modificó letter_o");
        end

        send_uart_byte(8'h5A);
        wait_for_valid_count(2);
        wait_for_ack_count(3);
        check_new_rx_cleared("Letra válida 0x5A");

        if (letter_o !== 8'h5A) begin
            $fatal(1, "Letra válida 0x5A: letter_o contiene 0x%02h", letter_o);
        end

        if (valid_pulse_count != 2) begin
            $fatal(1,
                "Se esperaban exactamente 2 pulsos válidos y se observaron %0d",
                valid_pulse_count);
        end

        if (ack_count != 3) begin
            $fatal(1,
                "Se esperaban exactamente 3 escrituras W1C y se observaron %0d",
                ack_count);
        end

        if (rx_data_read_count != 3) begin
            $fatal(1,
                "Se esperaban exactamente 3 lecturas de RX_DATA y se observaron %0d",
                rx_data_read_count);
        end

        $display("protocol_rx_controller_tb: todas las pruebas finalizaron correctamente");
        $finish;
    end

    initial begin : watchdog
        #WATCHDOG_TIMEOUT;
        $fatal(1,
            "protocol_rx_controller_tb: tiempo máximo de simulación excedido");
    end

endmodule
