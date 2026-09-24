# Planteamiento de diseño — Batalla Naval

El diseño se organiza mediante descomposición modular: el primer nivel presenta el sistema y su entorno; el segundo identifica los bloques principales y sus interconexiones. El tercer nivel descompone cada subsistema en funciones, y el cuarto desarrolla sus circuitos o procedimientos internos.

## Diagramas generales

- [Primer nivel: sistema, entradas y salidas](nivel_1.md).
- [Segundo nivel: arquitectura e interconexiones](nivel_2.md).

## Diseño por subsistema

| Subsistema | Responsable | Tercer nivel | Cuarto nivel |
|---|---|---|---|
| 1. CPU RISC-V y ROM | Kevin Aguilar | [Arquitectura del núcleo](nivel_3_cpu.md) | [Datapath, ROM y control](nivel_4_cpu.md) |
| 2. VGA y entradas J1 | Kenneth Campos | [Bloques e interfaces](nivel_3_vga_entradas.md) | [Video, memoria y entradas](nivel_4_vga_entradas.md) |
| 3. Plataforma de datos, UART y PC | Daniel Puentes | [Bus, memorias y periféricos](nivel_3_uart.md) | [Bus, RAM, UART y salidas](nivel_4_uart.md) |
| 4. Lógica del juego en ensamblador | Kevin Cortés | [Organización del software](nivel_3_logica_juego.md) | **EN PROCESO** |

## Organización documental

Los niveles generales se nombran `nivel_1.md` y `nivel_2.md`. Los documentos de subsistema utilizan `nivel_3_<subsistema>.md` y `nivel_4_<subsistema>.md`. Las imágenes se almacenan en `img/`, con nombres que identifican el nivel, el subsistema y, cuando corresponde, la vista representada.

Las fuentes se distribuyen por bloque en `src/design/`, las pruebas en `src/testbench/`, el programa ensamblador en `src/software_riscv/` y la aplicación remota en `src/software_pc/`. Las reglas de Batalla Naval se ejecutan en el CPU; los periféricos y la terminal de PC representan el estado comunicado por el programa.

Los resultados y sus evidencias se documentan en el [informe técnico](../informe/README.md).

[Descripción del proyecto](../../README.md)
