# Informe de verificación — Interfaz local

**Subsistema:** S4. **Responsable:** Kevin Cortés.

## 1. Objetivo y fundamento

Presentar el estado del juego mediante LCD, siete segmentos, LED y buzzer. El LCD requiere secuencias de inicialización, preparación, pulso y ejecución; los displays usan barrido multiplexado y el buzzer divide el reloj mediante contadores. El [diseño de S4](../diseno/nivel_3_interfaz_local.md) desarrolla interfaces, FSM, registros y valores nominales.

## 2. Evidencia disponible

| Comprobación | Estado y alcance |
|---|---|
| Integración RTL | `tb_top` instancia S4 y comprueba salidas conocidas después de reset; no decodifica el contenido completo de la LCD ni todos los tonos |
| Síntesis e implementación | S4 forma parte del `top` enrutado; recursos y timing se reportan en el [informe general](README.md) |
| Funcionamiento físico | El equipo reporta funcionamiento de LCD, buzzer y terminal en la tarjeta; las capturas o registro audiovisual completo no están incorporados |
| Banco específico de S4 | No existe un testbench dedicado a este subsistema en la versión entregada |

Los resultados no equivalen a cobertura automática completa de escritura LCD, barrido y audio. No se asignan valores experimentales de frecuencia, duración o margen eléctrico que no hayan sido medidos.

## 3. Revisión temporal y funcional

Una prueba dirigida de `lcd_peripheral` a 100 MHz midió 10 ns entre el cambio de RS y la subida de E. La hoja HD44780U indica mínimos de 40 ns a 4.5–5.5 V y 60 ns a 2.7–4.5 V. El controlador concreto del PmodCLP debe contrastarse con su propia especificación: Digilent identifica un KS0066. El ancho del pulso E no sustituye la preparación previa de RS.

El RTL espera 15 ms desde reset antes del primer comando; el manual PmodCLP establece al menos 20 ms desde alimentación. El tiempo de configuración de FPGA puede añadir margen en la prueba física, pero esa contribución no está modelada en el periférico. El funcionamiento observado no demuestra por sí solo todos los márgenes eléctricos.

Una prueba del buzzer con duraciones reducidas y la misma FSM mostró que un pulso de fin durante un tono previo se pierde. Los valores utilizados fueron 20/30/40 ciclos de duración y 2/3/4 ciclos de semiperíodo para acierto/error/fin. No se modifica la implementación física: se documenta el alcance de la prioridad de eventos, que solo opera en reposo.

El temporizador de S1 mantiene el estado final 3 s desde la decisión de fin. Como no espera `screen_done`, se necesita una medición separada de cuánto permanece completo el resultado en la LCD. Esta revisión no atribuye una duración experimental inferior sin esa medición.

## 4. Verificación complementaria

| Caso | Evidencia requerida para cerrar la comprobación |
|---|---|
| Inicialización | Secuencia de comandos, espera inicial y estado busy |
| Escritura LCD | RS, E, DB y lectura de la pantalla decodificada; preparación y ancho de pulso |
| Clear/home | Aceptación, espera larga, busy/done y rechazo de comandos mientras está ocupado |
| Pantallas | Selección, partida y resultado; actualización completa y duración visible final |
| Displays y LED | Correspondencia de datos, polaridad, barrido y tres estados visuales |
| Buzzer | Frecuencia/duración y eventos simultáneos o durante un tono |
| Tarjeta | Registro legible de LCD y displays, junto con audio y terminal |

## 5. Análisis y conclusión

La interfaz local está conectada y sintetizada con el sistema. El equipo reporta operación física satisfactoria; la evidencia automatizada disponible no comprueba todos los casos de periferia. Las limitaciones identificadas se concentran en margen temporal, eventos sonoros durante actividad y coordinación de visualización con S1. La implementación se conserva y el informe delimita lo comprobado.

## Referencias

- [Diseño y FSM de interfaz local](../diseno/nivel_3_interfaz_local.md).
- [Manual PmodCLP de Digilent](https://digilent.com/reference/_media/pmod:pmod:pmodCLP_rm.pdf).
- [HD44780U, características temporales](https://www.sparkfun.com/datasheets/LCD/HD44780.pdf).
- [Registros de comprobaciones dirigidas](resultados/integracion/limites_verificacion.txt).
