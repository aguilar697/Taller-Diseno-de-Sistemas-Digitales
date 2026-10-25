# Organización del hardware

| Carpeta | Responsable | Contenido |
|---|---|---|
| `microblaze/` | Daniel Puentes | Fuentes auxiliares de la plataforma; el Block Design se reconstruye con los scripts de Vivado |
| `pwm/` | Kevin Aguilar | Núcleo PWM, tiempo muerto, registros e interfaz AXI4-Lite |
| `adc/` | Kenneth Campos | Interfaz de adquisición ADC/XADC y lógica de disponibilidad de muestras |
| `top/` | Daniel Puentes, con revisión de interfaces | Conexión superior del sistema y adaptación de sus puertos |

Las fuentes SystemVerilog se organizan por módulo y función. Las configuraciones de IP necesarias para reconstruir el diseño se conservan como fuentes o scripts; los productos generados por Vivado pertenecen al directorio de trabajo.

Los módulos documentan puertos, dominios de reloj, polaridad de reset y parámetros. La interfaz de registros precisa offsets, permisos, valores de reset, tratamiento de bytes y efectos de cada acceso. Las modificaciones de conexiones compartidas se coordinan con los responsables indicados en el [diseño del sistema](../../docs/diseno/README.md).

Los testbenches se almacenan por separado en [src/testbench](../testbench/README.md). Los archivos de pines y temporización corresponden a `src/constraints/` y deben utilizar la tarjeta y el dispositivo seleccionados por el equipo.

[Descripción del proyecto](../../README.md)
