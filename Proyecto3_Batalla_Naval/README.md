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

## Estado de verificación

| Alcance | Estado documentado |
|---|---|
| CPU y ROM | Simulación funcional unitaria e integrada con resultados PASS; síntesis y análisis temporal pendientes |
| VGA y entradas J1 | Simulaciones unitarias e integradas, aceptación black-box 27/27, síntesis e implementación con cumplimiento temporal, y validación física de entradas y salida VGA en monitor documentadas |
| Plataforma de datos, UART y aplicación PC | Diseño de interfaces documentado; implementación y verificación pendientes de incorporar |
| Programa RISC-V | Diseño de tercer nivel documentado; cuarto nivel, programa y pruebas pendientes de incorporar |
| Juego completo | Integración, implementación y validación conjunta pendientes de documentar |

La verificación del Subsistema 2 incluye pruebas unitarias e integradas, aceptación black-box, implementación física en Basys 3 y comprobación de la salida VGA mediante monitor. Los resultados finales de utilización y temporización se encuentran documentados en el [informe de verificación del VGA y entradas del Jugador 1](docs/informe/vga_entradas_verificacion.md).

Las pruebas realizadas por subsistema tienen alcances independientes. La validación final del juego completo, incluida la simulación post-implementación temporizada del sistema, se documenta como parte de la integración conjunta del proyecto. El [índice del informe](docs/informe/README.md) reúne los resultados disponibles y los pendientes para completar la entrega.

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
