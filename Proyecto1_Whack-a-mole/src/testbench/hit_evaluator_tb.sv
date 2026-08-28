`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 18.08.2026 14:57:00
// Design Name: Whack-a-Mole FPGA Game
// Module Name: hit_evaluator_tb
// Project Name: project_1_fsm_game
// Target Devices: Basys 3 - Artix-7 XC7A35T-1CPG236C
// Tool Versions: Vivado 2026.1
// Description: 
// Testbench autoverificable para el módulo hit_evaluator.
//
// El objetivo es comprobar que el evaluador distingue correctamente entre:
//   - ausencia de pulsación,
//   - pulsación correcta,
//   - pulsación incorrecta,
//   - múltiples botones presionados simultáneamente.
//
// Se prueban las ocho posiciones posibles del topo, verificando que cada una
// genere hit_event únicamente cuando se presiona el botón correspondiente.
//
// Dependencies: 
// hit_evaluator.sv
//
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// Este testbench no requiere reloj, ya que hit_evaluator es un módulo
// puramente combinacional.
//
//////////////////////////////////////////////////////////////////////////////////


module hit_evaluator_tb;


    //--------------------------------------------------------------------------
    // Señales de entrada hacia el DUT
    //--------------------------------------------------------------------------

    logic [2:0] mole_position;
    logic [7:0] press_pulse;


    //--------------------------------------------------------------------------
    // Señales de salida del DUT
    //--------------------------------------------------------------------------

    logic hit_event;
    logic wrong_hit;
    logic any_press;


    //--------------------------------------------------------------------------
    // Instancia del módulo bajo prueba
    //--------------------------------------------------------------------------

    hit_evaluator dut (

        .mole_position (mole_position),
        .press_pulse   (press_pulse),

        .hit_event     (hit_event),
        .wrong_hit     (wrong_hit),
        .any_press     (any_press)

    );


    //--------------------------------------------------------------------------
    // Secuencia principal de pruebas
    //--------------------------------------------------------------------------

    initial begin

        integer i;


        //----------------------------------------------------------------------
        // PRUEBA 1
        // No se presiona ningún botón
        //
        // Resultado esperado:
        //   hit_event = 0
        //   wrong_hit = 0
        //   any_press = 0
        //----------------------------------------------------------------------

        mole_position = 3'd0;
        press_pulse   = 8'b00000000;

        #10ns;

        if ((hit_event !== 1'b0) ||
            (wrong_hit !== 1'b0) ||
            (any_press !== 1'b0)) begin

            $error(
                "ERROR: sin pulsacion se genero un evento"
            );

        end
        else begin

            $display(
                "PASS: sin pulsacion no hay evento"
            );

        end


        //----------------------------------------------------------------------
        // PRUEBA 2
        // Comprobar las ocho posiciones correctas
        //
        // Para cada posición del topo se activa únicamente el botón
        // correspondiente.
        //
        // Resultado esperado:
        //   hit_event = 1
        //   wrong_hit = 0
        //   any_press = 1
        //----------------------------------------------------------------------

        for (i = 0; i < 8; i = i + 1) begin

            mole_position = i[2:0];

            press_pulse =
                8'b00000001 << i;

            #10ns;


            if ((hit_event !== 1'b1) ||
                (wrong_hit !== 1'b0) ||
                (any_press !== 1'b1)) begin

                $error(
                    "ERROR: posicion %0d no genero HIT correcto",
                    i
                );

            end
            else begin

                $display(
                    "PASS: posicion %0d genera HIT correcto",
                    i
                );

            end

        end


        //----------------------------------------------------------------------
        // PRUEBA 3
        // Pulsación incorrecta
        //
        // El topo activo está en la posición 5, pero se presiona el botón 2.
        //
        // Resultado esperado:
        //   hit_event = 0
        //   wrong_hit = 1
        //   any_press = 1
        //----------------------------------------------------------------------

        mole_position = 3'd5;
        press_pulse   = 8'b00000100;

        #10ns;


        if ((hit_event !== 1'b0) ||
            (wrong_hit !== 1'b1) ||
            (any_press !== 1'b1)) begin

            $error(
                "ERROR: boton incorrecto no genero wrong_hit"
            );

        end
        else begin

            $display(
                "PASS: boton incorrecto genera wrong_hit"
            );

        end


        //----------------------------------------------------------------------
        // PRUEBA 4
        // Múltiples botones presionados simultáneamente
        //
        // Se considera una entrada incorrecta aunque uno de los botones
        // coincida con la posición activa.
        //
        // Resultado esperado:
        //   hit_event = 0
        //   wrong_hit = 1
        //   any_press = 1
        //----------------------------------------------------------------------

        mole_position = 3'd2;

        // Botones 2 y 5 activos simultáneamente
        press_pulse = 8'b00100100;

        #10ns;


        if ((hit_event !== 1'b0) ||
            (wrong_hit !== 1'b1) ||
            (any_press !== 1'b1)) begin

            $error(
                "ERROR: multiples botones no fueron considerados incorrectos"
            );

        end
        else begin

            $display(
                "PASS: multiples botones se consideran incorrectos"
            );

        end


        //----------------------------------------------------------------------
        // PRUEBA 5
        // Regresar a estado sin pulsaciones
        //
        // Esto verifica que las salidas combinacionales no queden retenidas.
        //
        // Resultado esperado:
        //   hit_event = 0
        //   wrong_hit = 0
        //   any_press = 0
        //----------------------------------------------------------------------

        press_pulse = 8'b00000000;

        #10ns;


        if ((hit_event !== 1'b0) ||
            (wrong_hit !== 1'b0) ||
            (any_press !== 1'b0)) begin

            $error(
                "ERROR: las salidas quedaron activas"
            );

        end
        else begin

            $display(
                "PASS: salidas regresan correctamente a cero"
            );

        end


        //----------------------------------------------------------------------
        // Fin de las pruebas
        //----------------------------------------------------------------------

        $display(
            "---------------------------------------"
        );

        $display(
            "TODAS LAS PRUEBAS hit_evaluator PASARON"
        );

        $display(
            "---------------------------------------"
        );

        #20ns;

        $finish;

    end

endmodule