# Integración del PWM con adquisición y control

## Configuración inicial

El periférico `pwm_system_axi` utiliza un solo reloj de 100 MHz. El diseño de [tercer](nivel_3_pwm.md) y [cuarto nivel](nivel_4_pwm.md) define su estructura; este documento fija los valores iniciales para conectar plataforma, adquisición y software.

| Parámetro | Valor inicial | Criterio |
|---|---:|---|
| PWM y control | 10 kHz; Ts = 100 µs | Un cálculo del PR por período PWM |
| `FREQ_SEL` | 0 | P = 10000 ciclos, N = 5000 |
| `DEADTIME` | 100 ciclos = 1 µs | Intervalo lógico inicial; comprobar VGS con los IR2110 y MOSFET |
| `MOD_LIMIT_Q15` | 27853 | Límite simétrico cercano a ±0,85, en RTL y C |
| `MIN_ON_CYCLES` | 100 ciclos = 1 µs | Margen mínimo de conducción después del tiempo muerto |
| `TRIGGER_PHASE` | 5000 ciclos = 50 µs | Disparo a mitad del período |
| Arranque | Cinco períodos con REFERENCE = 0 | 500 µs nominales de conmutación para precargar bootstrap |
| Referencia de corriente | 50 Hz; 0,2 / 0,5 / 1 A pico | Amplitudes de evaluación |

`MIN_ON_CYCLES` es un parámetro de elaboración, no un registro AXI. El periférico valida el conjunto al habilitar, incluyendo el peor pulso de todo el rango de modulación. Para D=100:

| PWM | Menor pulso ideal | Conducción restante tras D | Fase central |
|---|---:|---:|---:|
| 10 kHz | 750 ciclos | 650 ciclos | 5000 |
| 20 kHz | 374 ciclos | 274 ciclos | 2500 |
| 25 kHz | 300 ciclos | 200 ciclos | 2000 |

Las tres frecuencias están implementadas y se verifican individualmente. El control inicial utiliza 10 kHz. Cambiar a otra frecuencia exige revisar Ts, coeficientes, Timer, fase de adquisición y registro de muestras. PHASE=5000 es inválida a 20 y 25 kHz.

## Interconexión de plataforma

1. Agregar las cuatro fuentes de `src/design/pwm/` y crear una referencia de módulo a `pwm_system_axi` en el Block Design. La interfaz está identificada como `S_AXI`, AXI4-Lite de 32 bits.
2. Conectar `s_axi_aclk` al reloj de 100 MHz y `s_axi_aresetn` al reset de periféricos de esa interconexión. Afirmación asíncrona; liberación sincronizada por la plataforma.
3. Conectar `pwm_trigger_o` directamente a `pwm_trigger_i` del ADC, en el mismo dominio de reloj. El pulso dura un ciclo, 10 ns. No se utiliza como reloj.
4. Asignar una región AXI para el periférico y publicar la macro base de `xparameters.h`. El ancho local por defecto es 6 bits; los offsets no implementados devuelven SLVERR. La plataforma debe decodificar la dirección base antes de entregar el offset local.
5. Llevar `pwm_ah`, `pwm_al`, `pwm_bh`, `pwm_bl` a los cuatro pines de actuación. Mantener el permiso externo de drivers inhibido durante la configuración.
6. Conservar `pwm_period_start_o` como señal de diagnóstico, conectable a ILA o a un pin de observación. Dura un ciclo en el arranque y en cada retorno a fase cero. No necesita interrupción propia.

El ADC y el PWM no generan interrupciones de control. La ISR se inicia por AXI Timer a través de AXI INTC. El segundo contador permite medir su duración. Para 10000 ciclos de período, el driver de Timer descendente escribe TLR=9998, porque el [modo de generación de AXI Timer](https://docs.amd.com/r/en-US/pg079-axi-timer/Generate-Mode) tiene período `(TLR + 2) · Tclk`.

## Acceso a registros y arranque

Se mantienen los offsets y nombres del header `software/embedded/drivers/pwm/pwm_regs.h`.

| Offset | Registro | Semántica |
|---|---|---|
| 0x00 | CONTROL | Enable bit 0, frecuencia bits 2:1, running RO bit 3 |
| 0x04 | REFERENCE | Entero con signo Q1.15 en bits 15:0; lectura de la referencia pendiente saturada |
| 0x08 | DEADTIME | Separación en ciclos; escritura en reposo |
| 0x0C | TRIGGER_PHASE | Fase dentro de P; escritura en reposo |

Tras reset, todos los registros valen cero, las cuatro órdenes quedan apagadas y no hay disparos. La secuencia es: CONTROL=0, configurar frecuencia, DEADTIME=100, TRIGGER_PHASE=5000, REFERENCE=0, comprobar lecturas y habilitar. D=0 impide habilitar.

La fase arranca en cero. Las ramas esperan el primer cambio de su orden ideal antes de conducir; con m=0 la primera orden activada es la inferior, después de aproximadamente un cuarto de período más D. Esto permite cargar el bootstrap antes de activar el transistor superior. Los cinco períodos de referencia cero constituyen una condición de arranque a verificar eléctricamente, no una medición de la carga del capacitor.

Las escrituras REFERENCE se aplican juntas a ambas ramas en el siguiente inicio de período. Si la escritura interna coincide exactamente con ese inicio, se aplica la referencia pendiente anterior y la nueva queda para el siguiente. El software debe completar el acceso antes del límite que quiere utilizar.

CONTROL=0 apaga en el flanco de ejecución de la escritura interna, sin esperar al límite de período. Durante operación conserva la frecuencia anterior aunque el dato escrito intente cambiarla. La transacción AXI y la entrada a la rutina de falla tienen su propia latencia; esta orden no constituye una protección instantánea contra cortocircuitos.

## Secuencia temporal de adquisición y actuación

| Instante respecto al inicio del período k | Acción |
|---|---|
| 0 µs | PWM aplica la referencia pendiente y emite `pwm_period_start_o` |
| 50 µs | PWM emite el pulso de adquisición |
| Flanco siguiente | `adc_control` reconoce el disparo; el adaptador gestiona la conversión |
| Después de la conversión | ADC publica SAMPLE y token de reconocimiento |
| Cerca del inicio del período k+1 | ISR lee la última conversión completa, sin esperar; calcula el PR y escribe REFERENCE |
| Inicio del período k+2 | PWM aplica la orden calculada, si la escritura terminó a tiempo |

Con esta secuencia, el retardo nominal desde el muestreo hasta aplicar la orden es cercano a 1,5 Ts. **La relación exacta Timer–PWM debe medirse en la plataforma integrada.** Habilitar el PWM dentro de la ISR no elimina por sí solo las latencias de interrupción y AXI. Se debe comprobar que cada ISR encuentra una muestra nueva y termina la escritura antes del siguiente límite PWM. El instante de muestreo analógico también incluye la adaptación CONVST del XADC.

La simulación independiente del ADC informa aproximadamente 1,13 µs entre CONVST y publicación; no es una cota de peor caso ni una medición física. La prueba `tb_pwm_adc` utiliza `adc_control` real y respuestas digitales conocidas; permite revisar la secuencia, sin sustituir la integración del XADC Wizard y del procesador.

El driver lee SAMPLE y después ACK_ID, respetando el orden de los accesos. SAMPLE combina identificador de 16 bits y código de 12 bits alineado a la derecha. **ACK_ID es un token de 32 bits asociado a la lectura de SAMPLE**: se devuelve completo al reconocer el dato. No se sustituye por el identificador truncado de SAMPLE. Véase el [contrato del ADC](adc/README.md).

La fase central es la elección inicial de integración. Su conveniencia frente al rizado, los bordes de conmutación y el retardo de adquisición se comprobará con señales reales; no se presupone que cualquier lectura en esa fase represente exactamente el valor medio.

## Control y medición

`parametros.h` conserva Kp=12, Kr=200, ancho resonante de 2 Hz y los coeficientes de Tustin con pre-warping a 50 Hz para Ts=100 µs. Se contrastaron numéricamente los coeficientes y los modelos con uno y dos períodos de retardo. Los [ensayos existentes del PR discreto en PLECS](../informe/resultados/potencia/pr_discreto_plecs.json) utilizan un período de retardo y normalización fija de 12 V. Queda pendiente contrastar la temporización completa de la plataforma integrada, inicialmente cercana a 1,5 Ts; los modelos PLECS existentes no se modifican en esta revisión.

Las simulaciones iniciales usaron `VDC_V=12`. El firmware de la demostración configura `VDC_V=24.0f` y el bus se fijó en 12 V durante la campaña final. Se eligió esta combinación porque dio el mejor comportamiento del lazo observado durante la puesta a punto en el banco. El PR calcula una orden de tensión, que se divide entre 24 V antes de limitar la modulación a ±0,85. La FPGA no mide la tensión del bus.

En la prueba inicial se observó una pendiente negativa para la orientación usada entonces. En el montaje con control PR se confirmó el signo positivo y se empleó una escala nominal de 7,6383 mA por código. Queda por contrastar esa escala con una medición independiente. El umbral provisional I_MAX=1,5 A tampoco reemplaza la limitación de corriente de la fuente ni la protección eléctrica.

La configuración integrada registra 512 entradas de 8 bytes (4 KiB) con `K_REG=2`. A 10 kHz de control, una entrada cada 200 µs conserva una ventana nominal de 102,4 ms. La decimación actúa sobre el registro y el PR conserva su período nominal de 100 µs.

## Permiso de drivers y comprobaciones pendientes

Las cuatro señales PWM son órdenes lógicas HIN/LIN, no tensiones de compuerta. Los IR2110 requieren su alimentación de potencia y lógica, bootstrap y masa de referencia conforme al [diseño de potencia](../../Potencia/01_diseno_y_componentes.md). SD es activo alto y queda fuera del RTL PWM.

El permiso manual conserva prioridad. Si se agrega apagado por GPIO, debe combinarse con ese permiso mediante una interfaz definida; no conectar una salida GPIO que conduce a alto contra un interruptor que fuerza masa. La asignación de GPIO y la lógica final de SD deben acordarse antes de conectar la FPGA a los drivers.

Los pines y las direcciones AXI de laboratorio constan en la [integración Basys 3](integracion_basys3.md). La serie física verificó el funcionamiento conjunto del PWM y del lazo PR. Faltan la comprobación en Vivado/Vitis 2025.1, la medición del jitter, el contraste independiente de la escala del ADC y la caracterización de las compuertas en conmutación. Los resultados independientes se reúnen en [verificación del PWM](../informe/pwm_verificacion.md).
