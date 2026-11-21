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

## Comparación en lazo abierto con carga resistiva

Para el ensayo a 3 V con límite de 100 mA se retiró el transformador y se dejaron únicamente las resistencias entre A y B. Se utilizó el diagnóstico en lazo abierto, con referencia de 50 Hz y modulación de 0,10, sin realimentación de corriente. El osciloscopio se conectó directamente a los nodos A y B con ambos canales en DC y factor 1:1. La captura de la resta CH1 − CH2 se obtuvo a 5 ms/div y 1 V/div.

La resta muestra grupos de pulsos positivos y negativos que se repiten cada 20 ms aproximadamente. El instrumento indicó 49,885 Hz, 4,42 V pico a pico, 2,29 V de máximo y 1,86 V como nivel superior. Para un bus de 3 V se esperan pulsos con niveles cercanos a −3 V, 0 V y +3 V. Queda por medir el bus durante el ensayo y revisar las mesetas a 20 µs/div para identificar si la diferencia aparece durante los pulsos o en sus flancos.

La captura previa con el transformador usaba un ajuste de 10:1. Para determinar cuánto aporta el devanado a las perturbaciones, la comparación debe repetirse con el mismo ajuste 1:1, puntos de masa, cableado de medición y condiciones de alimentación en ambas cargas.

## Lazo abierto con el transformador de reemplazo

Se sustituyó el transformador y se capturó la caída en una resistencia de carga (`03.png`, `04.csv`) y la tensión entre A y B (`05.csv`, `06.png`). Los dos CSV contienen 25 000 muestras a 250 kSa/s, equivalentes a cinco períodos de 50 Hz. Se calculó la amplitud pico a 50 Hz proyectando la resta de canales sobre seno y coseno en toda la ventana.

| Medición | Componente de 50 Hz (pico) | Pico a pico de la señal capturada |
|---|---:|---:|
| Caída en una resistencia de carga | 55,7 mV | 0,924 V |
| Tensión diferencial A−B | 0,260 V | 11,01 V |

Si la resistencia medida es de 3,3 Ω, la componente de corriente a 50 Hz es de aproximadamente 16,9 mA pico (11,9 mA RMS). Su amplitud fue consistente a lo largo de los cinco ciclos. En A−B se observan niveles alrededor de ±3 V y picos breves de mayor amplitud. La fundamental de 0,260 V pico se aproxima a los 0,30 V pico del modelo ideal con bus de 3 V y modulación de 0,10. El ensayo confirma la presencia de corriente alterna con el devanado de reemplazo. Queda por caracterizar el devanado y comprobar cuánto de los picos proviene de la conmutación y cuánto de la medición.

### Segundo transformador de reemplazo

Tras sustituir nuevamente el transformador, se registró A−B (`02.png`, `03.csv`) y la caída en una resistencia (`04.png`, `05.csv`). Se aplicó el mismo cálculo sobre cinco ciclos de 50 Hz. El nombre `05.csv` se reutilizó en esta sesión para la captura de la resistencia.

| Medición | Componente de 50 Hz (pico) | Pico a pico de la señal capturada |
|---|---:|---:|
| Caída en una resistencia de carga | 88,8 mV | 1,246 V |
| Tensión diferencial A−B | 0,221 V | 11,37 V |

Con 3,3 Ω, la caída equivale a 26,9 mA pico de corriente a 50 Hz (19,0 mA RMS), frente a 16,9 mA pico en el ensayo anterior. Las amplitudes por ciclo en la resistencia quedaron entre 88 y 89 mV. En A−B se mantuvieron los niveles próximos a 0 y ±3 V, con extremos registrados de −5,49 V y +5,89 V. Los picos persistieron con el sensor retirado. La mejora de la señal de corriente se observó en estas condiciones de lazo abierto. Queda por medir la respuesta del ACS712 y del XADC con este devanado.

### Señal del sensor antes y durante la conmutación

Se reinstaló el ACS712 y se registró el canal 2 en el nodo del divisor con la señal de la FPGA deshabilitada (`06.csv`) y habilitada (`07.csv`). Cada captura contiene 50 000 muestras en 50 ms. La amplitud de 50 Hz se estimó mediante un ajuste de seno, coseno y constante a la ventana completa.

| Condición | Amplitud a 50 Hz | RMS de la componente AC capturada |
|---|---:|---:|
| FPGA con PWM deshabilitado | 0,058 mV pico | 2,44 mV |
| FPGA con PWM habilitado | 0,936 mV pico | 7,73 mV |

Con PWM se identificó una componente de 50 Hz del orden de los 0,87 mV pico esperados a partir de los 26,9 mA pico medidos anteriormente en la resistencia. También aumentó el contenido en torno a 10 kHz y 20 kHz. En la captura con PWM, el 5,6 % de las muestras se acumuló cerca de los límites de ±25,5 mV, lo que indica recorte en la adquisición del osciloscopio. El RMS de esa captura describe el registro recortado y sus extremos no caracterizan los picos reales. Falta repetir con mayor rango vertical, confirmar la presencia del capacitor de 100 nF y comparar con las muestras del XADC a la fase de adquisición del control.

## Primer ensayo completo del PR a 3 V

Con el transformador de reemplazo y el ACS712, se ejecutó el firmware de laboratorio para un bus de 3 V con límite de fuente de 100 mA. La UART indicó `ESTADO=4 ERROR=0`. El sondeo previo obtuvo 6,66 códigos en fase y −3,74 en cuadratura y seleccionó el signo positivo. El cero registrado fue de 1775,05 códigos. El máximo informado para la ISR fue de 2763 ciclos (27,63 µs con reloj de 100 MHz) frente al período de control de 100 µs. La secuencia programada dura unos 6 s después del arranque, con 1 s de sondeo y 5 s de control.

La [traza UART](../docs/informe/resultados/potencia/laboratorio/pr_3v_transformador_reemplazo.csv) contiene las últimas 256 muestras, separadas por 400 µs y con un incremento de cuatro en cada identificador consecutivo. El ajuste a 50 Hz dio 93,6 mA pico de corriente estimada frente a 100,0 mA pico de referencia, con un atraso de 5,7°. El error RMS entre las señales registradas fue de 22,8 mA. La orden de modulación alcanzó el límite de 0,45 en 13 de las 256 muestras. La corriente se convirtió con la ganancia nominal del sensor. Queda pendiente contrastarla con una medida independiente y verificar el lazo en el rango nominal de 12–24 V.

La repetición del ensayo tras recargar el firmware también terminó en `ESTADO=4 ERROR=0`. El cero del sensor fue de 1776,91 códigos, con correlaciones de 6,71 códigos en fase y −3,74 en cuadratura. Se mantuvo el signo positivo y la duración máxima de la ISR fue de 27,62 µs.

## Sesión del 21/11: aplicación general en la tarjeta

Se cargó `control_inversor` en la Basys 3 y se ensayó con la etapa de potencia. Las tramas se exportaron por UART con BTNL y se analizaron con `receptor.py`. La evidencia está en [`laboratorio/2026-11-21`](../docs/informe/resultados/potencia/laboratorio/2026-11-21/resultados.md).

| Punto | Resultado |
|---|---|
| 0,2 A pico | **Cumple** a 12 V (−7,07 %) y a 24 V (−3,81 %), sin conversiones perdidas y con la ISR en 8,3 µs |
| 0,5 A pico | **Sin resultado válido.** El firmware original cortó por muestras imposibles del ADC. Con la supervisión modificada no corta, pero ese ensayo tenía la carga alterada |
| 1 A pico | No se ensayó |

### Firmware y cambios en esta rama

**Construcción.** El sistema integrado se reconstruyó desde `main` con el flujo de la [integración física](../docs/diseno/integracion_basys3.md), con Vivado y Vitis 2026.1. El RTL y el firmware coinciden con `b5ed7fd`. El timing dio WNS +0,289 ns y WHS +0,042 ns, iguales a los de la construcción verificada. Se repitieron las simulaciones del PWM:

- funcional: cuatro bancos, PASS;
- error forzado: `EXPECTED_FAILURE`;
- implementación del periférico: holgura de +0,507 ns;
- temporizada post-implementación con SDF: PASS, 81 comprobaciones.

La simulación temporizada falla si se ejecuta dentro de OneDrive, porque la sincronización bloquea archivos de xsim, así que se corrió desde una copia local. En la PC usada, la instalación de Vitis no tenía el enlace `Vitis\gnu` hacia `..\gnu` ni `Vivado\bin` en el PATH. Por eso `vitis -s` no registraba el BSP local ni encontraba `riscv64-unknown-elf-gcc`. Se corrigieron ambos y el comando documentado funcionó sin cambios.

**Calibración** (`software/embedded/control/parametros.h`):

| Constante | Valor | Origen |
|---|---|---|
| `MEDICION_CALIBRADA` | 1 | — |
| `OFFSET_ADC` | 1776,0 | Promedio de los ceros del 20/11 |
| `GANANCIA_ADC` | +0,0076383 A/código | Ganancia nominal con VCC = 4,924 V y signo positivo del sondeo |

La ganancia no se contrastó todavía con una medición independiente.

**Supervisión.** Al subir a 0,5 A aparecieron muestras con códigos imposibles, y el firmware original cortaba con una sola de ellas. Se cambió así:

- La **sobrecorriente** y el **código fuera de rango** exigen ahora **tres muestras seguidas** (`N_SOBRECORRIENTE = 3` y `N_CODIGO_FUERA = 3`). Una muestra normal reinicia la cuenta, y el reconocimiento de la falla también.
- Una muestra con código fuera de rango **no entra al PR**: se usa la última muestra válida.
- Una sobrecorriente real se sigue detectando. Con la inductancia de la carga, la corriente cambia unos 0,06 A por período de 100 µs a 24 V, así que tres muestras (300 µs) no la dejan pasar.

Archivos modificados:

| Archivo | Cambio |
|---|---|
| `supervision.h` y `supervision.c` | Contadores de muestras seguidas |
| `aplicacion.c` | Sustitución de la muestra imposible |
| `test_supervision.c` y `test_aplicacion.c` | Comprobaciones nuevas: dos muestras no producen falla, tres sí, y una normal reinicia la cuenta |
| [`nivel_3_software.md`](../docs/diseno/nivel_3_software.md) y [`nivel_4_software.md`](../docs/diseno/nivel_4_software.md) | Criterio actualizado |

La batería de PC aprueba sus 206 comprobaciones; antes eran 201. El ELF compilado desde esta rama coincide con el que se ensayó: `.text`, `.text.init` y `.data` son idénticas. `.rodata` difiere solo en la ruta del espacio de trabajo que el BSP guarda en dos mensajes de aserción.

**Variantes usadas durante la sesión:**

| Variante | Qué tenía | Estado |
|---|---|---|
| A | Solo el cambio de sobrecorriente | Intermedia, ensayada (trama 08) |
| B | La supervisión completa descrita arriba | Es la que queda en esta rama |
| Diagnóstico | Congelaba el registro tras una falla y registraba cada muestra | Se compiló, pero no se usó |

**Herramientas.** En [`scripts/laboratorio`](../scripts/laboratorio/README.md) quedan las que se usaron para las gráficas y la tabla de resultados, y una para compilar variantes de 20 y 25 kHz, que no se ensayaron en la tarjeta.

### Tramas de la sesión

Cada trama tiene su `.csv`, su `.bin` (se puede reanalizar con `receptor.py --archivo`) y su gráfica `.png`. [`resultados.md`](../docs/informe/resultados/potencia/laboratorio/2026-11-21/resultados.md) las reúne con la predicción de PLECS.

| N.º | Firmware | Condición | Resultado |
|---|---|---|---|
| [01](../docs/informe/resultados/potencia/laboratorio/2026-11-21/01_reposo_auxiliares_apagadas.png) | Calibrado | Reposo, alimentaciones auxiliares apagadas | Falla por sobrecorriente y código fuera de rango: sensor sin alimentación |
| [02](../docs/informe/resultados/potencia/laboratorio/2026-11-21/02_reposo_bus_apagado.png) | Calibrado | Reposo, bus apagado | `DETENIDO`; cero de 1779,8 códigos y 21 mA RMS de ruido |
| [03](../docs/informe/resultados/potencia/laboratorio/2026-11-21/03_pr_12v_0a2.png) | Calibrado | 12 V, 0,2 A | 0,1859 A; −7,07 %; −2,53° |
| [04](../docs/informe/resultados/potencia/laboratorio/2026-11-21/04_pr_24v_0a2.png) | Calibrado | 24 V, 0,2 A | 0,1924 A; −3,81 %; −1,61° |
| [05](../docs/informe/resultados/potencia/laboratorio/2026-11-21/05_falla_24v_cambio_0a2_a_0a5.png) | Calibrado | 24 V, cambio de 0,2 a 0,5 A en marcha | Falla por sobrecorriente |
| [06](../docs/informe/resultados/potencia/laboratorio/2026-11-21/06_falla_24v_arranque_0a5.png) | Calibrado | 24 V, arranque directo a 0,5 A | Falla por sobrecorriente |
| [07](../docs/informe/resultados/potencia/laboratorio/2026-11-21/07_falla_24v_0a5_repeticion.png) | Calibrado | 24 V, 0,5 A, repetición | Falla por sobrecorriente |
| [08](../docs/informe/resultados/potencia/laboratorio/2026-11-21/08_falla_24v_0a5_variante_a.png) | Variante A | 24 V, 0,5 A | Falla por sobrecorriente y código fuera de rango |
| [09](../docs/informe/resultados/potencia/laboratorio/2026-11-21/09_variante_b_24v_0a5.png) | Variante B | 24 V, 0,5 A, condensador de 2200 µF conectado | Sin falla; 0,3194 A; −36,12 %; −41,83°; m en ±0,85 en 135 de 512 muestras. No representativo |
| [10](../docs/informe/resultados/potencia/laboratorio/2026-11-21/10_variante_b_0a2.png) | Variante B | 0,2 A, bus no registrado, condensador conectado | 0,1829 A; −8,56 %; −3,67°; m máxima 0,47 |

Las tramas de falla se exportaron después del corte, por lo que muestran el PWM apagado y no el instante del disparo. El límite de fuente fue de 0,5 A en todos los ensayos con bus. En una de las repeticiones a 0,5 A (tramas 05 a 07) se usó un segundo inductor que no quedó identificado.

### Reposo y cero

Con las alimentaciones auxiliares apagadas, el XADC leyó unos 7 códigos y la aplicación entró en falla, como corresponde a un sensor sin alimentación. Con las auxiliares encendidas y el bus apagado, el cero medido fue de 1779,8 códigos: +29 mA respecto a los 1776,0 cargados. El ruido fue de 21 mA RMS, unos 2,8 códigos. Con el bus a 24 V y el PWM apagado, después de una falla, la media subió a +57–68 mA, de 4 a 5 códigos más que con el bus apagado. La diferencia de cero solo agrega una componente continua. El PR no tiene ganancia resonante en continua, así que no afecta la fundamental de 50 Hz que evalúa el criterio.

### Seguimiento a 0,2 A pico

| Bus | Fundamental medida | Error de amplitud | Desfase | m máxima | ISR máxima | PLECS |
|---|---:|---:|---:|---:|---:|---|
| 12 V | 0,1859 A | −7,07 % | −2,53° | 0,39 | 8,34 µs | 0,1935 A; −3,23 %; −0,90° |
| 24 V | 0,1924 A | −3,81 % | −1,61° | 0,27 | 8,34 µs | 0,1967 A; −1,64 %; −0,45° |

El criterio del 10 % se cumple con los dos buses, sin conversiones perdidas ni saltos en el número de muestra. La fundamental de la modulación fue 0,311 a 12 V y 0,166 a 24 V, lo que confirma el cambio de bus.

Con esos valores, la carga presenta unos 20 Ω aparentes a 0,19 A, incluido el efecto del tiempo muerto. El modelo usaba 7,77 Ω. Esto concuerda con el aumento de impedancia con la corriente observado el 20/11, y explica un error mayor que en PLECS: la ganancia del PR a 50 Hz se reparte contra una carga mayor. A 24 V, con `VDC_V` fijo en 12 V, la ganancia del lazo se duplica y el error disminuyó.

La corriente medida contiene un tercer armónico del 6,6 % a 12 V y del 4,2 % a 24 V. El contraste con la caída en una resistencia de 3,3 Ω en la misma corrida no quedó registrado.

### Intentos a 0,5 A pico con bus de 24 V

**Con el firmware original.** El cambio de 0,2 a 0,5 A en marcha, el arranque directo a 0,5 A y una repetición terminaron en falla por sobrecorriente. Hubo además una captura de osciloscopio en una resistencia de 3,3 Ω durante el arranque directo, con resta de canales y una muestra cada 50 µs; todavía no está en el repositorio. Mostró:

- lóbulos de unos 0,5–0,6 A durante algo más de un ciclo;
- el disparo a los ~25 ms;
- al cortar, los nodos subieron a ~25 V mientras la corriente del devanado se descargaba al bus en ~1 ms.

Las excursiones de la resta coinciden con tramos en los que el muestreo cae cerca de las conmutaciones, así que no permiten afirmar picos reales de corriente.

**Con la variante A.** La falla incluyó código fuera de rango. Un código fuera de 16–4079 equivale a −13 A o +17 A, corrientes imposibles con 24 V y la carga montada. La medición en VAUX6 se corrompe al aumentar la corriente.

**Con la variante B.** No hubo falla, pero la modulación quedó en ±0,85 en el 26 % de las muestras y la corriente medida fue asimétrica: crecía lentamente y tenía un pico al final del semiciclo positivo. En ese ensayo había un condensador de 2200 µF en paralelo con una de las resistencias de 3,3 Ω:

- a 50 Hz esa rama queda en unos 1,3 Ω, mayormente capacitiva;
- solo el 40 % de la corriente circula por la resistencia, así que la carga deja de ser RL serie y la caída en esa resistencia no representa la corriente;
- si es electrolítico, queda polarizado en sentido inverso en cada semiciclo.

El condensador reduce la impedancia, por lo que no explica la saturación de la modulación. La hipótesis es que el límite de fuente de 0,5 A redujo el bus: con unos 20 Ω aparentes, 0,5 A pico requiere unos 10 W instantáneos, y los 100 µF del bus no cubren la pulsación de 100 Hz. Queda por comprobar con la tensión del bus y el modo de la fuente durante el ensayo. El resultado no se considera representativo.

### Pendientes de esta sesión

1. Retirar el condensador de 2200 µF de la resistencia de carga y conservar únicamente los 100 nF previstos entre el nodo del divisor y su retorno.
2. Revisar la medición:
   - JXADC7 directo al retorno del divisor;
   - conductores de JXADC trenzados y alejados de la potencia;
   - retornos de potencia y de señal separados hasta el punto común.

   Repetir después el reposo con el bus a 24 V para comprobar el corrimiento del cero.
3. Repetir 0,5 A y luego 1 A a 24 V, con límite de fuente de 1 A y 1,5 A respectivamente. Registrar la tensión del bus, el modo de la fuente y, en la misma corrida, la caída en una resistencia de 3,3 Ω.
4. Registrar VGS, el tiempo muerto e `isr_debug` (JB1).
5. Identificar el segundo inductor: inductancia, resistencia y corriente nominal.
6. Incorporar la captura de osciloscopio del arranque directo a 0,5 A.
7. Revisar en equipo la calibración y el cambio de supervisión de esta rama antes de llevarlos a `main`.

## Continuación de las pruebas

1. Usar el bitstream y ELF del mismo XSA, con el mapa y pines de la [integración física](../docs/diseno/integracion_basys3.md). No combinar el proyecto JA con los constraints JC.
2. Con bus apagado y ACS712 alimentado, comprobar JXADC7–GND y JXADC1–JXADC7, códigos y ruido. Obtener cero y pendiente con corriente conocida en ambos sentidos, conservando fuente, divisor y retorno. Registrar VCC.
3. Comparar ruido con SD alto, luego con drivers habilitados y bus apagado, y finalmente con bus de 3 V limitado. Cambiar una condición por vez permite distinguir ruido propio, acoplamiento de compuertas y acoplamiento de potencia.
4. Con ensayo abierto finito, medir VAB y corriente mediante una referencia independiente. Confirmar que ACS712, devanado y resistencias estén en un único camino en serie entre A y B, sin derivaciones a GND. Contrastar tensión analógica y código ADC.
5. Repetir el [ensayo PR de 3 V](../software/embedded/integration/lazo_laboratorio.md) cuando la respuesta sea medible y el signo esté definido. Conservar la traza aunque se detenga en el sondeo.
6. Pasar después a 12–24 V y referencias de 0,2; 0,5 y 1 A, ajustando el límite de fuente al ensayo y registrando fundamental, fase, rizado y transitorios. Estos resultados siguen pendientes.

No detener el procesador para inspeccionar variables mientras el PWM esté activo: el ADC sigue adquiriendo y puede generar errores persistentes. Ante una falla, conservar el diagnóstico y apagar el bus, bajar SW15 y dejar SD altos antes de reiniciar.

[Diseño y componentes](01_diseno_y_componentes.md) · [Pendientes](03_pendientes_y_validacion.md)
