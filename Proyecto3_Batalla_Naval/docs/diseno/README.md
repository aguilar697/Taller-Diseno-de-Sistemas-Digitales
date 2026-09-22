# Planteamiento de diseño — Batalla Naval

El diseño se organiza mediante descomposición modular: el primer nivel presenta el sistema y su entorno; el segundo identifica los bloques principales y sus interconexiones. El detalle de datapath, FSM, registros y circuitos corresponde a los niveles posteriores.

## Diagramas generales

- [Primer nivel: sistema, entradas y salidas](nivel_1.md).
- [Segundo nivel: procesador, memorias y periféricos](nivel_2.md).
- [Subsistema 2: VGA y entradas del Jugador 1](subsistema_2_nivel_2.md).

Cada nivel presenta el diagrama correspondiente y desarrolla su objetivo, interfaces y funcionamiento.

## Subsistemas

- [Tercer nivel: procesador RISC-V y ROM](nivel_3_cpu.md).

## Organización

La plataforma contiene CPU RISC-V, ROM, RAM, bus de datos y periféricos de video, comunicación y entrada/salida. Las reglas de Batalla Naval se implementan en ensamblador y se ejecutan en el CPU. La aplicación de PC funciona como terminal del Jugador 2.

Las fuentes se distribuyen por bloque en `src/design/`, las pruebas en `src/testbench/`, el programa ensamblador en `src/software_riscv/` y la aplicación remota en `src/software_pc/`.

[Descripción del proyecto](../../README.md)

