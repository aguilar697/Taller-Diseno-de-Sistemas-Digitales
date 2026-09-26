module pixel_clock (
    input  logic clk_100_i,
    input  logic rst_i,

    output logic clk_pixel_o,
    output logic locked_o
);

    // -------------------------------------------------------------------------
    // Pixel clock generator
    // -------------------------------------------------------------------------
    // El Clocking Wizard utiliza un MMCM dedicado del Artix-7 para convertir
    // el reloj principal de 100 MHz de la Basys 3 en el reloj VGA de 25 MHz.
    //
    // locked_o indica que el MMCM alcanzó una condición estable y que el reloj
    // de salida puede utilizarse de forma segura por el dominio VGA.
    pixel_clock_wiz u_pixel_clock_wiz (
        .clk_in1  (clk_100_i),
        .reset    (rst_i),
        .clk_out1 (clk_pixel_o),
        .locked   (locked_o)
    );

endmodule