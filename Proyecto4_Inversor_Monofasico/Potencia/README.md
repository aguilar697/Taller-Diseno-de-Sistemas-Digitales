# Etapa de potencia

El inversor emplea un puente H con cuatro IRF540N, dos IR2110 y un ACS712 de 5 A. La carga nominal combina 6,6 Ω externos con el secundario de un transformador. El objetivo es regular corriente sinusoidal de 50 Hz con un bus de 12 a 24 V y consignas de 0,2, 0,5 y 1 A pico.

En la campaña final se registraron los dos escalones de referencia y un cambio de carga. Con 12 V fijos y 7,3 Ω DC entre A y B, las referencias de 0,20, 0,50 y 1,00 A pico dieron fundamentales de 176, 390 y 337 mA pico por UART. Los cinco puntos evaluados quedaron fuera de ±10 % y se observó saturación a 0,50 y 1,00 A. [Mediciones de la campaña final](mediciones_lab_osciloscopio/final_82a8226_12V/README.md).

El [esquemático completo](img/esquematico_inversor.svg) muestra los cuatro interruptores S1–S4, ambos IR2110, la carga y el sensado. Los [estados del puente](01_diseno_y_componentes.md#topología-y-alimentaciones) y la [asignación de pines](../docs/diseno/integracion_basys3.md#conexiones) detallan su funcionamiento y cableado.

| Documento | Contenido |
|---|---|
| [Diseño y componentes](01_diseno_y_componentes.md) | Circuito, fuentes, selección de componentes, cálculos e interfaz con Basys 3 |
| [Simulación y resultados](02_simulacion_y_resultados.md) | Modelos PLECS, condiciones, tolerancias y resultados |
| [Registro de laboratorio](04_registro_laboratorio.md) | Puesta en marcha, cambios del montaje, ensayos en lazo cerrado y diagnóstico de fallas |
| [Estado de validación](03_pendientes_y_validacion.md) | Criterios de aceptación, evidencia disponible y mediciones por completar |

[Documentos de EL4201 en PDF y archivos de reproducción](../docs/informe/potencia/README.md). El diseño de Potencia corresponde a Kevin Aguilar, Kenneth Campos y Kevin Cortés. Daniel Puentes participa en la integración de Taller de Diseño Digital.
