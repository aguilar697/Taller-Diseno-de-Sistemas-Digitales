# Proyecto 2 — Ahorcado

EL3313 Taller de Diseño Digital · II Semestre 2026 · Grupo 3.

Juego implementado en FPGA Basys 3 con terminal remota Python por UART a
115200 baud. La FPGA selecciona la palabra, evalúa letras, controla tiempo e
intentos y determina el resultado. La PC permite ingresar letras y muestra
las respuestas de la FPGA.

## Documentación

- [Planteamiento de diseño](docs/diseno/README.md).
- [Diagrama de primer nivel](docs/diseno/nivel_1.md).
- [Diagrama de segundo nivel](docs/diseno/nivel_2.md).
- [Tercer nivel del motor del juego](docs/diseno/nivel_3_motor_del_juego.md).
- [Cuarto nivel y FSM del motor](docs/diseno/nivel_4_motor_del_juego.md).
- [Diseño de UART y protocolo](docs/diseño/uart_protocolo.md).
- [Informe de verificación del motor](docs/informe/motor_verificacion.md).

## Responsabilidades

| Subsistema | Responsable |
|---|---|
| Control del juego y temporización | Kenneth Campos |
| Motor del juego | Kevin Aguilar |
| UART, protocolo y aplicación Python | Daniel Puentes |
| LCD e interfaz local | Kevin Cortés |

## Organización

```text
docs/
    diseno/       Diseño general y motor del juego
    diseño/       Diseño de UART
    informe/      Resultados y evidencias
src/
    design/       Módulos de cada subsistema
    testbench/    Pruebas de los módulos
```

## Motor del juego

Los cuatro archivos de `src/design/word_engine/` se agregan a Vivado como
fuentes de diseño. `word_engine_tb.sv` se agrega como fuente de simulación.
El archivo `word_bank.txt` contiene las palabras de referencia utilizadas
por el testbench. Los pasos completos están en el informe de verificación.

El motor incluye selección por dificultad, ROM de 50 palabras, LFSR,
validación, registro de letras utilizadas y actualización del patrón.
El informe incluye simulación conductual, formas de onda y reportes de síntesis
y temporización del motor aislado en Vivado. La integración con los demás
subsistemas, el cierre temporal del sistema, la simulación temporizada y las
pruebas físicas siguen pendientes.

## Trabajo colaborativo

Cada integrante trabaja en su rama, registra avances con commits descriptivos
y solicita revisión mediante Pull Request antes de integrar a `main`.
Las tareas y errores se documentan en issues asignados a sus responsables.
