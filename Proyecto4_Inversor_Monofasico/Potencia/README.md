# Etapa de potencia

El inversor emplea un puente H con cuatro IRF540N, dos IR2110 y un ACS712 de 5 A. La carga nominal combina 6,6 Ω externos con el secundario de un transformador. El objetivo es regular corriente sinusoidal de 50 Hz con un bus de 12 a 24 V y consignas de 0,2, 0,5 y 1 A pico.

En PLECS se ensayaron las tres consignas y los transitorios de referencia y carga con un PR discreto. El montaje físico operó en lazo cerrado con el devanado de reemplazo. Las mediciones del XADC cumplen el criterio de amplitud a 0,2 A pico con 12 y 24 V y a 0,5 A pico con 24 V. A 1 A pico la modulación alcanzó su límite y la corriente quedó por debajo de la consigna. La validación física permanece abierta para el escalón hacia 1 A, el rizado y el contraste independiente de la escala del sensor.

El [esquemático completo](img/esquematico_inversor.svg) muestra los cuatro interruptores S1–S4, ambos IR2110, la carga y el sensado. Los [estados del puente](01_diseno_y_componentes.md#topología-y-alimentaciones) y la [asignación de pines](../docs/diseno/integracion_basys3.md#conexiones) detallan su funcionamiento y cableado.

| Documento | Contenido |
|---|---|
| [Diseño y componentes](01_diseno_y_componentes.md) | Circuito, fuentes, selección de componentes, cálculos e interfaz con Basys 3 |
| [Simulación y resultados](02_simulacion_y_resultados.md) | Modelos PLECS, condiciones, tolerancias y resultados |
| [Registro de laboratorio](04_registro_laboratorio.md) | Puesta en marcha, cambios del montaje, ensayos en lazo cerrado y diagnóstico de fallas |
| [Estado de validación](03_pendientes_y_validacion.md) | Criterios de aceptación, evidencia disponible y mediciones por completar |

[Documentos de EL4201 en PDF y archivos de reproducción](../docs/informe/potencia/README.md). El diseño de Potencia corresponde a Kevin Aguilar, Kenneth Campos y Kevin Cortés. Daniel Puentes participa en la integración de Taller de Diseño Digital.
