# Informes y evidencias por curso

El proyecto tiene evaluaciones independientes en EL3313 Taller de Diseño Digital y EL4201 Procesamiento Electrónico de Potencia. Cada curso tiene documentos con objetivos, integrantes, análisis y conclusiones propios. Taller conserva su informe en Markdown. Para Potencia se preparan un documento de diseño y un informe técnico en la carpeta potencia/. Los modelos y las mediciones compartidas se citan desde su ubicación original para evitar versiones distintas de una misma evidencia.

| Curso | Integrantes | Documento final previsto | Diseño de referencia |
|---|---|---|---|
| Taller de Diseño Digital | Daniel Puentes, Kevin Aguilar, Kenneth Campos y Kevin Cortés | `informe_digitales.md` | [Arquitectura e interfaces](../diseno/README.md) |
| Procesamiento Electrónico de Potencia | Kevin Aguilar, Kenneth Campos y Kevin Cortés | [Diseño e informe técnico](potencia/README.md) | [Etapa de potencia y control](../../Potencia/README.md) |

El documento de diseño y el informe de Potencia tienen borradores PDF con fuentes editables; los apartados experimentales siguen pendientes. El formato IEEE se propone para Potencia, sujeto a las indicaciones adicionales del docente: la sección 8.2 y el anexo B no lo exigen expresamente. El anexo A sí establece Markdown para Taller. Los requisitos proceden de las secciones 7, 8 y anexos A y B del [instructivo](../enunciado/Proyecto_4_EL3313__Taller_de_Diseño_Digital.pdf).

## Evaluación de Taller de Diseño Digital

| Rubro | Peso | Evidencia principal |
|---|---|---|
| Diseño | 20 % | Diagramas, objetivos, registros, interfaces, decisiones y estrategia de verificación |
| Presentación funcional | 60 % | MicroBlaze V, PWM personalizado, adquisición sincronizada, PR integrado, UART y defensa técnica |
| Informe | 10 % | Fundamentación, resultados, análisis, conclusiones y organización |
| Repositorio y trazabilidad | 10 % | Fuentes, instrucciones de construcción, commits, ramas, issues y revisiones |

El informe digital debe incluir los testbenches autoverificables, casos de borde, simulación postimplementación temporizada del PWM, utilización de recursos, restricciones y resultados de timing. También debe documentar el período real del control, su jitter y la exportación del histórico sin interrumpir el lazo. El repositorio ya contiene el software de control en C, los drivers, sus pruebas y la aplicación de PC. Siguen pendientes la integración de los bloques RTL y la plataforma reconstruible, así como los resultados de implementación y ensayo del sistema completo.

## Evaluación de Procesamiento Electrónico de Potencia

| Rubro | Peso | Evidencia principal |
|---|---|---|
| Diseño e investigación | 20 % | Puente H, carga, pérdidas, frecuencia PWM, modelo RL y diseño justificado del PR discreto |
| Presentación funcional propia | 50 % | Inversor construido con PR discreto, seguimiento nominal y cambios de referencia y carga |
| Integración con Taller | 20 % | Medición, MicroBlaze V, PWM, accionamiento y ensayos conjuntos |
| Informe | 10 % | Parámetros reales, modelos PLECS, registros experimentales y comparación cuantitativa |

La sección 8.2 permite evaluar hasta 80 puntos de PEDP sin que concluya MicroBlaze V, utilizando una plataforma digital alternativa si hace falta. Esos puntos requieren demostrar físicamente el inversor con PR discreto en lazo cerrado; una simulación por sí sola no sustituye la demostración. Los 20 puntos de integración se califican aparte. PEDP exige archivos reproducibles, pero no tiene un rubro independiente de historial Git.

El [plan de potencia](../../Potencia/03_pendientes_y_validacion.md) identifica las evidencias disponibles y las pendientes. La caracterización del sensor, el montaje con los componentes comprados, la implementación física del controlador discreto y las mediciones finales siguen pendientes. La simulación del PR discreto y de la copia funcional ya dispone de resultados reproducibles.

## Contenido de los informes

| Apartado | Taller de Diseño Digital | Procesamiento Electrónico de Potencia |
|---|---|---|
| Fundamentación | Procesamiento, AXI, PWM, adquisición y tiempo real | Puente H, carga RL, medición y control PR |
| Solución implementada | Plataforma, registros, FSM, ISR, buffer y UART | Circuito, accionamiento, parámetros, pérdidas y ecuación discreta |
| Resultados | Autochequeo, simulación temporizada, recursos, timing y demostración | PLECS y mediciones de seguimiento, cambios de consigna y carga |
| Análisis | Latencias, jitter, errores numéricos y comportamiento de las interfaces | Fundamental, fase, rizado, transitorios y diferencias simulación–laboratorio |
| Conclusiones | Cumplimiento respaldado por las pruebas digitales e integradas | Cumplimiento respaldado por los cálculos, simulaciones y ensayos físicos |

Cada responsable aporta el análisis y las evidencias de su subsistema. Los resultados de integración identifican las versiones de hardware, software y parámetros utilizados en el ensayo.

## Análisis disponibles

- [Simulación de potencia y control](../../Potencia/02_simulacion_y_resultados.md): modelos ideales de PLECS, configuración guardada y alcance de los ensayos exploratorios.
- [Análisis numéricos](../../modelos/analisis/README.md): barrido inicial de 144 escenarios de rizado y comprobación lineal del PR. Los datos conservados corresponden a cálculos, no a mediciones físicas.

## Evidencias

Las evidencias se conservan en `resultados/`, agrupadas por subsistema o ensayo. Cada registro identifica el montaje, los valores de R y L, la alimentación, las frecuencias, el período de control, las unidades y el método de medición que corresponda. Las figuras indican señales, escalas y condiciones de prueba.

Las simulaciones incluyen los estímulos, las referencias utilizadas para el autochequeo y el diagnóstico de paso o fallo. Las mediciones físicas se presentan con sus condiciones de adquisición; los reportes de implementación identifican el módulo superior y las restricciones analizadas.

## Ensayos de corriente

| Ensayo o indicador | Condición de evaluación |
|---|---|
| Seguimiento estacionario | Referencias de 0,2; 0,5 y 1,0 A pico a 50 Hz |
| Cambio de referencia | Transiciones de 0,2 a 0,5 A y de 0,5 a 1,0 A pico |
| Cambio de carga | Variación de resistencia externa de al menos 25 %, conservando L y referencia de 0,5 A pico |
| Amplitud de la fundamental | Error relativo máximo de 10 % en los puntos estacionarios nominales |
| Ventana de análisis | Al menos cinco períodos completos de 50 Hz para extraer la fundamental |
| Fase | Medición del desfase respecto a la referencia |
| Rizado de conmutación | Máximo de 0,20 A pico a pico, separado de la componente de baja frecuencia |

Los transitorios se analizan mediante su evolución, establecimiento y respeto de los límites eléctricos. La corriente, la referencia, la tensión de carga y las señales PWM forman parte de las evidencias de cada ensayo.

[Diseño del sistema](../diseno/README.md) · [Descripción del proyecto](../../README.md)
