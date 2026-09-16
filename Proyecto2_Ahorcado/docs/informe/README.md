# Informe técnico — Ahorcado FPGA–PC

**EL3313 Taller de Diseño Digital · II Semestre 2026 · Grupo 3**

**Integrantes:** Kenneth Campos, Kevin Aguilar, Daniel Puentes y Kevin Cortés.

**Fecha de consolidación documental:** 16 de septiembre de 2026.

**Fuentes integradas de referencia:** `16d6f73`; sin cambios HDL respecto de `70c6f68`.

## Resumen

Se implementó un juego de Ahorcado en Basys 3 con lógica de control, banco de palabras, evaluación de letras, temporización, periféricos locales y comunicación UART con una terminal Python. La FPGA mantiene todas las reglas del juego. La PC transmite letras y presenta los mensajes recibidos.

La regresión conductual ejecutó 17 bancos: 16 con comprobaciones satisfactorias y uno de reset basado solamente en estímulos. El motor completó 38 636 comprobaciones en 129 partidas. El diseño completo se sintetizó y enrutó a 100 MHz con WNS de 0.888 ns, 1501 LUT, 1344 registros y ningún latch. El equipo reporta funcionamiento físico de LCD, buzzer y terminal; la evidencia incorporada distingue ese reporte de los ensayos documentados. No se incorpora todavía simulación post-implementación con retardos ni registro audiovisual completo de ambos modos.

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

## 4. Estrategia de validación y procedencia

Se distinguen cuatro niveles de evidencia: bancos individuales, integración conductual, implementación y ensayo físico. Las capturas históricas y los reportes no se reinterpretan como resultados de etapas distintas.

| Evidencia | Herramienta y fecha | Fuentes / alcance |
|---|---|---|
| Motor original y prueba ampliada | Vivado/XSim 2026.1, 10/09/2026 | Revisiones b8bb7cc y 292ba93; motor aislado |
| Capturas Wave del motor | Aportadas el 16/09/2026 | word_engine_tb_behav; simulación conductual, cinco casos |
| Capturas UART de Puentes | Vivado 2026.1; incorporadas en 16d6f73 | Bancos de protocolo, tb_top y ensayo físico UART aislado |
| Regresión de integración | Vivado/XSim 2026.1, 15/09/2026 | 70c6f68; fuentes HDL y bancos idénticos en 16d6f73 |
| Síntesis e implementación completa | Vivado 2026.1, 15/09/2026 | top, xc7a35tcpg236-1 y XDC del sistema completo |
| Operación física completa | Reportada por el equipo | LCD, buzzer y terminal funcionando; demostración grabada según el equipo, sin enlace incorporado |

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

**Figura 1.** Captura de la ejecución conductual integrada aportada por Puentes. El encabezado de Vivado identifica Behavioral Simulation; no es simulación temporizada post-implementación.

Las formas de onda de S1 se conservan en su informe. El [informe de S2](motor_verificacion.md#capturas-de-formas-de-onda-en-vivado) incorpora cinco capturas directas de la ventana Wave, aportadas por Kevin Aguilar el 16/09/2026: selección fácil, selección difícil, acierto y repetición, palabra completa y reset. Complementan la evidencia conductual; no sustituyen el autochequeo ni la simulación temporizada.

`tb_top` finaliza con `$finish` incluso al reportar errores; el resultado se determina leyendo sus comprobaciones, no solo el código de salida del proceso. No existe un banco dedicado a S4 que decodifique texto LCD, valide todas las temporizaciones o compruebe cada tono.

## 6. Síntesis, implementación y análisis temporal

La implementación completa usa la Artix-7 `xc7a35tcpg236-1`, reloj de 10 ns y `src/design/constraints/Basys-3-Master.xdc`. Se ejecutaron síntesis, optimización, colocación y enrutamiento con parámetros funcionales por defecto. Esta ejecución no programó la tarjeta ni generó evidencia de funcionamiento físico.

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

Reportes originales: [utilización](resultados/integracion/utilization_routed.rpt), [timing](resultados/integracion/timing_routed.rpt), [DRC](resultados/integracion/drc_routed.rpt).

El margen positivo respalda las restricciones internas de 100 MHz. El reporte identifica cuatro entradas sin input delay y 25 salidas sin output delay. Parte de estas interfaces es asíncrona o periférica; su protocolo y márgenes requieren análisis específico. No se concluye cumplimiento de todos los tiempos del LCD a partir del WNS interno.

La síntesis emitió avisos de bits de bus sin carga, incluidos campos reservados. No se declara ausencia total de warnings. La ausencia de latches se comprueba en la netlist; no se adjunta ejecución independiente de linter.

Los valores de S1/S2 aislados y del top UART de ensayo pertenecen a diseños distintos. No se suman directamente para inferir el uso final, porque la síntesis optimiza la lógica en contexto.

## 7. Pruebas físicas y matriz de evidencia

El [informe UART](uart_verificacion.md) conserva la comunicación de ida y vuelta del ensayo `uart_protocol_hw_test_top`: una letra válida produce un START fijo. La captura de bitstream de ese ensayo utiliza `basys3_uart_test.xdc`; no acredita por sí sola una partida del top completo.

El equipo reporta operación del sistema completo con LCD, buzzer y terminal. Para el registro de evaluación se distingue la observación reportada de las capturas o mediciones actualmente adjuntas:

| Requisito | Evidencia disponible | Alcance adicional no incorporado |
|---|---|---|
| Banco, LFSR y restricción difícil | Autochequeo de S2 y capturas directas de selección en Vivado | Registro audiovisual de ambos modos |
| Repetición y revelado múltiple | Autochequeo y capturas directas del motor en Vivado | Demostración audiovisual integrada |
| Victoria y derrotas | tb_top y pruebas S1 | Registro físico de ambos modos y causas de derrota |
| UART bidireccional | Autochequeo y ensayo físico aislado | Registro de una partida completa en GUI y FPGA |
| LCD, displays, LED y buzzer | RTL integrado y funcionamiento reportado por el equipo | Capturas legibles y audio; medición de duración visible del resultado |
| Recursos y timing | Reportes enrutados del top completo | No sustituyen simulación con retardos |
| Recepción y validación temporizada | Sin evidencia adjunta | Simulación post-implementación requerida por el instructivo |
| Video de defensa | Sin enlace incorporado | Registro audiovisual de la entrega |

## 8. Problemas, tratamientos y limitaciones

| Situación | Tratamiento o resultado en la versión actual |
|---|---|
| Evaluación del motor durante selección | Caso dirigido añadido al banco; descarte sin procesamiento diferido comprobado |
| Envío de palabra secreta final | Puerto `secret_word` y captura en top incorporados; mensajes finales comprobados en integración |
| Evento nuevo simultáneo al consumo del anterior | Reemplazo comprobado en tb_top |
| Ráfaga mientras el registro de evento está lleno | Prueba dirigida con seis errores consecutivos perdió cuatro eventos, incluido LOSE_ATTEMPTS; operación limitada a espera por respuesta |
| Fin de partida durante un tono | La FSM de buzzer solo atiende eventos en reposo; la prueba dirigida confirmó omisión del tono final durante actividad |
| Preparación de LCD | Medida RTL RS→E de 10 ns; contraste con hoja de datos y arranque documentado en S4 |
| Lectura fragmentada de GUI | El lector entrega fragmentos sin esperar LF; no hay garantía de recuperación automática ante timeout o reset durante partida |
| Duración visible de resultado | S1 cuenta 3 s desde fin; no consume screen_done; medición visual completa no incorporada |
| Mapa UART | RX_DATA implementado solo lectura y new_rx W1C; diferencia frente a la descripción RW del enunciado declarada en S3 |

Los [registros de pruebas dirigidas](resultados/integracion/limites_verificacion.txt) preservan las observaciones adicionales. Estas pruebas de límite son distintas de la regresión nominal y no se contabilizan como casos aprobados. El funcionamiento físico reportado y estos límites pueden coexistir: corresponden a condiciones de estímulo y observación diferentes.

## 9. Conclusiones

El diseño modular permitió integrar selección y evaluación de palabras, control temporal, comunicación serial y presentación local sin trasladar reglas a la PC. La regresión respalda los escenarios implementados y la síntesis confirma un uso moderado de recursos, ausencia de latches y cumplimiento de las restricciones internas de 100 MHz.

La evaluación completa exige distinguir éxito conductual, timing estático y funcionamiento experimental. La evidencia actual no acredita la simulación temporizada requerida, todos los casos de periferia ni el registro físico completo de ambos modos. La capacidad de eventos, la recuperación de la terminal y los márgenes LCD constituyen límites identificados de esta implementación. Las conclusiones se restringen a los ensayos y reportes adjuntos.

## 10. Referencias

- EL3313 Taller de Diseño Digital. *Proyecto 2: Ahorcado FPGA–PC*, II Semestre de 2026, secciones 3–4 y rúbricas del Anexo A.
- [Documentación del diseño e interfaces](../diseno/README.md).
- [Manual PmodCLP, Digilent](https://digilent.com/reference/_media/pmod:pmod:pmodCLP_rm.pdf).
- [HD44780U: controlador LCD, Hitachi](https://www.sparkfun.com/datasheets/LCD/HD44780.pdf).
- [Basys 3: restricciones de referencia, Digilent](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc).
- [Historial de integración del proyecto](https://github.com/aguilar697/Taller-Diseno-de-Sistemas-Digitales/commits/main/Proyecto2_Ahorcado).
