# Registro de laboratorio y continuidad de pruebas

Registro consolidado el 14 de noviembre de 2026. Próxima sesión prevista: lunes 16 de noviembre de 2026.

## Punto de partida

Se adquirieron los componentes para el accionamiento de las dos ramas y se preparó el montaje en protoboard. Las pruebas realizadas corresponden a alimentación y órdenes estáticas de los IR2110, con el bus de potencia apagado. El circuito y las cantidades de diseño se describen en [Diseño y componentes](01_diseno_y_componentes.md).

| Elemento | Resultado disponible | Comprobación pendiente |
|---|---|---|
| Salida inferior del driver izquierdo | El pin 1 sube a unos 12 V con el pin 12 alto y el pin 11 bajo; se apaga al subir el pin 11 | Repetir como referencia al comenzar la sesión |
| Salida inferior del driver derecho | El pin 1 permanece cerca de cero durante la orden de activación | Identificar la causa antes de alimentar el bus |
| Bootstrap y salida superior | Se definieron SB360 y capacitores independientes por rama | Medir pin 6 respecto al 5 y pin 7 respecto al 5 durante una secuencia de prueba adecuada |
| ACS712 y divisor | Hay lecturas DC con 0; 0,2 y 0,5 A | Resolver la variación observada en el divisor y completar calibración, signo y ruido |
| Puente con PWM y lazo PR | Se dispone de resultados de simulación | Comprobar señales de compuerta, tiempo muerto y respuesta física del conjunto |

Las tensiones siguientes son lecturas puntuales de multímetro. No incluyen incertidumbre instrumental, formas de onda ni registro temporal de conmutación. Los ensayos estáticos de una salida no validan el puente completo.

## Alimentaciones y referencias de medida

| Fuente | Conexión prevista | Motivo y uso en estas pruebas |
|---|---|---|
| Variable de 12–24 V DC | Drenadores de los dos MOSFET superiores | Bus que entrega energía a la carga. Permanece apagado durante el diagnóstico de los drivers |
| Fija de 12 V DC | Pin 3 de ambos IR2110 y entrada de cada resistencia de bootstrap | Proporciona la tensión de compuerta independientemente de la variación del bus |
| Fija de 3,3 V DC, externa | Pin 9 de ambos IR2110 y polarización de sus pines 11 | Alimenta la lógica y establece niveles compatibles con las órdenes digitales |
| Fija de 5 V DC | VCC del ACS712 | Alimenta el sensor; no alimenta los IR2110. Puede permanecer apagada durante la prueba aislada de sus salidas inferiores |

Los negativos de las fuentes comparten una referencia de GND con los pines 2 y 13 de los drivers. El retorno de la Basys 3 se une a esa referencia cuando se integre la placa; la salida de alimentación de 3,3 V de la Basys no se conecta en paralelo con la fuente externa. Las salidas positivas de distinta tensión se mantienen separadas.

Los pines 5 y los capacitores de bootstrap pertenecen a los nodos A y B; no se confunden con GND. La carga queda entre A y B. La tierra de señal del ACS712 sí se une a GND, mientras sus dos terminales de corriente quedan en serie con la carga.

Las fuentes de laboratorio deben admitir la conexión de negativos prevista. Se verifica su referencia a tierra y se evita interconectar canales cuya configuración produzca un cortocircuito. Los capacitores y retornos locales se mantienen cerca de cada driver; compartir fuente no sustituye el desacoplo individual.

Para comparar resultados se mide directamente en las patas del integrado:

- Alimentación de accionamiento: pin 3 respecto al 2.
- Alimentación lógica y entradas: pines 9, 10, 11 y 12 respecto al 13.
- Salida inferior: pin 1 respecto al 2.
- Alimentación flotante y salida superior: pines 6 y 7 respecto al 5.

Durante las pruebas se observaron unos 30–50 mV entre algunos puntos denominados GND. Las lecturas anteriores tomadas respecto al pin 2 se conservan con esa referencia. Antes de conmutar se verificará la continuidad entre 2 y 13 y sus retornos a las fuentes; una tensión pequeña entre dos puntos no demuestra por sí sola una unión de baja resistencia. En el osciloscopio convencional la pinza de tierra se conecta únicamente al GND del circuito, nunca a A o B; las medidas superiores requieren medición diferencial adecuada.

## Resultados de los drivers

### Alimentación y reposo

Con los jumpers de prueba retirados, los pines 10 y 12 se mantienen bajos mediante resistencias de 10 kΩ. El pin 11 se mantiene alto mediante 10 kΩ a 3,3 V. En la conexión de laboratorio los pines 11 de las dos ramas son independientes; durante la prueba de una rama la otra permanece deshabilitada. El apagado común del diseño puede integrarse después de comprobar ambas ramas. Dos polarizaciones independientes requieren dos resistencias para el pin 11, frente a una del esquema común.

La serie corregida de alimentación de ambos drivers, tomada respecto al punto de GND utilizado en el ensayo, fue:

| Punto | Lectura |
|---|---|
| Pin 9 | 3,2697 V |
| Pin 3 | 11,972 V |
| Pin 11 | 3,2129 V |
| Pin 1 | Aproximadamente 44 mV |

Este estado de salida baja es el esperado con el pin 11 alto y el pin 12 bajo.

### Driver izquierdo

Se mantuvo el pin 10 bajo. Primero se llevó el pin 11 a GND y después el pin 12 a 3,3 V, conservando las resistencias de polarización.

| Condición | Medida | Lectura |
|---|---|---|
| Pin 11 bajo y pin 12 alto | Pin 1 respecto a GND | 11,964 V |
| Misma condición | Pin 2 respecto a GND | 38,31 mV |
| Misma condición | Pin 1 respecto al 2, medida directa | 11,926 V |
| Se retira el jumper del pin 11 a GND, manteniendo el 12 alto | Pin 1 respecto a GND | 41,9 mV |
| Se retira también el jumper del pin 12 a 3,3 V | Pines 1 y 2 respecto a GND | 40,50 mV y 40,10 mV, respectivamente |

La última pareja corresponde a una diferencia aproximada de 0,40 mV. El resultado comprueba la respuesta estática de la salida inferior y el apagado mediante el pin 11 en esta posición.

### Driver derecho

En reposo se observaron aproximadamente 12 V en el pin 3, 3,3 V en el 9 y el 11 y 48,10 mV en el 12. Con el jumper del pin 11 a GND y el del 12 a 3,3 V se registraron estas entradas, todas respecto al pin 2:

| Punto | Lectura |
|---|---|
| Pin 11 | 33,23 mV |
| Pin 12 | 3,2698 V |
| Pin 13 | 31,73 mV |
| Pin 9 | 3,2698 V |

Se retiró y repuso el jumper del pin 12 manteniendo bajo el 11. Con el jumper retirado se comprobó que el pin 12 respecto al 13 era prácticamente cero. Al repetir la activación, el pin 3 respecto al 2 midió 11,938 V, pero el pin 1 respecto al 2 permaneció cerca de cero.

Se realizaron dos comprobaciones adicionales:

1. Se trasladó a la posición derecha el integrado que había respondido en la izquierda. La salida permaneció baja.
2. Se abrió la conexión entre el pin 1 y la resistencia de 22 Ω hacia la compuerta inferior. La salida del integrado también permaneció baja al repetir la orden.

El problema se mantiene en la posición derecha y requiere revisar la numeración, alimentación, retornos, contactos y conexiones de esa posición. Estas pruebas no permiten declarar averiado un integrado ni certificar que el resto del cableado sea correcto. El bootstrap y la salida superior no se han validado.

## Medición de corriente

En una primera serie con el ACS712 alimentado a unos 5 V se obtuvieron:

| Corriente DC | Tensión OUT del sensor |
|---|---|
| 0 A | Aproximadamente 2,426–2,427 V |
| 0,2 A | 2,385 V |
| 0,5 A | 2,328 V |

OUT disminuye en el sentido de corriente utilizado. La pendiente aproximada entre cero y 0,5 A tiene magnitud cercana a 0,20 V/A y signo negativo. Esta observación sirve para fijar la convención de signo; no sustituye una calibración con alimentación y referencias controladas.

En una serie posterior se midió el divisor de 4,7 kΩ/1 kΩ:

| Corriente en la carga | VCC del módulo | Salida del divisor conectado a OUT |
|---|---|---|
| 0 A | 5,023 V | 0,4277 V |
| 0,5 A | 5,012 V | 0,4055 V |

Para revisar el divisor por separado se desconectó su entrada de OUT y se conectó a VCC del módulo:

| Corriente en la carga | Entrada del divisor, conectada a VCC | Salida del divisor |
|---|---|---|
| 0 A | 5,023 V | 0,8847 V |
| 0,5 A | 5,006 V | 0,8749 V |

La primera lectura da una relación de aproximadamente 0,1761. Si esa relación permaneciera constante, con 5,006 V se esperarían unos 0,8817 V; se obtuvieron 0,8749 V. Queda una diferencia aproximada de 6,8 mV que debe investigarse. Se revisarán conexiones, valores resistivos, carga del nodo y referencias de medida, sin atribuir todavía la diferencia a una causa concreta.

Antes de conectar el XADC se debe restaurar la entrada del divisor a OUT si quedó conectada a VCC para esta comprobación. Se verificará nuevamente el rango de tensión y se obtendrán cero y ganancia reales, con signo, antes de habilitar el PR. Los parámetros nominales de software no constituyen calibración de este módulo.

## Secuencia para retomar el laboratorio

1. **Inspección sin alimentación.** Identificar la muesca y numeración real de cada IR2110. Confirmar la referencia completa de los MOSFET y los valores, tensiones nominales y polaridades de los capacitores instalados. Revisar rieles partidos y contacto de cada pata en la protoboard.
2. **Retornos sin alimentación.** Desconectar las fuentes y descargar los capacitores. Comparar la resistencia de las puntas juntas con la medida entre 2 y 13 del derecho, entre 2 y el retorno de 12 V, y entre 13 y el retorno de 3,3 V. Las uniones por cable deben medir prácticamente lo mismo que las puntas juntas. Registrar los valores; esta comprobación quedó pendiente.
3. **Configuración inicial.** Mantener el bus apagado, pines 10 y 12 bajos y pines 11 altos. Confirmar qué integrado ocupa cada posición y si la resistencia de 22 Ω del pin 1 derecho continúa desconectada. No dar por conservada la configuración tras trasladar el montaje.
4. **Alimentación y control estático.** Encender 3,3 V y después 12 V auxiliares. Repetir la prueba izquierda como referencia. En el derecho verificar 3–2 y 9–13 directamente en las patas; bajar 11, comprobar 11–13, mantener 10 bajo y aplicar una transición de bajo a alto en 12. Registrar simultáneamente el estado de entradas y 1–2. Dejar deshabilitada la otra rama.
5. **Aislamiento de la posición derecha si persiste la falla.** Con todas las fuentes apagadas, revisar o reconstruir en otro sector una conexión mínima del driver, con alimentación, desacoplos, retornos y polarización de entradas. Mantener ambas salidas separadas de las compuertas durante esa prueba. Obtener una respuesta reproducible antes de reintegrar el accionamiento.
6. **Bootstrap y conmutación.** Cuando ambas salidas inferiores respondan, comprobar apagado, carga de bootstrap y salidas superiores con referencias de medida correctas. Verificar tiempo muerto con osciloscopio antes de alimentar el bus. El multímetro no demuestra ausencia de solapamiento.
7. **Sensado e integración.** Resolver el divisor, calibrar la corriente y comprobar el XADC. Iniciar la prueba de potencia con bus reducido y fuente limitada, y completar después los puntos nominales y transitorios del [plan de validación](03_pendientes_y_validacion.md).

Al terminar cada prueba se retira el jumper de 12 a 3,3 V y se deja el 11 alto. Las modificaciones e intercambios de integrados se realizan sin alimentación. El diagnóstico del driver derecho se completa antes de aplicar energía al puente.

En cada repetición se registrarán posición e identificación del integrado, conexiones modificadas, referencias de las puntas, tensiones de alimentación, estados de 10/11/12 y tensión 1–2. Las nuevas lecturas se añaden a este documento conservando las condiciones y resultados anteriores.

[Potencia](README.md) · [Diseño y componentes](01_diseno_y_componentes.md) · [Pendientes y validación](03_pendientes_y_validacion.md)
