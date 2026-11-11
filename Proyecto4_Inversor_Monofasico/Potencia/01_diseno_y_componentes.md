# Etapa de potencia y componentes

## Configuración del circuito

La etapa propuesta es un puente H alimentado entre 12 y 24 V DC, con cuatro MOSFET de canal N y una carga RL en serie. La modulación unipolar aplica a la carga niveles de tensión positivos, negativos y cero. La inductancia limita la variación de corriente entre conmutaciones y el controlador PR ajusta la modulación para seguir una referencia sinusoidal de 50 Hz.

La cadena de control es:

```text
Referencia de corriente → PR → PWM con tiempo muerto → drivers → puente H → carga RL
                         ↑                                                   │
                         └── XADC ← acondicionamiento ← ACS712 ←──────────────┘
```

El PR y la adquisición pertenecen a los subsistemas de control y medición. La etapa de potencia debe proporcionar señales compatibles con esas interfaces; la simulación continua es una primera aproximación a su comportamiento.

## Componentes disponibles

| Cantidad | Componente | Función y criterio de elección |
|---|---|---|
| 4 | IRF540N | Dos interruptores por rama del puente H; encapsulado adecuado para montaje y margen nominal de tensión respecto al bus de 24 V |
| 1 | Módulo ACS712 de 5 A | Medición bidireccional de corriente en serie con la carga, sin añadir un amplificador de shunt conectado a los nodos conmutados |
| 3 | Resistencia de 3,3 Ω y 5 W | Dos unidades forman la carga nominal de 6,6 Ω; la tercera permite aumentarla a 9,9 Ω |
| 1 | Secundario de transformador | Elemento inductivo disponible; se utiliza con el primario abierto y sus terminales aislados |

Los drivers, el acondicionamiento analógico y los elementos auxiliares de alimentación y protección todavía no tienen una selección final.

### MOSFET y accionamiento

El IRF540N tiene una tensión nominal drenador–fuente de 100 V. Su resistencia de conducción se especifica con 10 V entre compuerta y fuente; el umbral de encendido no equivale a una tensión de accionamiento suficiente. Por ello, las salidas de 3,3 V de la FPGA deben pasar por drivers. El margen nominal de tensión no elimina la necesidad de revisar los transitorios del montaje. [Hoja de datos IRF540N](https://www.infineon.com/assets/row/public/documents/24/49/infineon-irf540n-datasheet-en.pdf).

Se requieren dos drivers de medio puente. El IR2101 es un candidato por disponibilidad local y el IR2110 es una alternativa. La elección se cerrará según compatibilidad lógica, carga de compuerta, tiempos de conmutación, alimentación y disponibilidad. El IR2110 no se considera obligatorio únicamente por tener mayor capacidad de accionamiento. Las características se deben comprobar para la referencia y el fabricante adquiridos. [IR2101](https://www.infineon.com/part/IR2101?ispn-redirect=IR2101) · [IR2110](https://www.infineon.com/assets/row/public/documents/non-assigned/49/infineon-ir2110-datasheet-en.pdf).

El esquema final incluirá alimentación regulada para los drivers, bootstrap para los interruptores superiores si se utiliza esta solución, desacoplo local, resistencias de compuerta y resistencias compuerta–fuente para mantener el apagado. Los valores y el tiempo muerto se fijarán con el driver elegido. No se conectarán directamente los MOSFET a los pines de la FPGA.

### Devanado utilizado como inductancia

Las mediciones disponibles corresponden al secundario, con el primario abierto:

| Magnitud | Valor observado |
|---|---|
| Inductancia a 120 Hz | 9,291 mH |
| Inductancia a 1 kHz | 6,984 mH |
| Resistencia del devanado | Aproximadamente 0,6 Ω |

Estas mediciones no permiten extrapolar un valor preciso a 50 Hz ni determinar cómo cambia la inductancia con la corriente. El valor de 10 mH es una aproximación de diseño; el modelo PLECS guardado utiliza 9,3 mH constantes. La corriente nominal indicada de 3 A para el transformador no acredita que el devanado se comporte como una inductancia lineal hasta esa corriente.

La viabilidad se comprobará observando la corriente, el calentamiento y la respuesta a los puntos de operación. El primario permanecerá abierto, con los terminales aislados: aunque no se conecte a una fuente, puede aparecer tensión inducida en él.

## Carga y margen de tensión

Con dos resistencias en serie, la resistencia total aproximada es:

```math
R_{total}=6{,}6+0{,}6=7{,}2\ \Omega.
```

Para una corriente sinusoidal, el modelo RL lineal requiere una amplitud de tensión:

```math
V_{1,pk}=I_{pk}\sqrt{R_{total}^{2}+(2\pi fL)^2}.
```

Con 50 Hz y L = 9,3 mH, la magnitud de la impedancia es aproximadamente 7,77 Ω. En el puente ideal, la amplitud del índice de modulación es aproximadamente V₁,pk/Vdc:

| Referencia, A pico | Tensión requerida, V pico | Modulación a 12 V | Modulación a 24 V |
|---|---|---|---|
| 0,2 | 1,55 | 0,130 | 0,065 |
| 0,5 | 3,89 | 0,324 | 0,162 |
| 1,0 | 7,77 | 0,648 | 0,324 |

El cálculo indica margen de tensión para los tres puntos nominales con la carga propuesta. No incluye caídas de semiconductores, tiempo muerto ni pérdidas del núcleo. El límite de modulación utilizado en la simulación inicial es ±0,85.

A 1 A pico sinusoidal, la corriente eficaz es 0,707 A. Cada resistencia de 3,3 Ω disipa aproximadamente 1,65 W y el devanado disipa 0,30 W por resistencia de cobre. La potencia nominal de 5 W ofrece margen para ese punto, sujeto a las condiciones de montaje y temperatura; las pérdidas magnéticas se evaluarán aparte.

La tercera resistencia aumenta la resistencia externa de 6,6 a 9,9 Ω, un 50 %, manteniendo la misma inductancia. Este cambio permite ensayar el requisito de variación de carga con referencia de 0,5 A pico. La conmutación debe insertar o puentear esa resistencia sin interrumpir el camino de corriente inductiva.

## Medición e interfaz con la Basys 3

El camino de corriente del ACS712 se conecta en serie con la carga. Para la versión de 5 A, alimentada a 5 V, la salida nominal es aproximadamente:

```math
V_{sensor}=2{,}5+0{,}185\,i_L
```

con tensión en voltios y corriente en amperios. A ±1 A, esto representa aproximadamente 2,315–2,685 V. El cero y la sensibilidad reales se deben calibrar en el módulo adquirido. [Hoja de datos ACS712](https://www.allegromicro.com/-/media/Files/Datasheets/ACS712-Datasheet.ashx).

La salida del sensor no se conectará directamente al XADC. El acondicionamiento debe adaptar el rango de tensión, conservar el signo de la corriente mediante un nivel de referencia, filtrar ruido y limitar la tensión aplicada a la entrada. Su ganancia, offset y retardo deben coordinarse con el subsistema ADC y el PR. La calidad de la medición se verificará también a 0,2 A pico, donde la variación de salida del sensor es menor.

## Protección y puesta en marcha

Se propone un montaje con limitación de corriente de la fuente de laboratorio, fusible en la alimentación DC y desconexión manual. El accionamiento debe garantizar apagado durante reset y ausencia de conducción simultánea en cada rama mediante tiempo muerto. Los valores del fusible, los límites de corriente y la respuesta ante fallos quedan por definir con el circuito final.

El desacoplo del bus y de los drivers forma parte del montaje. La necesidad de diodos adicionales o redes de amortiguamiento se decidirá según los caminos de recirculación, el tiempo muerto y los transitorios medidos; no se incorporan como componentes ya seleccionados. Antes de energizar el puente se comprobarán las señales de compuerta y su referencia de tensión.

[Potencia](README.md) · [Simulación](02_simulacion_y_resultados.md) · [Pendientes](03_pendientes_y_validacion.md)
