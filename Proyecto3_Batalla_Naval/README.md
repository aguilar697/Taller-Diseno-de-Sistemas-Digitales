# Proyecto 3 – Batalla Naval

Juego de Batalla Naval para dos jugadores ejecutado sobre un microprocesador RISC-V diseñado en FPGA.

El jugador 1 utiliza la FPGA, una pantalla VGA y botones. El jugador 2 utiliza una aplicación de PC conectada por UART. Toda la lógica del juego se ejecutará en ensamblador RISC-V y los periféricos se implementarán en SystemVerilog.

El diseño utilizará un reloj principal de 100 MHz, VGA a 640 × 480 y 60 Hz, y UART a 115200 baud.

## Organización del desarrollo

- Persona 1: CPU RISC-V y ROM.
- Persona 2: VGA, memoria de video y entradas J1.
- Persona 3: bus, RAM, UART, outputs y aplicación PC.
- Persona 4: software RISC-V y lógica de Batalla Naval.
