# Registro de puesta en marcha

Las observaciones corresponden al montaje con IRF540N, IR2110 DIP-14, ACS712 de 5 A, divisor de 4,7 kΩ/1 kΩ y carga RL. Son lecturas puntuales y capturas de la sesión; todavía no constituyen validación del control de corriente en los puntos nominales.

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

## Continuación de las pruebas

1. Usar el bitstream y ELF del mismo XSA, con el mapa y pines de la [integración física](../docs/diseno/integracion_basys3.md). No combinar el proyecto JA con los constraints JC.
2. Con bus apagado y ACS712 alimentado, comprobar JXADC7–GND y JXADC1–JXADC7, códigos y ruido. Obtener cero y pendiente con corriente conocida en ambos sentidos, conservando fuente, divisor y retorno. Registrar VCC.
3. Comparar ruido con SD alto, luego con drivers habilitados y bus apagado, y finalmente con bus de 3 V limitado. Cambiar una condición por vez permite distinguir ruido propio, acoplamiento de compuertas y acoplamiento de potencia.
4. Con ensayo abierto finito, medir VAB y corriente mediante una referencia independiente. Confirmar que ACS712, devanado y resistencias estén en un único camino en serie entre A y B, sin derivaciones a GND. Contrastar tensión analógica y código ADC.
5. Repetir el [ensayo PR de 3 V](../software/embedded/integration/lazo_laboratorio.md) cuando la respuesta sea medible y el signo esté definido. Conservar la traza aunque se detenga en el sondeo.
6. Pasar después a 12–24 V y referencias de 0,2; 0,5 y 1 A, ajustando el límite de fuente al ensayo y registrando fundamental, fase, rizado y transitorios. Estos resultados siguen pendientes.

No detener el procesador para inspeccionar variables mientras el PWM esté activo: el ADC sigue adquiriendo y puede generar errores persistentes. Ante una falla, conservar el diagnóstico y apagar el bus, bajar SW15 y dejar SD altos antes de reiniciar.

[Diseño y componentes](01_diseno_y_componentes.md) · [Pendientes](03_pendientes_y_validacion.md)
