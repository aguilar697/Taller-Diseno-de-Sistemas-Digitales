# Verificación del motor del juego — S2

Fecha: 10 de septiembre de 2026. Responsable: Kevin Aguilar.

## Alcance

Se verificó el motor aislado: ROM, LFSR, selección y evaluación de letras.
Las pruebas no incluyen S1, UART, Python, LCD ni los dispositivos físicos.
Este documento es evidencia incremental, no el informe final del sistema.

## Simulación RTL autoverificable

Herramienta: Icarus Verilog 12.0 (devel), modo SystemVerilog `-g2012`.
Reloj del testbench: 10 ns. No se redujeron parámetros del motor para simular.

Resultado:

```text
PASS: word_engine_tb; 38612 checks, 128 games; 50 easy words and all eligible hard words covered
```

| Cobertura ejercitada | Resultado |
|---|---|
| 50 entradas, unicidad, ASCII y longitudes | PASS |
| Índices inválidos 50–63 | PASS |
| 63 estados no nulos del LFSR y retorno a semilla | PASS |
| Alcanzabilidad de 50 palabras fáciles | PASS |
| Alcanzabilidad de las 35 palabras difíciles y exclusión de cortas | PASS |
| A–Z, coincidencias múltiples y repeticiones | PASS |
| Los 230 bytes fuera de A–Z, en ambos modos | PASS |
| Patrón inicial, orden de bytes y relleno | PASS |
| Captura de dificultad, reinicio y prioridad de solicitudes | PASS |
| Fin de palabra y conservación del resultado | PASS |

Se prueban todas las fases del generador para cada modo; cada partida se
contrasta con un modelo de patrón y letras usadas. Los conteos son de
comprobaciones ejecutadas, **no una medida porcentual de cobertura de código**.

El archivo [simulation_result.txt](resultados/motor/simulation_result.txt)
conserva la salida de la ejecución. El [testbench](../../src/testbench/word_engine/word_engine_tb.sv)
contiene los criterios de fallo y un timeout global para evitar pruebas colgadas.

## Síntesis en Vivado

Herramienta: Vivado 2026.1. Dispositivo: `xc7a35tcpg236-1`.
Top: `word_engine`. Modo: out-of-context, un hilo.

| Recurso / comprobación | Resultado |
|---|---:|
| Slice LUTs, ajustadas por combinación de LUT | 384 (1.85 %) |
| Registros | 202 (0.49 %) |
| Latches | 0 |
| BRAM | 0 |
| Errores de síntesis | 0 |
| Advertencias críticas de síntesis | 0 |

La ROM se implementó como lógica LUT; no se exigió BRAM. Se comprobó además
que no hubiera celdas de latch en la netlist sintetizada.

El análisis temporal **posterior a síntesis** con un reloj de 10 ns produjo:

| Indicador | Valor |
|---|---:|
| WNS | +2.654 ns |
| TNS | 0 ns |
| WHS | +0.297 ns |
| THS | 0 ns |

Estos valores no certifican el timing del sistema integrado. El análisis no
incluye colocación y ruteo ni los retardos de entrada/salida de los otros
subsistemas. El reporte identifica 12 entradas y 92 salidas sin restricciones
de retardo. Vivado también advierte que `HD.CLK_SRC` no está definido en esta
síntesis aislada, por lo que no estima completamente el retardo/skew de reloj.
No se asignó una ubicación ficticia para ocultar esa limitación.

La consulta de latches puede emitir «No cells matched» precisamente porque
no existen celdas con ese tipo; el conteo reportado es cero.

Reportes de la ejecución (solo se normalizaron espacios finales y saltos de
línea para versionarlos; sus valores no se modificaron):

- [Utilización posterior a síntesis](resultados/motor/utilization_synth.rpt).
- [Análisis temporal posterior a síntesis](resultados/motor/timing_synth.rpt).

## Configuración de la simulación en Vivado

La reproducción de las pruebas utiliza un proyecto RTL para Basys 3
(`xc7a35tcpg236-1`) con la siguiente configuración:

| Elemento | Configuración |
|---|---|
| Fuentes de diseño | `word_engine.sv`, `word_rom.sv`, `word_lfsr.sv` y `letter_evaluator.sv` |
| Top de diseño | `word_engine` |
| Fuente y top de simulación | `word_engine_tb.sv` / `word_engine_tb` |
| Referencia del banco | `word_bank.txt` en el directorio de trabajo de simulación, normalmente `<proyecto>.sim/sim_1/behav/xsim/` |
| Tipo de simulación | Behavioral Simulation |
| Duración | Run All, hasta `$finish` o `$fatal` |
| Resultado esperado | PASS con 38 612 comprobaciones y 128 partidas |

El testbench pertenece exclusivamente al conjunto de fuentes de simulación.
La ausencia del archivo de referencia produce un error explícito al inicio.
Ese archivo no es necesario para la síntesis ni para el funcionamiento en FPGA.

Las señales de observación son `new_game`, `word_ready`, `letter_valid`,
`letter_ascii`, `letter_correct`, `letter_repeated`, `revealed_word` y
`word_complete`. Los casos de interés incluyen inicio de partida, coincidencias
múltiples, repetición de letras y revelado de la última posición pendiente.

Los reportes existentes corresponden a síntesis aislada out-of-context con
`word_engine` como top. Los recursos y tiempos pueden variar en el diseño integrado.

Para analizar tiempos debe existir una restricción de reloj de 10 ns:

```tcl
create_clock -name clk -period 10.000 [get_ports clk]
```

Las evidencias se organizan en `docs/informe/resultados/motor/`, con la
identificación de las señales y el resultado observado. La simulación funcional
registrada se ejecutó en Icarus; la simulación conductual en Vivado aún no se ha
documentado. Los reportes de síntesis sí se obtuvieron en Vivado.

## Alcance de validación pendiente

| Etapa | Criterio de verificación |
|---|---|
| Interfaces entre subsistemas | Semántica de aceptación/evaluación y entrega de palabra final a UART |
| Integración con la FSM principal | Intentos, tiempo, eventos simultáneos y descarte de letras fuera de partida |
| Implementación del sistema | Linter, implementación física y análisis temporal con los constraints de Basys 3 |
| Simulación post-implementación temporizada | Recepción UART y validación de una letra |
| Pruebas físicas | Ambas dificultades, LCD, displays, LED, buzzer y terminal |

La validación final requiere estas evidencias y el análisis de las diferencias
respecto a la verificación aislada, incluidos los problemas de integración y
sus soluciones.
