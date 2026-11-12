# Etapa de potencia

El inversor utiliza un puente H con PWM unipolar para regular una corriente sinusoidal de 50 Hz en una carga RL. Su alimentación de trabajo es de 12 a 24 V DC y las referencias nominales son 0,2; 0,5 y 1 A pico.

Esta documentación corresponde a EL4201 Procesamiento Electrónico de Potencia. Sus integrantes son Kevin Aguilar, Kenneth Campos y Kevin Cortés. La conexión con la plataforma de Taller de Diseño Digital se coordina también con Daniel Puentes.

## Estado del desarrollo

Se realizaron simulaciones exploratorias del puente ideal en lazo abierto y con un PR continuo. Se añadieron copias con PR discreto y un modelo funcional que incorpora resistencia de conducción, tiempo muerto y medición nominal cuantizada. Se dispone de cuatro IRF540N, dos IR2110 DIP-14, un módulo ACS712 de 5 A, tres resistencias de 3,3 Ω y 5 W y un transformador cuyo secundario se propone como inductancia de carga. Falta completar el circuito de accionamiento, comprobar el acondicionamiento para XADC, cerrar la protección y validar el montaje físico.

| Documento | Contenido |
|---|---|
| [Diseño y componentes](01_diseno_y_componentes.md) | Configuración, materiales disponibles, mediciones del devanado, carga, margen de tensión e interfaces |
| [Simulación y resultados](02_simulacion_y_resultados.md) | Ensayos ideales, configuración de los archivos PLECS, controlador inicial y análisis numéricos |
| [Pendientes y validación](03_pendientes_y_validacion.md) | Decisiones por cerrar, secuencia de trabajo y criterios del instructivo |

La inductancia del secundario se midió a 120 Hz y 1 kHz; aún no se ha caracterizado a la corriente de operación. Los modelos actuales utilizan una inductancia lineal y no validan por sí solos su comportamiento físico.

Los archivos PLECS originales se conservan sin editar. Las copias nuevas permiten evaluar algunas no idealidades, pero aún faltan parámetros medidos y efectos físicos, como ruido, bootstrap y comportamiento magnético. La validación del circuito comprado sigue pendiente.

## Archivos del proyecto

- [Modelos de PLECS y herramientas de análisis](../modelos/README.md).
- [Diseño digital e interfaces](../docs/diseno/README.md).
- [Organización del informe y evidencias](../docs/informe/README.md).
- [Borradores de diseño e informe de Potencia](../docs/informe/potencia/README.md).
- [Instructivo](../docs/enunciado/Proyecto_4_EL3313__Taller_de_Diseño_Digital.pdf).

[Descripción del proyecto](../README.md)
