# Etapa de potencia

El inversor emplea un puente H con cuatro IRF540N, dos IR2110 y un ACS712 de 5 A. La carga nominal combina 6,6 Ω externos con el secundario de un transformador. El objetivo es regular corriente sinusoidal de 50 Hz con un bus de 12 a 24 V y consignas de 0,2, 0,5 y 1 A pico.

En PLECS se ensayaron las tres consignas y los transitorios de referencia y carga con un PR discreto. En el montaje se verificaron el PWM, las salidas inferiores de los drivers, la conmutación a 3 V y el cero del XADC. La respuesta al sondeo abierto quedó por debajo de la estimación del modelo RL y el programa deshabilitó el PWM antes de ejecutar el PR. Quedan pendientes la calibración de la corriente y la operación en lazo cerrado en el rango nominal.

| Documento | Contenido |
|---|---|
| [Diseño y componentes](01_diseno_y_componentes.md) | Circuito, fuentes, selección de componentes, cálculos e interfaz con Basys 3 |
| [Simulación y resultados](02_simulacion_y_resultados.md) | Modelos PLECS, condiciones, tolerancias y resultados |
| [Registro de laboratorio](04_registro_laboratorio.md) | Lecturas del puente, retorno del XADC y diagnóstico del sondeo |
| [Verificación pendiente](03_pendientes_y_validacion.md) | Ensayos, criterios de aceptación y medidas requeridas |

[Documentos de EL4201 en PDF y archivos de reproducción](../docs/informe/potencia/README.md). El diseño de Potencia corresponde a Kevin Aguilar, Kenneth Campos y Kevin Cortés. Daniel Puentes participa en la integración de Taller de Diseño Digital.
