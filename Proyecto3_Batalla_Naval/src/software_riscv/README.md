# Programa del juego (Subsistema 4)

Programa en ensamblador RV32I que contiene todas las reglas de Batalla Naval.
El diseño está en [tercer nivel de la lógica del juego](../../docs/diseno/nivel_3_logica_juego.md).

| Archivo | Bloque de segundo nivel |
|---|---|
| `constantes.s` | Mapa de memoria, registros de periféricos y códigos del protocolo |
| `main.s` | Inicialización y ciclo de servicio |
| `control_estado.s` | Control de estado del juego |
| `colocacion.s` | Gestión de colocación de barcos |
| `turnos.s` | Gestión de turnos y disparos |
| `victoria.s` | Detección de hundido y victoria |
| `uart.s` | Comunicación UART |
| `salidas.s` | Actualización de periféricos de salida (VGA, LED, displays, buzzer) |
| `program.hex` | Imagen de la ROM: 2048 palabras de 32 bits, una por línea |

`program.hex` ocupa 1735 de 2048 palabras. `program_rom` lo carga con
`INIT_FILE`, y `basys3_top` lo pasa por defecto.

## Generación de `program.hex`

Esta imagen se generó con el ensamblador de la carpeta de pruebas
(`tools/asm.py`), que acepta solo el subconjunto de instrucciones que
implementa el CPU. Antes de la entrega hay que regenerarla con el toolchain
GNU acordado (`rv32i`, `ilp32`, sin relajación) y comparar el desensamblado.

Las pseudoinstrucciones `call` pueden ocupar dos palabras con el ensamblador
GNU (`auipc` + `jalr`). Con las 165 llamadas del programa, la ROM llegaría a
unas 1900 de 2048 palabras, así que todavía cabe.

## Contrato con el hardware

- UART: el programa transmite solo con `CONTROL` bit 0 en 1 (TX lista) y
  consume cada byte recibido escribiendo `CONTROL` bit 1. La UART no tiene
  FIFO, así que ninguna vuelta del ciclo de servicio supera un byte (8680
  ciclos); el redibujado de la pantalla se hace en 25 pasos, uno por vuelta.
- Buzzer: el programa solo escribe el código del suceso; el periférico define
  la duración de cada sonido.
