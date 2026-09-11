# Informe de verificación — Motor del juego

**Estado:** plantilla de entrega, pendiente de resultados y evidencias.
**Subsistema:** S2. **Responsable:** Kevin Aguilar.

Los campos «Pendiente» no representan resultados de ejecución. Las tablas
separan los criterios esperados del diseño de las observaciones experimentales.

## 1. Objetivo y alcance

Verificar selección de palabras, registro de letras utilizadas, actualización
del patrón y detección de palabra completa. El alcance de cada ejecución se
identifica como motor aislado, integración con UART/controlador o sistema completo.

| Identificación de la ejecución | Valor |
|---|---|
| Fecha | Pendiente |
| Commit de las fuentes verificadas | Pendiente |
| Herramienta y versión | Pendiente |
| Dispositivo | Pendiente; objetivo: xc7a35tcpg236-1 |
| Top y alcance | Pendiente |
| Etapa: RTL, post-síntesis o post-implementación | Pendiente |
| Restricciones utilizadas | Pendiente |

## 2. Fundamento del diseño

El [tercer nivel](../diseno/nivel_3_motor_del_juego.md) define la interfaz y los
bloques. El [cuarto nivel](../diseno/nivel_4_motor_del_juego.md) desarrolla sus
circuitos y FSM. La evaluación compara la letra con las posiciones válidas y
consulta la máscara de letras utilizadas. El patrón siguiente permite detectar
la última letra en la misma actualización. Las pruebas contrastan esa
especificación con las señales observadas.

## 3. Configuración prevista en Vivado

| Elemento | Configuración de referencia |
|---|---|
| Design Sources | word_engine.sv, word_rom.sv, word_lfsr.sv, letter_evaluator.sv |
| Top de diseño aislado | word_engine |
| Simulation Source / top | word_engine_tb.sv / word_engine_tb |
| Banco de referencia | word_bank.txt |
| Reloj del testbench | Período de 10 ns |
| Finalización | Run All hasta `$finish`; una discrepancia produce `$fatal` |

El banco de referencia debe encontrarse en el directorio de trabajo del
simulador, normalmente `<proyecto>.sim/sim_1/behav/xsim/`. También se admite la
ruta de fuentes del repositorio desde `Proyecto2_Ahorcado`. El archivo de texto
solo se utiliza en pruebas y no es una dependencia de la FPGA.

La restricción de reloj prevista es:

```tcl
create_clock -name clk -period 10.000 [get_ports clk]
```

La configuración efectiva y las demás restricciones se registran con la
ejecución. Los puertos sin restricciones limitan la validez del análisis temporal.

## 4. Simulación RTL autoverificable

| ID | Caso | Criterio esperado | Resultado / evidencia |
|---|---|---|---|
| T01 | Reset y nueva partida | Limpieza y prioridad reset > new_game > letra | Pendiente |
| T02 | ROM | 50 palabras distintas A–Z de longitud 4–12; índices externos inválidos | Pendiente |
| T03 | LFSR | 63 estados no nulos y retorno a semilla | Pendiente |
| T04 | Fácil | Todas las entradas alcanzables | Pendiente |
| T05 | Difícil | Solo palabras de seis o más letras | Pendiente |
| T06 | Patrón inicial | Guiones bajos válidos y espacios en relleno | Pendiente |
| T07 | Letra correcta | Todas las coincidencias reveladas juntas | Pendiente |
| T08 | Letra incorrecta | Patrón conservado; letra registrada como utilizada | Pendiente |
| T09 | Repetida correcta/incorrecta | Sin nuevo acierto ni cambio de progreso | Pendiente |
| T10 | ASCII inválido | Sin cambios en el progreso | Pendiente |
| T11 | Última letra | Patrón completo y word_complete actualizados juntos | Pendiente |
| T12 | Modo y selección | Modo capturado; letras ignoradas en IDLE/selección | Pendiente |
| T13 | Solicitudes consecutivas | Resultados asociados al ciclo correcto | Pendiente |

| Indicador de ejecución | Resultado medido |
|---|---|
| Mensaje final del testbench | Pendiente |
| Comprobaciones ejecutadas | Pendiente |
| Partidas ejercitadas | Pendiente |
| Tiempo simulado | Pendiente |
| Errores y advertencias | Pendiente |

### Capturas de formas de onda

Las evidencias se ubican en `resultados/motor/` cuando estén disponibles.
Los nombres siguientes son previstos, no enlaces a archivos existentes.

| Figura | Archivo previsto | Señales de interés |
|---|---|---|
| 1. Selección e inicio | seleccion_palabra.png | new_game, difficulty, word_ready, word_length, revealed_word |
| 2. Coincidencias múltiples | letra_correcta.png | letter_valid, letter_ascii, letter_correct, revealed_word |
| 3. Repetición | letra_repetida.png | Solicitudes original/repetida, letter_repeated, patrón |
| 4. Palabra completa | palabra_completa.png | Última letra, patrón y word_complete |
| 5. Reinicio | reinicio.png | reset/new_game y limpieza del estado |

**Descripción e interpretación de las figuras:** pendiente. Cada evidencia
identifica escala temporal, valores de entrada y resultado observado.

## 5. Síntesis y recursos

| Condición | Valor |
|---|---|
| Modo: aislado out-of-context o integrado | Pendiente |
| Dispositivo y restricciones | Pendiente |
| Reporte y commit asociados | Pendiente |

| Recurso / comprobación | Resultado |
|---|---|
| LUT | Pendiente |
| Registros | Pendiente |
| Latches inferidos | Pendiente |
| BRAM / DSP | Pendiente |
| Errores y advertencias críticas | Pendiente |
| Linter y observaciones de netlist | Pendiente |

**Esquemáticos RTL y sintetizado:** pendientes de evidencia. La correspondencia
con el cuarto nivel y las optimizaciones se analizan a partir de los esquemáticos
obtenidos de la herramienta.

## 6. Implementación y temporización

| Condición del análisis | Valor |
|---|---|
| Etapa: síntesis o posterior a place-and-route | Pendiente |
| Período de reloj aplicado | Pendiente |
| Puertos/caminos sin restricciones | Pendiente |
| Reporte y versión de fuentes | Pendiente |

| Indicador | Resultado |
|---|---|
| WNS / TNS | Pendiente |
| WHS / THS | Pendiente |
| DRC | Pendiente |

**Camino crítico y cumplimiento temporal:** pendiente. Los resultados posteriores
a síntesis se distinguen de los obtenidos después de implementación.

## 7. Integración y simulación temporizada

| Prueba | Criterio esperado | Resultado / evidencia |
|---|---|---|
| Recepción UART y evaluación | Correspondencia entre byte, solicitud y patrón | Pendiente |
| Fin de partida | Sin pérdida de eventos por UART ocupado | Pendiente |
| Letras fuera de partida | Sin procesamiento tardío de entradas descartadas | Pendiente |
| Tiempo e intentos en S1 | Derrota y prioridad de eventos correctas | Pendiente |

La entrega requiere simulación post-implementación temporizada de al menos la
recepción y validación de una letra. El testbench RTL aislado accede a señales
internas por jerarquía: no se supone que sus nombres se conserven en una netlist.
La prueba temporizada de integración debe operar sobre las interfaces del top.

## 8. Pruebas físicas

| Prueba | Observación | Evidencia |
|---|---|---|
| Partida fácil | Pendiente | Pendiente |
| Partida difícil | Pendiente | Pendiente |
| Acierto, repetición y derrota | Pendiente | Pendiente |
| LCD, displays, LED, buzzer y terminal | Pendiente | Pendiente |

## 9. Problemas y correcciones

| Problema observado | Causa | Corrección y commit | Resultado de nueva prueba |
|---|---|---|---|
| Pendiente | Pendiente | Pendiente | Pendiente |

## 10. Análisis y conclusiones

**Comparación entre diseño y resultados:** pendiente.

**Limitaciones observadas:** pendiente.

**Conclusiones sustentadas en evidencias:** pendientes.

## Referencias

- Instructivo Proyecto 2 EL3313: entregables y rúbricas de verificación e informe.
- [Diseño de tercer nivel](../diseno/nivel_3_motor_del_juego.md).
- [Diseño de cuarto nivel](../diseno/nivel_4_motor_del_juego.md).
- [Testbench del motor](../../src/testbench/word_engine/word_engine_tb.sv).
