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
| 2 | IR2110 DIP-14, integrados sueltos | Un driver por rama para accionar sus MOSFET superior e inferior |
| 1 | Módulo ACS712 de 5 A | Medición bidireccional de corriente en serie con la carga, sin añadir un amplificador de shunt conectado a los nodos conmutados |
| 3 | Resistencia de 3,3 Ω y 5 W | Dos unidades forman la carga nominal de 6,6 Ω; la tercera permite aumentarla a 9,9 Ω |
| 1 | Secundario de transformador | Elemento inductivo disponible; se utiliza con el primario abierto y sus terminales aislados |

Se dispone de los dos IR2110 en encapsulado DIP-14 necesarios para el puente, uno por rama. El acondicionamiento analógico y los elementos auxiliares de alimentación y protección permanecen en diseño.

### MOSFET y accionamiento

El IRF540N tiene una tensión nominal drenador–fuente de 100 V. Su resistencia de conducción se especifica con 10 V entre compuerta y fuente; el umbral de encendido no equivale a una tensión de accionamiento suficiente. Por ello, las salidas de 3,3 V de la FPGA deben pasar por drivers. El margen nominal de tensión no elimina la necesidad de revisar los transitorios del montaje. [Hoja de datos IRF540N](https://www.infineon.com/assets/row/public/documents/24/49/infineon-irf540n-datasheet-en.pdf).

Se selecciona el IR2110 por disponibilidad y por disponer de dos canales independientes, alimentación lógica separada y salida flotante para el MOSFET superior. Cada unidad acciona una rama, no los cuatro MOSFET. La referencia adquirida corresponde a [IR2110 DIP-14](https://componenteselectronicoscr.com/product/ir2110-circuito-integrado-high-and-low-side-driver-mosf); sus conexiones eléctricas se toman de la [hoja de datos del fabricante](https://www.infineon.com/assets/row/public/documents/24/49/infineon-ir2110-datasheet-en.pdf).

La propuesta utiliza `VDD=3,3 V` para la lógica y `VCC=12 V` regulados para el accionamiento. Con VDD a 3,3 V, HIN y LIN reciben las señales de la Basys 3; alimentar VDD a 12 V cambiaría sus umbrales y no corresponde a esta interfaz. La fuente auxiliar de 12 V debe mantenerse estable mientras el bus varía entre 12 y 24 V; no se conecta VCC directamente al bus variable.

![Conexiones de una rama con IR2110 DIP-14](img/accionamiento_ir2110.svg)

La figura utiliza símbolos de conexión, no la distribución física de las patas. Los números siguientes corresponden exclusivamente al IR2110 de 14 pines, según la sección «Lead Assignments» de la hoja de datos. No se aplican al IR2110S de 16 pines.

| Pin | Terminal | Conexión |
|---|---|---|
| 1 | LO | Resistencia de 22 Ω hacia la compuerta inferior |
| 2 | COM | Retorno del MOSFET inferior y de la alimentación auxiliar |
| 3 | VCC | +12 V auxiliares regulados |
| 4, 8, 14 | Sin conexión | Dejar abiertos |
| 5 | VS | Nodo A o B: fuente superior y drenador inferior |
| 6 | VB | Cátodo del diodo de bootstrap y extremo superior de su capacitor |
| 7 | HO | Resistencia de 22 Ω hacia la compuerta superior |
| 9 | VDD | +3,3 V de lógica |
| 10 | HIN | `pwm_ah` para A; `pwm_bh` para B |
| 11 | SD | Apagado común de las dos ramas, activo en alto |
| 12 | LIN | `pwm_al` para A; `pwm_bl` para B |
| 13 | VSS | Retorno lógico, unido a COM |

El bootstrap comprende un diodo desde VCC hacia VB y un capacitor entre VB y VS. Se propone SB1100, Schottky de 1 A y 100 V, con la banda del cátodo hacia VB y una resistencia serie inicial de 2,2 Ω. Se emplean 1 µF efectivo y 100 nF en paralelo entre VB y VS, con tensión nominal de al menos 25 V; su tensión es flotante y no se referencia a GND. El capacitor debe conservar su capacitancia con la polarización aplicada. [Hoja de datos SB1100](https://www.diodes.com/datasheet/download/SB1100.pdf).

Como comprobación inicial de dimensionamiento, a 10 kHz y modulación máxima de 0,85 la orden superior puede durar 92,5 µs. Un presupuesto de carga de 100 nC para compuerta, 230 µA para el driver, 0,5 mA de fuga de diodo y 1,2 mA para la resistencia compuerta–fuente produce unos 279 nC. Con 1 µF efectivo, la caída calculada es de unos 0,28 V. Es una estimación conservadora a temperatura ambiente, no una garantía térmica ni de recarga: se medirá VB−VS con el circuito real, incluyendo la caída del diodo y los intervalos mínimos de conducción inferior.

### Auxiliares para los dos drivers

Los componentes siguientes completan la propuesta de accionamiento; no se registran todavía como comprados. Los valores son iniciales y se ajustan con las mediciones de compuerta.

| Cantidad | Componente | Conexión o función |
|---|---|---|
| 2 | SB1100 | Diodos de bootstrap, uno por rama |
| 2 | 2,2 Ω, 0,5 W, aptas para pulsos | Serie con cada diodo de bootstrap; limitar corriente de carga |
| 2 | 1 µF, ≥25 V, capacitancia efectiva ≥1 µF | Capacitores de bootstrap; cerámicos X7R con margen de polarización o película |
| 6 | 100 nF cerámicos, ≥25 V | Dos para bootstrap, dos para VCC y dos para VDD |
| 2 | 10 µF, ≥25 V | Desacoplo VCC–COM, uno junto a cada driver |
| 2 | 1 µF, ≥10 V | Desacoplo VDD–VSS, uno junto a cada driver |
| 4 | 22 Ω, 0,25 W | Serie con cada compuerta, cerca del MOSFET |
| 9 | 10 kΩ, 0,25 W | Cuatro compuerta–fuente, cuatro HIN/LIN a GND y una SD común a +3,3 V |
| 1 | Interruptor de permiso | Entre SD común y GND; abierto mantiene apagados los drivers |

La alimentación lógica puede tomarse de 3,3 V de la Basys para estos dos drivers; se comprobarán tensión y secuencia de encendido. Para la primera evaluación se usará una salida auxiliar de laboratorio a 12 V, separada del bus variable y con el retorno unido a COM. Los capacitores se colocan junto a los terminales correspondientes. El retorno de las compuertas inferiores llega a COM con un recorrido corto, evitando que la corriente de carga circule por el cable de tierra del sensor o de la FPGA.

El PWM debe insertar tiempo muerto: el IR2110 no sustituye esa función. Se propone comenzar la evaluación con 1 µs, equivalente a 100 ciclos de 100 MHz, y ajustar según las señales reales de compuerta. Se medirá HO respecto a VS y LO respecto a COM; la pinza de tierra de un osciloscopio convencional no se conectará a VS, pues ese nodo conmuta. El lazo de compuerta y su desacoplo deben ser cortos; la potencia se montará en una placa con conexiones firmes.

Para las pruebas, SD común se mantiene alto mediante 10 kΩ a VDD; un interruptor entre SD y GND permite las órdenes cuando está cerrado. Se mantiene abierto durante configuración y reset. HIN y LIN llevan 10 kΩ a GND y permanecen bajos en reposo. Este permiso manual no detecta una falla del programa ni constituye protección de sobrecorriente. El control automático de SD y los pines físicos de la Basys quedan pendientes de integración.

El arranque se evaluará con referencia de modulación cero y al menos cinco períodos PWM antes de aplicar una referencia de corriente. La secuencia debe dar primero un intervalo inferior que cargue cada bootstrap, conforme a la máquina de arranque del PWM; la simulación RTL y la medición deben confirmarlo. Con 10 kHz, cinco períodos equivalen a 500 µs. La prueba inicial se realiza sin alimentar el bus de potencia, verificando retorno, alimentación de drivers, apagado, carga de bootstrap y ausencia de solapamiento en las compuertas.

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

### Primera prueba de adaptación al XADC

Para caracterizar el sensor se propone un divisor de 4,7 kΩ desde OUT hasta la entrada analógica y 1 kΩ desde esa entrada hasta tierra, ambas de 1 %. El módulo se alimenta con 5 V regulados. La corriente circula por IP+ e IP−; esos terminales de potencia no se conectan a la tierra de señal. El retorno del sensor y la entrada negativa del canal XADC se conectan al retorno analógico común. El rango nominal unipolar del XADC es de 0 a 1 V. [Digilent, ejemplo Basys 3 XADC](https://github.com/Digilent/Basys-3-XADC) · [AMD, función de transferencia](https://docs.amd.com/r/en-US/ug480_7Series_XADC/ADC-Transfer-Functions).

La relación nominal es `V_ADC = V_sensor / 5,7 = 0,4386 + 0,03246·i_L`. A ±1 A, la tensión queda entre 0,4061 y 0,4711 V. Incluso con salida del sensor de 5,5 V, el divisor nominal entrega 0,965 V; con tolerancias de 1 % en el peor sentido, aproximadamente 0,981 V. Esto cubre el rango normal de salida y alimentación especificado, no una conexión accidental al bus de potencia.

El divisor carga la salida con 5,7 kΩ, por encima del mínimo de 4,7 kΩ indicado para el ACS712. Su resistencia equivalente es de unos 825 Ω; adquisición debe comprobar el tiempo de establecimiento con la impedancia del canal y del cableado. El filtrado del módulo y cualquier filtro adicional se medirán antes de fijar la temporización.

Esta adaptación solo proporciona unos 133 códigos por amperio con un resultado de 12 bits: a 0,2 A pico, la excursión es de unos 27 códigos respecto al cero. Antes de adoptarla para el lazo se comprobarán ruido, deriva y error de fundamental en ese punto. Si no alcanza la precisión requerida, se diseñará una etapa con ganancia y compensación de offset. No se declara cerrado el acondicionamiento por el solo hecho de respetar el rango de tensión.

La calibración se realizará con corriente nula y una corriente conocida, obteniendo `i_L = (n − n_cero) / K`, con K en códigos por amperio y signo verificado. Adquisición y software deben acordar primero la alineación del dato: una lectura DRP de 16 bits no equivale a un ADC de 16 bits. Se propone evaluar VAUX6, accesible por JXADC1(P) y JXADC7(N), sujeto a confirmación de Kenneth y al archivo de pines final.

## Protección y puesta en marcha

Se propone un montaje con limitación de corriente de la fuente de laboratorio, fusible en la alimentación DC y desconexión manual. El accionamiento debe garantizar apagado durante reset y ausencia de conducción simultánea en cada rama mediante tiempo muerto. Los valores del fusible, los límites de corriente y la respuesta ante fallos quedan por definir con el circuito final.

El desacoplo del bus y de los drivers forma parte del montaje. La necesidad de diodos adicionales o redes de amortiguamiento se decidirá según los caminos de recirculación, el tiempo muerto y los transitorios medidos; no se incorporan como componentes ya seleccionados. Antes de energizar el puente se comprobarán las señales de compuerta y su referencia de tensión.

[Potencia](README.md) · [Simulación](02_simulacion_y_resultados.md) · [Pendientes](03_pendientes_y_validacion.md)
