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
PASS: 50 valid distinct words; RTL matches the bank
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
- [Hashes SHA-256 de fuentes verificadas](resultados/motor/source_sha256.txt).

## Reproducción

Desde la raíz del repositorio:

```text
python Proyecto2_Ahorcado/scripts/test_word_engine.py
python Proyecto2_Ahorcado/scripts/synth_word_engine.py
```

La síntesis inicial desde la ruta del repositorio encontró problemas de manejo
de rutas y un cierre prematuro. El procedimiento reproducible usa una copia
temporal de las mismas fuentes, con un hilo, y recupera los reportes. Esto
permitió completar la síntesis; no se atribuye una causa única al cierre previo.

## Validación que falta para la entrega final

1. Revisar con los otros integrantes la semántica de aceptación/evaluación y
   resolver la entrega de la palabra final hacia UART.
2. Integrar el motor con la FSM de partida y probar intentos, tiempo y eventos
   simultáneos; verificar que una letra fuera de partida no se procese después.
3. Ejecutar linter, implementación física y análisis temporal del top completo
   con los constraints de la Basys 3.
4. Presentar simulación **post-implementación temporizada** que incluya recepción
   UART y validación de una letra, como solicita el instructivo.
5. Probar en hardware ambas dificultades, LCD, displays, LED, buzzer y terminal.

El informe final debe incorporar esas evidencias, discutir las diferencias con
esta verificación aislada y registrar problemas de integración y sus soluciones.
