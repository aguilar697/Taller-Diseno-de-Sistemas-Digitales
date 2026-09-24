# Proyecto 3 — Batalla Naval

Juego de Batalla Naval para dos jugadores sobre un procesador RISC-V implementado en FPGA. El Jugador 1 utiliza la Basys 3, una pantalla VGA y controles físicos; el Jugador 2 utiliza una aplicación de PC conectada por UART.

Toda la lógica del juego corresponde al programa ensamblador RISC-V. La plataforma utiliza un reloj principal de 100 MHz, salida VGA de 640 × 480 a 60 Hz nominales y UART a 115200 baud.

## Organización del desarrollo

| Subsistema | Responsable | Alcance |
|---|---|---|
| 1. CPU y ROM | Kevin Aguilar | Procesador RISC-V, memoria de instrucciones y pruebas del núcleo |
| 2. VGA y entradas J1 | Kenneth Campos | Memoria de video, reloj de píxel, generación gráfica y acondicionamiento de controles |
| 3. Plataforma de datos y PC | Daniel Puentes | Bus, RAM, UART, displays, LED, buzzer y aplicación del Jugador 2 |
| 4. Software del juego | Kevin Cortés | Programa de Batalla Naval en ensamblador RISC-V |

## Documentación

- [Índice del planteamiento de diseño](docs/diseno/README.md).
- [Primer nivel: sistema y entorno](docs/diseno/nivel_1.md).
- [Segundo nivel: arquitectura e interconexiones](docs/diseno/nivel_2.md).
- [Informe técnico y verificación](docs/informe/README.md).

| Subsistema | Tercer nivel | Cuarto nivel |
|---|---|---|
| CPU y ROM | [Arquitectura](docs/diseno/nivel_3_cpu.md) | [Datapath y control](docs/diseno/nivel_4_cpu.md) |
| VGA y entradas J1 | [Bloques e interfaces](docs/diseno/nivel_3_vga_entradas.md) | [Desarrollo interno](docs/diseno/nivel_4_vga_entradas.md) |
| Plataforma de datos, UART y PC | [Arquitectura](docs/diseno/nivel_3_uart.md) | [Bus, RAM y periféricos](docs/diseno/nivel_4_uart.md) |
| Lógica del juego | [Organización del software](docs/diseno/nivel_3_logica_juego.md) | **EN PROCESO** |

## Implementación del CPU y la ROM

- [Módulos e interfaces del núcleo](src/design/cpu/README.md).
- [Testbenches y ejecución en Vivado](src/testbench/cpu/README.md).
- [Informe de verificación del CPU y la ROM](docs/informe/cpu_verificacion.md).

## Estructura

| Carpeta | Contenido |
|---|---|
| `docs/diseno/` | Arquitectura, diagramas e interfaces |
| `docs/informe/` | Análisis de resultados y evidencias de verificación |
| `src/design/` | Módulos RTL organizados por bloque |
| `src/testbench/` | Pruebas unitarias y de integración |
| `src/constraints/` | Restricciones de reloj y asignación de pines |
| `src/software_riscv/` | Programa ensamblador del juego |
| `src/software_pc/` | Aplicación remota del Jugador 2 |

[Repositorio del curso](../README.md)
