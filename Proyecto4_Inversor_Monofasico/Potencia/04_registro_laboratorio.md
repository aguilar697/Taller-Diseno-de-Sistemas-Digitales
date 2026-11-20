# Registro de puesta en marcha

Las observaciones corresponden al montaje con IRF540N, IR2110 DIP-14, ACS712 de 5 A, divisor de 4,7 kΩ/1 kΩ y carga RL. Cada entrada recoge las condiciones del ensayo, las mediciones y las comprobaciones pendientes. La validación del control de corriente en los puntos nominales sigue pendiente.

## Accionamiento y puente

| Comprobación | Resultado observado | Alcance |
|---|---|---|
| Salida inferior izquierda, pin 1 respecto al 2 | 11,926 V al activar LIN con SD bajo; vuelve a cero al deshabilitar | Respuesta estática |
| Salida inferior derecha | Respondió después de trasladar el montaje a otra protoboard | La falla inicial estaba asociada al montaje/contactos; no se confirmó avería del integrado |
| Bootstrap, pin 6 respecto al 5 | Aproximadamente 11,95 V | Falta registrar caída durante conmutación y máximo duty |
| PWM de la Basys | Aproximadamente 10 kHz; separación de 1 µs entre órdenes complementarias en la captura | Repetir para ambas ramas y medir VGS reales |
| Salida inferior con PWM | Nivel alto cercano a 12,1 V | No valida por sí sola HO ni VGS superior |
| Nodos A y B con bus reducido | Niveles altos de aproximadamente 2,91 y 2,95 V | Falta contrastar corriente y tensión diferencial cuantitativamente |
| Fuente del bus | 3,012 V; límite de 100 mA; sin limitación permanente reportada | No acredita operación a 12–24 V |

El osciloscopio inicial y los cables largos mostraron picos grandes. Una medida con punta y retorno en el mismo punto también presentó perturbaciones: esas capturas no permiten atribuir todos los picos a la salida del driver. Se cambió el instrumento y se mejoró la conexión. La indicación «Base −100 mV» no es una medida de mínimo absoluto.

Las masas de los canales convencionales se conectan únicamente a GND. Para observar A−B se miden A y B respecto a GND y se utiliza la resta matemática, dentro del rango del instrumento. VGS superior requiere medición diferencial adecuada; no llevar la masa del osciloscopio a A o B.

## Referencia analógica y sensor

En las pruebas DC iniciales OUT pasó de unos 2,426 V sin corriente a 2,385 V con 0,2 A y 2,328 V con 0,5 A. La pendiente fue negativa en el sentido ensayado. El sentido respecto a A→B del puente no quedó identificado; esas lecturas no son una calibración definitiva.

Durante la integración se midieron 0,426 V en JXADC1 y −0,047 V en JXADC7 respecto al GND utilizado; entre ambas entradas había 0,473 V. El XADC mide esa diferencia, por lo que no era correcto comparar su código únicamente con JXADC1 respecto a otro retorno.

Después de corregir el retorno de VAUX6 se obtuvieron:

| Punto | Resultado |
|---|---|
| JXADC7 respecto a GND | 0 V |
| Divisor y JXADC1 respecto al mismo GND | 0,426 V |
| Cero promediado por software | 1748,16 códigos, equivalente nominal a 0,4268 V |
| Códigos en reposo observados | Aproximadamente 1745–1751 |
| STATUS del ADC | 3: muestra válida y nueva, sin errores reportados |

La [captura scope_2.csv](../docs/informe/resultados/potencia/laboratorio/scope_2.csv), anterior a esta corrección, contiene 5000 puntos en 50 ms: aproximadamente 5,10 mV RMS de componente AC y 35,3 mV pico a pico. Su posición de medida y acoplamiento deben conservarse al repetir la captura. Ese ruido no se traslada automáticamente al montaje corregido.

## Intento de cierre del lazo

El ensayo limitado utilizó bus de 3 V, referencia prevista de 0,10 A pico y sondeo previo de 50 Hz con modulación 0,20. Tras ajustar el cero, el sondeo obtuvo correlaciones de aproximadamente 1,57 códigos en fase y −0,34 en cuadratura. El programa detectó respuesta insuficiente (ERROR=5) y apagó el PWM **antes de entrar al PR**.

Con 3,012 V de bus y una modulación de 0,20, el modelo lineal de 7,2 Ω y 9,3 mH predice 0,0775 A pico. Con una sensibilidad nominal de 133 códigos/A, se esperarían 10,3 códigos de amplitud, unos 9,5 códigos en fase con la excitación. La respuesta observada fue menor. Falta determinar si la diferencia corresponde al accionamiento, al recorrido de corriente, al sensado u otra condición. No se redujo el umbral para forzar el arranque.

## Sesión de lazo abierto con el bus reducido

Se habilitó el PWM con SW15 y se inició con BTNU el diagnóstico de 50 Hz, modulación de 0,10 y duración máxima de cinco segundos. La fuente del puente se mantuvo alrededor de 3 V con límite de 100 mA. En la resta matemática A−B del osciloscopio se observaron pulsos de ambas polaridades, con nivel superior de 2,95 V y repetición a 50,03 Hz. Esta lectura verifica la alternancia de polaridad en el ensayo reducido. La portadora es de 10 kHz y la repetición a 50 Hz corresponde a la modulación.

Con el bus apagado se comprobó que JXADC7 estaba flotante. Tras unirlo al retorno común, JXADC7 midió 0 V y JXADC1 midió 0,430 V. Ocho lecturas en reposo quedaron entre 1763 y 1768 códigos, con promedio de 1765,5 (0,431 V nominales). Esto verifica la concordancia de la conversión en el punto de reposo.

| Punto de medida | Resultado | Interpretación |
|---|---|---|
| OUT del ACS712 antes del divisor | Aproximadamente 410 mV pico a pico en acoplamiento AC. Con punta y retorno en el mismo GND se observaron aproximadamente 370 mV pico a pico. | La prueba de referencia muestra captación de perturbaciones en la medición. Los picos de ambas capturas no se pueden restar para obtener la salida del sensor. |
| Entrada del XADC después del divisor | Registro en DC con promedio cercano a 0,420 V y 16,1 mV pico a pico. El registro en AC alcanzó 51,1 mV pico a pico, con indicios de recorte. | Los extremos incluyen picos y efectos de adquisición. La componente a 50 Hz quedó por debajo de 0,4 mV pico a pico en ambos registros. |
| Caída diferencial en una resistencia de 3,3 Ω | La exportación de la resta de canales presenta valores alternados y muestras repetidas en un extremo. | La captura no permite cuantificar de forma fiable la corriente independiente. |

Para esta excitación, el modelo de 7,2 Ω y 9,3 mH da cerca de 39 mA pico a 50 Hz. Con la ganancia nominal del divisor y el ACS712, la componente esperada a la entrada del XADC es de unos 2,5 mV pico a pico. La señal registrada quedó por debajo de esa estimación. El devanado puede contribuir por su inductancia dependiente de la frecuencia, sus pérdidas o su acoplamiento magnético. La captación observada en GND y la falta de una medida independiente de corriente dejan abierta la causa de la discrepancia. El seguimiento de corriente en lazo cerrado continúa pendiente.

### Comparaciones pendientes

1. Repetir el ensayo a 3 V con límite de 100 mA y con el transformador actual. Usar ramales separados para el retorno de potencia y el de la Basys, unidos en el negativo del capacitor del bus. Conservar JXADC7 en el retorno del divisor y comparar la captura en GND y la señal del sensor con las anteriores.
2. Si se consigue un inductor de potencia cercano a 10 mH, registrar su inductancia, resistencia DC y corriente de saturación. Repetir el mismo ensayo con el cableado de la primera comparación y las dos resistencias de 3,3 Ω. Contrastar VAB, la lectura del ACS712 y una medición independiente de corriente.

## Continuación de las pruebas

1. Usar el bitstream y ELF del mismo XSA, con el mapa y pines de la [integración física](../docs/diseno/integracion_basys3.md). No combinar el proyecto JA con los constraints JC.
2. Con bus apagado y ACS712 alimentado, comprobar JXADC7–GND y JXADC1–JXADC7, códigos y ruido. Obtener cero y pendiente con corriente conocida en ambos sentidos, conservando fuente, divisor y retorno. Registrar VCC.
3. Comparar ruido con SD alto, luego con drivers habilitados y bus apagado, y finalmente con bus de 3 V limitado. Cambiar una condición por vez permite distinguir ruido propio, acoplamiento de compuertas y acoplamiento de potencia.
4. Con ensayo abierto finito, medir VAB y corriente mediante una referencia independiente. Confirmar que ACS712, devanado y resistencias estén en un único camino en serie entre A y B, sin derivaciones a GND. Contrastar tensión analógica y código ADC.
5. Repetir el [ensayo PR de 3 V](../software/embedded/integration/lazo_laboratorio.md) cuando la respuesta sea medible y el signo esté definido. Conservar la traza aunque se detenga en el sondeo.
6. Pasar después a 12–24 V y referencias de 0,2; 0,5 y 1 A, ajustando el límite de fuente al ensayo y registrando fundamental, fase, rizado y transitorios. Estos resultados siguen pendientes.

No detener el procesador para inspeccionar variables mientras el PWM esté activo: el ADC sigue adquiriendo y puede generar errores persistentes. Ante una falla, conservar el diagnóstico y apagar el bus, bajar SW15 y dejar SD altos antes de reiniciar.

[Diseño y componentes](01_diseno_y_componentes.md) · [Pendientes](03_pendientes_y_validacion.md)
