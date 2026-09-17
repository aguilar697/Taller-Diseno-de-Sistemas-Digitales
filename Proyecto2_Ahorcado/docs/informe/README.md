# Informe técnico — Ahorcado FPGA–PC

**EL3313 Taller de Diseño Digital · II Semestre 2026 · Grupo 3**

**Integrantes:** Kenneth Campos, Kevin Aguilar, Daniel Puentes y Kevin Cortés.

**Fecha:** 16 de septiembre de 2026.

## Resumen

Se implementó un juego de Ahorcado en Basys 3 con lógica de control, banco de palabras, evaluación de letras, temporización, periféricos locales y comunicación UART con una terminal Python. La FPGA mantiene todas las reglas del juego. La PC transmite letras y presenta los mensajes recibidos.

La regresión conductual ejecutó 17 bancos: 16 con comprobaciones satisfactorias y uno de reset basado solamente en estímulos. El motor completó 38 636 comprobaciones en 129 partidas. El diseño completo se sintetizó y enrutó a 100 MHz con WNS de 0.888 ns, 1501 LUT, 1344 registros y ningún latch. La interfaz local presenta el estado de la partida mediante LCD, displays, LED y buzzer, mientras la terminal permite ingresar letras y consultar los resultados.

## 1. Objetivo y fundamento

El sistema permite seleccionar dificultad, iniciar una partida, proponer letras y obtener un resultado local y remoto. El diseño modular separa control (S1), motor de palabras (S2), comunicación (S3) e interfaz local (S4).

Las FSM coordinan solicitudes y resultados registrados. S2 emplea una ROM constante y un LFSR de seis bits: la selección rechaza índices fuera del banco y palabras cortas en difícil. Un mapa de 26 letras detecta repeticiones; la comparación paralela de caracteres revela todas las coincidencias en una actualización.

UART transmite bytes 8N1 a 115200 baud. El periférico transforma pulsos de recepción/finalización en registros de 32 bits; el protocolo forma mensajes ASCII terminados en LF. La LCD utiliza una interfaz de registros equivalente y secuencias temporizadas de escritura. Los contadores lentos emplean habilitaciones del reloj de 100 MHz.

## 2. Arquitectura y documentos de detalle

| Subsistema | Responsable | Diseño | Verificación |
|---|---|---|---|
| S1: control y temporización | Kenneth Campos | [Arquitectura y FSM](../diseno/nivel_3_control_del_juego.md) | [Informe S1](control_verificacion.md) |
| S2: motor del juego | Kevin Aguilar | [Nivel 3](../diseno/nivel_3_motor_del_juego.md), [nivel 4](../diseno/nivel_4_motor_del_juego.md) | [Informe S2](motor_verificacion.md) |
| S3: UART, protocolo y PC | Daniel Puentes | [Nivel 3](../diseno/nivel_3_uart_protocolo.md), [nivel 4](../diseno/nivel_4_uart_protocolo.md) | [Informe S3](uart_verificacion.md) |
| S4: interfaz local | Kevin Cortés | [Arquitectura y FSM LCD](../diseno/nivel_3_interfaz_local.md) | [Informe S4](interfaz_local_verificacion.md) |

Los [niveles 1](../diseno/nivel_1.md) y [2](../diseno/nivel_2.md) presentan los límites del sistema y sus interconexiones. El [README](../../README.md) describe preparación de Vivado, fuentes activas, conexiones y ejecución de las terminales.

## 3. Contrato de integración y decisiones

| Aspecto | Decisión implementada |
|---|---|
| Datos de palabra | 96 bits, primer carácter en bits 7:0; longitud de 4 bits |
| Representación | ASCII A–Z; `_` en posiciones ocultas; espacios fuera de longitud |
| Dificultad | 0 fácil, 1 difícil; 60/45 s y restricción de longitud ≥6 en difícil |
| Intentos | 6; solo letras nuevas incorrectas descuentan |
| Victorias | Contador de 7 bits, saturado en 99 y borrado por reset |
| Respuesta S2 | Registrada al aceptar la letra, consumida por S1 en el flanco siguiente |
| Resultado | Victoria prioritaria en evaluación; luego último error y tiempo agotado |
| Palabra final | `secret_word` explícita desde S2 hacia el adaptador UART de `top` |
| Protocolo | START, HIT, MISS, REPEAT, WIN, LOSE_ATTEMPTS y LOSE_TIME; EASY/HARD; LF sin CR |
| Retención | Temporizador de S1 de 3 s desde la decisión de fin |
| Letras fuera de partida | Descartadas en selección y resultado |

La palabra secreta no se selecciona ni evalúa en la PC. El registro del evento y sus datos evita mezclar un mensaje en transmisión con actualizaciones posteriores del juego. Su capacidad es limitada a un evento pendiente; la operación prevista requiere una letra por respuesta.

## 4. Metodología de verificación

La verificación comprende pruebas individuales de los subsistemas, simulación conductual del sistema integrado, síntesis, análisis temporal y pruebas físicas. Los bancos de simulación comparan las salidas con los valores esperados para cada estímulo.

| Prueba | Herramienta | Alcance |
|---|---|---|
| Motor del juego | Vivado/XSim 2026.1 | Selección, evaluación de letras, repetición y finalización |
| Formas de onda del motor | Ventana Wave de Vivado | Cinco casos de simulación conductual |
| UART y protocolo | Vivado/XSim 2026.1 | Núcleo serial, registros, mensajes e integración |
| Sistema integrado | Vivado/XSim 2026.1 | Control, motor, comunicación e interfaz local en tb_top |
| Síntesis e implementación | Vivado 2026.1 | top, xc7a35tcpg236-1 y restricciones del sistema completo |

Los resultados de regresión se conservan como [extractos literales de logs](resultados/integracion/regresion_rtl.txt). La elaboración reproducible del motor emplea `-debug typical`; una ejecución inicial sin esa opción falló en la primera comparación de ROM, por lo que se registra la configuración junto con el resultado satisfactorio.

## 5. Resultados de simulación conductual

| Grupo | Bancos | Resultado y límite |
|---|---|---|
| Control S1 | button_conditioner, countdown_timer, game_datapath, game_fsm, result_hold_timer, game_control_top | 6 PASS; incluye prioridades, intentos, tiempos y saturación |
| Reset | reset_sync_tb | Estímulos completados; sin comprobación automática |
| Motor S2 | word_engine_tb | PASS; 38 636 comprobaciones, 129 partidas; 50 palabras fáciles y las 35 elegibles en difícil |
| Núcleo UART | UART_tx_tb, UART_rx_tb, UART_tb | 3 bancos con comprobaciones satisfactorias |
| Periférico y protocolo | uart_peripheral_tb, protocol_rx_controller_tb, protocol_tx_controller_tb, protocol_controller_tb, uart_protocol_top_tb | 5 bancos con comprobaciones satisfactorias |
| Sistema completo | tb_top | 0 errores en los escenarios implementados |

`tb_top` comprueba victoria, derrota por intentos, derrota por tiempo, repetición y mensajes finales exactos. También comprueba el reemplazo de un evento en el mismo ciclo en que se acepta el anterior. Los temporizadores se aceleran mediante parámetros de simulación; las duraciones del banco no son tiempos físicos de una partida real.

![Resultado conductual del sistema integrado](resultados/uart/tb_top_resultado_0_errores.png)

**Figura 1.** Resultado de la simulación conductual del sistema integrado en Vivado: `tb_top` finaliza con cero errores en los escenarios comprobados.

Las formas de onda de control se presentan en el [informe de S1](control_verificacion.md). El [informe de S2](motor_verificacion.md#capturas-de-formas-de-onda-en-vivado) muestra selección fácil, selección difícil, acierto y repetición, palabra completa y reset mediante capturas directas de Vivado.

`tb_top` finaliza con `$finish` incluso al reportar errores; el resultado se determina leyendo sus comprobaciones, no solo el código de salida del proceso.

### 5.1. Simulación específica de la interfaz local

`tb_local_interface.sv` prueba S4 de forma aislada: 39 comprobaciones autoverificables sobre LED, 7 segmentos, buzzer (prioridades y duración) y contenido exacto de 5 pantallas LCD, con 0 errores. Detalle, formas de onda y modelos de referencia en el [informe de S4](interfaz_local_verificacion.md#2-simulación-e-implementación).

### 5.2. Simulación post-implementación temporizada: recepción y validación de una letra

No se completó una simulación post-implementación con SDF por su tiempo de ejecución. La recepción y validación de una letra queda respaldada por la simulación conductual de `tb_top` (sección 5, 0 errores) y por el análisis estático de timing sobre el diseño ya enrutado (sección 6, WNS 0.888 ns), que cubren el comportamiento funcional y el margen temporal por separado.

## 6. Síntesis, implementación y análisis temporal

La implementación completa usa la Artix-7 `xc7a35tcpg236-1`, reloj de 10 ns y `src/design/constraints/Basys-3-Master.xdc`. Se ejecutaron síntesis, optimización, colocación y enrutamiento con parámetros funcionales por defecto.

| Indicador del top enrutado | Resultado |
|---|---:|
| LUT | 1501 / 20800 (7.22 %) |
| Registros | 1344 / 41600 (3.23 %) |
| Latches | 0 |
| BRAM | 0 |
| WNS | 0.888 ns |
| TNS | 0.000 ns |
| WHS | 0.122 ns |
| THS | 0.000 ns |
| DRC del ruledeck ejecutado | 0 incidencias |

Reportes de implementación: [utilización](resultados/integracion/utilization_routed.rpt), [timing](resultados/integracion/timing_routed.rpt), [DRC](resultados/integracion/drc_routed.rpt).

El margen positivo respalda las restricciones internas de 100 MHz. El reporte identifica cuatro entradas sin input delay y 25 salidas sin output delay. Parte de estas interfaces es asíncrona o periférica; su protocolo y márgenes requieren análisis específico. No se concluye cumplimiento de todos los tiempos del LCD a partir del WNS interno.

La síntesis emitió avisos de bits de bus sin carga, incluidos campos reservados. La consulta de la netlist confirmó la ausencia de latches.

Los valores de S1/S2 aislados y del top UART de ensayo pertenecen a diseños distintos. No se suman directamente para inferir el uso final, porque la síntesis optimiza la lógica en contexto.

## 7. Pruebas físicas y presentación funcional

### 7.1. Comunicación UART

El [ensayo UART](uart_verificacion.md) utiliza `uart_protocol_hw_test_top` y `basys3_uart_test.xdc`. Una letra válida produce un mensaje START fijo, lo que permite comprobar la comunicación bidireccional antes de integrar las reglas del juego.

### 7.2. Demostración del juego completo: video

[Video de la demostración funcional](https://youtu.be/9DqGet_NECk): partida completa en la Basys 3 con la aplicación de PC, mostrando selección de modo, LCD, displays, LED de estado y buzzer en hardware real.

## 8. Problemas, tratamientos y limitaciones

| Situación | Análisis y resultado |
|---|---|
| Evaluación del motor durante selección | Caso dirigido añadido al banco; descarte sin procesamiento diferido comprobado |
| Envío de palabra secreta final | Puerto `secret_word` y captura en top incorporados; mensajes finales comprobados en integración |
| Evento nuevo simultáneo al consumo del anterior | Reemplazo comprobado en tb_top |
| Ráfaga mientras el registro de evento está lleno | Prueba dirigida con seis errores consecutivos perdió cuatro eventos, incluido LOSE_ATTEMPTS; operación limitada a espera por respuesta |
| Fin de partida durante un tono | La FSM de buzzer solo atiende eventos en reposo; la prueba dirigida confirmó omisión del tono final durante actividad |
| Preparación de LCD | Medida RTL RS→E de 10 ns; contraste con hoja de datos y arranque documentado en S4 |
| Lectura fragmentada de GUI | El lector entrega fragmentos sin esperar LF; no hay garantía de recuperación automática ante timeout o reset durante partida |

| Mapa UART | RX_DATA implementado solo lectura y new_rx W1C; diferencia frente a la descripción RW del enunciado declarada en S3 |

Las [pruebas dirigidas](resultados/integracion/limites_verificacion.txt) permiten identificar los límites de capacidad y temporización. Los fallos de estas pruebas corresponden a condiciones distintas de los escenarios aprobados en la regresión nominal.

## 9. Conclusiones

El diseño modular permitió integrar selección y evaluación de palabras, control temporal, comunicación serial y presentación local sin trasladar reglas a la PC. La regresión respalda los escenarios implementados y la síntesis confirma un uso moderado de recursos, ausencia de latches y cumplimiento de las restricciones internas de 100 MHz.

La capacidad del registro de eventos limita la recepción de ráfagas; la recuperación de la terminal y los márgenes temporales del LCD requieren atención específica. El análisis temporal estático y la simulación conductual permiten evaluar aspectos distintos del diseño y deben interpretarse según el alcance de cada prueba.

## 10. Referencias

- EL3313 Taller de Diseño Digital. *Proyecto 2: Ahorcado FPGA–PC*, II Semestre de 2026, secciones 3–4 y rúbricas del Anexo A.
- [Documentación del diseño e interfaces](../diseno/README.md).
- [Manual PmodCLP, Digilent](https://digilent.com/reference/_media/pmod:pmod:pmodCLP_rm.pdf).
- [HD44780U: controlador LCD, Hitachi](https://www.sparkfun.com/datasheets/LCD/HD44780.pdf).
- [Basys 3: restricciones de referencia, Digilent](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc).
- [Historial de integración del proyecto](https://github.com/aguilar697/Taller-Diseno-de-Sistemas-Digitales/commits/main/Proyecto2_Ahorcado).
