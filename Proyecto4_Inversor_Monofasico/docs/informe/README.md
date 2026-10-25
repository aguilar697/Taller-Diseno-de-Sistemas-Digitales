# Documentación de resultados

El informe técnico reúne la fundamentación, las decisiones de diseño, los resultados y las conclusiones del sistema de control de corriente. Relaciona el comportamiento de la plataforma digital con el modelo y las mediciones de la etapa de potencia.

## Organización del informe

| Apartado | Contenido |
|---|---|
| Fundamentación | MicroBlaze V, AXI4-Lite, PWM unipolar, adquisición, tiempo real, carga RL y control PR |
| Solución implementada | Arquitectura, interfaces, registros, parámetros, modelos y ecuación discreta |
| Verificación digital | Pruebas autoverificables, simulación temporizada del PWM, recursos y análisis temporal |
| Resultados experimentales | Seguimiento de corriente, cambios de referencia y carga, temporización y exportación UART |
| Análisis | Comparación entre teoría, PLECS y mediciones; error, fase, rizado, retardos y limitaciones |
| Conclusiones | Relación entre objetivos, resultados y lecciones obtenidas |

Cada responsable aporta el análisis y las evidencias de su subsistema. Los resultados de integración identifican las versiones de hardware, software y parámetros utilizados en el ensayo.

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
