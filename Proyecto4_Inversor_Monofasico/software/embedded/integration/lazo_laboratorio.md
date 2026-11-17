# Ensayo inicial del control de corriente

`lazo_laboratorio.c` ejecuta una prueba finita sobre la plataforma integrada.
Utiliza los drivers AXI, el PR discreto y la referencia sinusoidal del proyecto.
La aplicación general se construye aparte y exige declarar la calibración antes del arranque físico.

## Condiciones del ensayo

| Parametro | Valor |
| --- | --- |
| Bus de potencia | 3 V, limite de fuente de 100 mA |
| Alimentacion de drivers y sensor | Fuentes auxiliares independientes del bus |
| PWM / control | 10 kHz / 10 kHz |
| Tiempo muerto | 1 microsegundo |
| Disparo del ADC | Fase 5000 de 10000 ciclos |
| Referencia del PR | 0.10 A pico, 50 Hz |
| Subida de referencia | 200 ms |
| Limite de modulacion del PR | 0.45 |
| Limite de corriente estimada por software | 0.30 A |
| Duracion del PR | 5 s |

La sensibilidad utilizada es nominal: ACS712 de 5 A, 185 mV/A a 5 V,
alimentacion de referencia de 4.924 V y divisor de 4.7 kohm / 1 kohm.
La corriente indicada no constituye una medicion calibrada. Los limites de
software tampoco sustituyen el limite de la fuente ni el bloqueo por SD.
Este ejecutable no esta preparado para alimentar el bus con 12 o 24 V.

## Secuencia

1. Arrancar con el sensor alimentado, bus apagado, SW15 abajo y ambos SD altos.
   El programa deja el PWM apagado y promedia 2048 conversiones para obtener
   el cero. Una entrada fuera de rango o inestable cancela el ensayo.
2. Esperar `ESTADO=1 ERROR=0` por UART; LD2 indica disponibilidad.
3. Con las conexiones ya revisadas, ajustar el bus a 3 V y 100 mA, habilitar
   los drivers mediante SD bajo y subir SW15. El PWM sigue detenido hasta
   pulsar BTN U.
4. BTN U inicia cinco periodos de referencia cero y una excitacion sinusoidal
   de modulacion 0.20 durante un segundo. Se calcula la correlacion con el ADC
   para comprobar el signo del sensado. Si no hay respuesta suficiente o la
   fase es incompatible, el PWM se apaga sin cerrar el lazo.
5. Con una respuesta valida se inicia el PR durante cinco segundos. El signo
   se ajusta en RAM; no se modifica la calibracion del proyecto.
6. El sondeo también se registra. Ante una falla se congela su traza; si llega al PR, se conservan al terminar las últimas 256 entradas,
   separadas 400 microsegundos: ventana de 102.4 ms. BTN L las exporta como
   CSV por UART a 115200 bit/s.

BTN D detiene el ensayo desde la ISR. SW15 bloquea fisicamente las cuatro
salidas en el top. SD alto bloquea las salidas de cada IR2110. Tras una falla
o una prueba completa, el programa requiere reinicio para volver a ensayar;
el reinicio y el ajuste de cero se realizan con el bus apagado.

## Estado y diagnostico

Estados: 0 ajuste de cero; 1 listo; 2 comprobacion de signo; 3 PR activo;
4 finalizado; 5 detenido por falla.

Errores: 1 configuracion; 2 ADC o secuencia de muestras; 3 cero del sensor;
4 corriente estimada fuera de limite; 5 respuesta insuficiente para determinar
el signo; 6 plazo de la ISR; 7 parada solicitada.

El arranque del PWM se realiza dentro de la ISR, despues de leer SAMPLE y
reconocer ACK_ID. El software lee la ultima conversion completa y escribe la
referencia que se aplicara en el siguiente periodo del PWM. Se comprueban las
banderas de error del ADC, los identificadores y el tiempo de ejecucion.

## Construccion y verificacion

`scripts/vitis/build_integrated.py --incluir-laboratorio` incorpora esta tercera
aplicacion en un workspace nuevo. Su configuracion usa `REGISTRO_N_BUF=256`
y `K_REG=4`. La descarga utiliza el bitstream integrado y este ELF mediante
`scripts/vitis/cargar_integrado.tcl`.

`software/tests/test_lazo_laboratorio.c` ejecuta la ISR real con registros
simulados y un modelo RL de 7.2 ohm y 9.3 mH, incluyendo dos periodos de retardo.
Comprueba ambos signos del sensor, ausencia de respuesta, overrun, muestras
repetidas, parada, limite de corriente y finalizacion automatica. Estas pruebas
no representan una validacion del puente fisico ni de la calibracion analogica.

## Resultado físico disponible

El ensayo anterior se detuvo en ERROR=5 con una respuesta de 1,57 códigos en fase. No llegó a ejecutar el PR. El umbral de 3 códigos y la excitación 0,20 se mantienen; antes de aumentar la excitación se debe contrastar corriente real y tensión diferencial. El [registro de laboratorio](../../../Potencia/04_registro_laboratorio.md) conserva las condiciones y las correcciones del retorno analógico.
