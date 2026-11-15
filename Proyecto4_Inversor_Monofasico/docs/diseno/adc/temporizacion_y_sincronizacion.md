# Temporización, concurrencia y reconocimiento

## Secuencia preservada

A 100 MHz, un ciclo son 10 ns. El controlador solicita CONVST, espera el flanco EOC, emite DEN para DADDR=0x16/DWE=0 y publica solo al observar DRDY. busy del controlador cubre todas esas esperas; xadc_busy es la ocupación interna del Wizard y tiene otro alcance. ADC_TIMEOUT_CYCLES=1024 se aplica a cada espera EOC/DRDY, no a toda la transacción AXI.

Los TB con el IP real esperan 5000 ciclos tras liberar reset. El estímulo [design.txt](../../../src/testbench/adc/stimuli/design.txt) conserva los tiempos y valores originales, con espacios finales normalizados; 0xE66 representa tensión simulada aproximada de 0,9 V, no 0,9 A.

## Efecto de ACK

AXI registra el token y el pulso `ack_sample_o` al ejecutar la escritura ACK_ID. adc_control los observa en el flanco siguiente. La comparación debe ocurrir allí: comprobar solo en AW dejaría una ventana para una conversión intermedia. Un pulso coincide solo con la muestra actual válida/pendiente y un token no nulo igual.

Si en ese flanco también se publica DRDY, la asignación de publicación prevalece y new_data=1. El reconocimiento válido de la muestra anterior evita un falso `overrun`, pero un token antiguo no lo suprime. Las lecturas MMIO responden aunque la conversión continúe o falte EOC/DRDY.

## Snapshot de muestra y token

SAMPLE y su token se capturan juntos al aceptar AR. RDATA se mantiene estable hasta RREADY. ACK_ID leído después devuelve ese token capturado aunque hayan llegado otras muestras. Es necesario que no se intercale otra lectura SAMPLE de otro consumidor entre ambas lecturas. El orden debe garantizarse por software/BSP y por la configuración de E/S de la plataforma.

El ID16 envuelve; el token 32 conserva la generación. Tras agotarse, token 0 bloquea ACK hasta reset para evitar alias. Un reset inicia otra sesión: descartar tokens y comandos anteriores es una obligación del driver, no una propiedad verificada del sistema MicroBlaze V.

## Resultados actuales

La regresión desde el repositorio `repo_final_20261111` midió 111, 113 y 113 ciclos CONVST→SAMPLE. Las tres palabras fueron 00010E66, 00020E66 y 00030E66. Las latencias dependen de la fase del disparo respecto al modelo XADC. No se modificó la FSM ni la configuración IP al trasladar las fuentes.

Estos valores son tres observaciones simuladas, no una cota de jitter ni validación física. El período PWM, fase de disparo, ISR, escalas, latencia hasta actuación y posibles cruces de reloj siguen pendientes del equipo.
