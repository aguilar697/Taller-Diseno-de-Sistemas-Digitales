# Informes de verificación — Ahorcado

Los informes se organizan por subsistema. Cada documento identifica las pruebas
realizadas, sus evidencias y el alcance de los resultados.

| Subsistema | Informe | Evidencias |
|---|---|---|
| S1: control del juego y temporización | [Verificación del controlador](control_verificacion.md) | [Resultados de control](resultados/control/) |
| S2: motor del juego | [Verificación del motor](motor_verificacion.md) | [Resultados del motor](resultados/motor/) |
| S3: UART y protocolo | Pendiente de incorporar | Testbenches disponibles en `src/testbench/uart/` |
| S4: interfaz local | Pendiente de incorporar | Pendiente |

La verificación aislada de un subsistema no acredita la integración del sistema
completo. La recepción UART, la evaluación de letras, la presentación local y
las pruebas físicas se documentarán al completar esa integración.

Los reportes y las figuras se guardan en `resultados/<subsistema>/`. Los archivos
temporales de Vivado permanecen fuera de la documentación entregable.

[Diseño del sistema](../diseno/README.md) · [Proyecto 2](../../README.md)
