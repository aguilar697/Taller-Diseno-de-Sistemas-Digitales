# Verificación del hardware

Los bancos de prueba se organizan por subsistema y utilizan comprobaciones automáticas con resultados esperados. Una discrepancia o un tiempo de espera excedido debe producir un diagnóstico y finalizar la prueba con error.

| Carpeta | Responsable | Cobertura |
|---|---|---|
| `pwm/` | Kevin Aguilar | Generación PWM, tiempo muerto, interfaz AXI4-Lite y disparo de adquisición |
| `adc/` | Kenneth Campos | Inicio de conversión, muestras conocidas, disponibilidad y sincronización |
| `integration/` | Responsables de los bloques conectados, coordinados por Daniel Puentes | Transacciones, interrupciones y relación temporal entre adquisición y actuación |

## PWM

- Lectura y escritura de registros, valores de reset y escrituras por bytes.
- Canales AXI de dirección y datos de escritura con distintos instantes de llegada, y respuestas bajo espera del receptor.
- Frecuencias seleccionables, referencia y saturación en los límites definidos.
- Tiempo muerto y ausencia de solapamiento lógico entre señales complementarias de cada rama.
- Habilitación, deshabilitación y cambios de configuración según la política documentada.
- Instante y duración del disparo de adquisición.
- Comportamiento del periférico después de implementación mediante simulación temporizada.

## Adquisición e integración

Las pruebas de adquisición distinguen el disparo de conversión de la disponibilidad del resultado. La integración comprueba que el software obtiene muestras válidas y actualiza la actuación conforme al período de control. Se registran las latencias y el comportamiento ante conversiones pendientes o muestras no consumidas.

Los modelos de simulación identifican sus simplificaciones. Los comandos y dependencias de cada prueba se incorporan junto con su banco y los [scripts de verificación](../../scripts/README.md). Las evidencias seleccionadas se documentan en el [informe](../../docs/informe/README.md).

[Descripción del proyecto](../../README.md)
