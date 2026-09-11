`timescale 1ns/1ps

module button_conditioner_tb;

    localparam int unsigned TB_DEBOUNCE_CYCLES = 4;

    logic clk_i;
    logic rst_sync;
    logic btn_i;
    logic btn_pulse;

    integer pulse_count;


    // ============================================================
    // CLOCK 100 MHz
    // ============================================================
    initial begin
        clk_i = 1'b0;
        forever #5 clk_i = ~clk_i;
    end


    // ============================================================
    // DUT
    // ============================================================
    button_conditioner #(
        .DEBOUNCE_CYCLES(TB_DEBOUNCE_CYCLES)
    ) dut (
        .clk_i     (clk_i),
        .rst_sync  (rst_sync),
        .btn_i     (btn_i),
        .btn_pulse (btn_pulse)
    );


    // ============================================================
    // CONTADOR DE PULSOS GENERADOS
    // ============================================================
    always @(posedge clk_i) begin
        if (rst_sync)
            pulse_count <= 0;
        else if (btn_pulse)
            pulse_count <= pulse_count + 1;
    end


    // ============================================================
    // ESTÍMULOS
    // ============================================================
    initial begin

        // --------------------------------------------------------
        // RESET
        // --------------------------------------------------------
        rst_sync = 1'b1;
        btn_i    = 1'b0;

        #20;

        rst_sync = 1'b0;

        #20;


        // --------------------------------------------------------
        // PRUEBA 1:
        // Simular rebote al PRESIONAR el botón
        // --------------------------------------------------------
        btn_i = 1'b1;
        #3;

        btn_i = 1'b0;
        #4;

        btn_i = 1'b1;
        #3;

        btn_i = 1'b0;
        #4;

        // El botón finalmente queda presionado
        btn_i = 1'b1;

        // Tiempo suficiente para completar el debounce
        #100;


        // --------------------------------------------------------
        // Mantener botón presionado.
        // NO debe producir pulsos adicionales.
        // --------------------------------------------------------
        #50;


        // --------------------------------------------------------
        // PRUEBA 2:
        // Simular rebote al SOLTAR el botón
        // --------------------------------------------------------
        btn_i = 1'b0;
        #3;

        btn_i = 1'b1;
        #4;

        btn_i = 1'b0;
        #3;

        btn_i = 1'b1;
        #4;

        // Finalmente queda liberado
        btn_i = 1'b0;

        #100;


        // --------------------------------------------------------
        // PRUEBA 3:
        // Segunda pulsación válida
        // --------------------------------------------------------
        btn_i = 1'b1;

        #100;

        btn_i = 1'b0;

        #100;


        // --------------------------------------------------------
        // VERIFICACIÓN
        // --------------------------------------------------------
        if (pulse_count == 2) begin
            $display("-------------------------------------");
            $display("PASS: button_conditioner");
            $display("Pulsos detectados = %0d", pulse_count);
            $display("-------------------------------------");
        end
        else begin
            $error(
                "FAIL: se esperaban 2 pulsos y se obtuvieron %0d",
                pulse_count
            );
        end

        $finish;

    end

endmodule