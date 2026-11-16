# Verificación digital integrada PWM–ADC y temporización de plataforma

## Alcance

Revisión del 15 de noviembre de 2026, Vivado/Vitis 2026.1 y Basys 3 xc7a35tcpg236-1. Conserva 100 MHz, FPU simple, BRAM compartida de 32 KiB, I-cache de 8 KiB y las fuentes originales de PWM, ADC y PR. No genera bitstream ni programa la FPGA; tampoco conecta potencia. La compatibilidad con 2025.1 sigue pendiente.

Hay dos verificaciones distintas: simulación RTL del subsistema PWM–ADC con maestros AXI de prueba, e implementación exploratoria del sistema completo. **No se simula MicroBlaze ejecutando PR.** Compilar el programa por separado no equivale a ejecutar sus accesos junto con estos estímulos.

## Reconstrucción de las pruebas funcionales

Desde la raíz del repositorio, con Python y Vivado 2026.1 instalados:

```powershell
python -B Proyecto4_Inversor_Monofasico/scripts/verificacion/ejecutar_integracion_digital.py <salida_externa_nueva> --vivado-home <instalacion_Vivado>
```

El ejecutor conserva comandos, hashes y logs en la salida externa y exige código correcto, ausencia de errores/fatales y marcador TEST PASSED. Reutiliza los cinco testbenches PWM existentes sin modificarlos. `tb_pwm_timing` se ejecuta como RTL funcional, **sin SDF**: su nombre no significa simulación post-routing. `--solo-integracion` permite repetir únicamente el nuevo testbench.

| Testbench | Comprobaciones | Resultado |
|---|---:|---|
| tb_pwm_deadtime | 20 | PASS |
| tb_pwm_core | 1064490 | PASS |
| tb_pwm_axi | 1220 | PASS |
| tb_pwm_adc | 260195 | PASS |
| tb_pwm_timing, RTL sin SDF | 81 | PASS |
| tb_pwm_adc_axi, monitor continuo de REFERENCE | 65602 | PASS |

La suite completa quedó en `%TEMP%/p4_sim_digital_20261115_a/`. La repetición con traza quedó en `%TEMP%/p4_sim_digital_20261115_b/`; la pasada final, con monitor continuo de REFERENCE, en `%TEMP%/p4_sim_digital_20261115_c/`. Los intentos anteriores conservaron 60740 comprobaciones integradas; el monitor final amplía esa cobertura. El caso negativo `+INJECT_ERROR` cambia únicamente un valor esperado y termina con ERROR_INYECTADO_DETECTADO, sin TEST PASSED. El ejecutor comprueba esa detección incluso si XSim devuelve cero después de `$fatal`.

## Modelo de adquisición y contratos verificados

El nuevo testbench instancia `pwm_system_axi` y `adc_system_axi` completos, ambos con dirección local de 12 bits. Dos maestros de prueba conducen sus interfaces AXI4-Lite; el SmartConnect no forma parte de esta simulación. Su conexionado se comprueba por separado en el BD.

`xadc_digital_model.sv` sustituye **solo en este conjunto de simulación** el módulo generado xadc_wiz_0. No debe añadirse a síntesis ni compilarse junto con el XCI real. Reutiliza la estrategia del testbench PWM–ADC existente: respuesta EOC modelada con cuenta de 100 y respuesta DRDY con cuenta de 7, conducidas en flanco negativo. No representa voltaje, ACS712, ruido, calibración ni latencia física garantizada del XADC.

Se verifican reset activo bajo, reloj común de 10 ns, habilitación y running, período PWM de 10000 ciclos, tiempo muerto exacto de 100 ciclos en ambas ramas y ausencia de conducción simultánea. period_start y trigger duran un ciclo; el trigger aparece en fase 5000 y llega directamente al ADC. Las dos publicaciones nominales no producen timeout, missed_trigger ni overrun.

Los accesos AXI comprueban STATUS=3 tras publicación, SAMPLE=0x00010123 y después 0x00020124, y ACK_ID=1/2. Una escritura ACK con los mismos 16 bits bajos pero distinta mitad alta no consume la muestra. Tampoco la consume el token de la muestra anterior. El token completo correcto limpia new_data y conserva valid; ERROR queda en cero. Esto prueba comparación de 32 bits, no el agotamiento del contador de generaciones.

REFERENCE se escribe durante un período y se comprueba por observación, sin force/release, que `active_reference_q` conserva el valor anterior hasta el siguiente period_start. Ese registro interno solo se observa para verificar el punto de aplicación; no se altera RTL ni se sustituye lógica funcional.

## Tiempos medidos y límites

Los monitores muestrean después de las actualizaciones de registros. Los siguientes tiempos se expresan respecto al comienzo de período; no son medidas eléctricas:

| Evento | Medición de esta prueba |
|---|---|
| Período PWM | 10000 ciclos = 100 us |
| Tiempo muerto | 100 ciclos = 1 us |
| Trigger ADC | Fase 5000 = 50 us |
| CONVST | Un ciclo después del trigger |
| Publicación SAMPLE | 111 ciclos desde trigger = 1,11 us; fase 5111 |
| CONVST a SAMPLE | 110 ciclos = 1,10 us, con este modelo digital |
| Fin de la transacción REFERENCE del maestro de prueba | Fase 5143 = 51,43 us |
| Aplicación de REFERENCE | Inicio del siguiente período, fase 0 |

El primer period_start se observó en ciclo 28 y el siguiente en 10028; trigger en 5028 y 15028. El monitor continuo confirmó la captura de REFERENCE exactamente al ciclo 10028 y rechazó cambios anteriores; el estímulo volvió a comprobar el valor en 10029. El registro se actualiza en el flanco de period_start.

La ISR del Timer, sus accesos reales a STATUS/SAMPLE/ACK_ID, el cálculo PR y la escritura REFERENCE no se ejecutan en este testbench. Timer y PWM se habilitan mediante escrituras AXI distintas: un período nominal de 100 us no fija su fase relativa. El maestro de prueba lee la muestra y escribe REFERENCE a su propio ritmo. **No se demuestra un retardo de 1,5 Ts**, WCET, estabilidad del lazo ni suficiencia dinámica de pila. Faltan ejecución en procesador y observación conjunta de period_start, trigger e ISR_DIAG.

## Investigación del reloj OOC de BRAM

El XDC generado `platform_microblaze_lmb_bram_0_ooc.xdc` contiene create_clock TS_CLKA y TS_CLKB de 20 ns. El BD configura Port_A_Clock y Port_B_Clock en 100 MHz, y los reportes superiores reconocen el reloj de entrada y sistema de 10 ns. Son restricciones de ámbitos distintos, no la duplicación anterior del create_clock de entrada.

`blk_mem_gen_v8_4/component.xml` registra `ttcl/bmg_ooc_xdc.ttcl` como producto utilizado en síntesis fuera de contexto. Esa plantilla instalada está codificada y no se modificó ni se deduce su lógica interna. El XDC generado explica el aviso Timing 38-316; no se considera que cambiar Port_A_Clock haya corregido la restricción OOC. Debe evaluarse una restricción OOC de proyecto soportada y repetir esa síntesis antes de cerrar el aviso. No se editan archivos AMD, productos generados ni excepciones para ocultarlo.

## Software comprobado nuevamente

La plataforma y las 18 fuentes PR se reconstruyeron en `%TEMP%/p4_digital_vitis_20261115_a/`, usando el XSA PWM–ADC de la etapa anterior. Las conexiones y parámetros de la nueva reconstrucción hardware se comprueban con el mismo verify_platform; no hay cambios funcionales de arquitectura.

El flujo valida macros reales PWM 0x44000000–0x44000FFF y ADC 0x44A00000–0x44A00FFF, ID Timer 0 y bases GPIO/UART. Se mantienen RV32IMF/ilp32f, -Os, linker validado, buffer 1024 muestras, heap 2048 y pila 1024. El BSP local conserva marco de 272 bytes y preservación de contexto; ABI_ESTATICA_PASS. El ELF reserva 32032 bytes y deja 736 libres. Los símbolos exigidos incluyen PR, app_isr y drivers. Persisten dos advertencias de estructura BSP y LOAD RWX; no se presentan como corregidas por el parche de alineación.

## Implementación exploratoria y bloqueo encontrado

El sistema completo se reconstruyó desde los scripts en la carpeta nueva `%TEMP%/p4_digital_20261115_a/`. La validación del BD y la síntesis pasaron, sin cambiar arquitectura ni constraints. Después se ejecutó `implement.tcl` hasta donde permitieron las restricciones actuales. opt_design terminó y produjo `microblaze_platform.runs/impl_1/platform_microblaze_wrapper_opt.dcp`.

Placement falló en el colocador de E/S:

```text
ERROR: [Place 30-58] IO placement is infeasible.
Number of unplaced IO Ports (5) is greater than number of available pins (0).
IO Group: SioStd: LVCMOS18 VCCO = 1.8 ... needs 5 sites.
ERROR: [Place 30-374] IO placer failed to find a solution
ERROR: [Place 30-99] Placer failed with error: 'IO Clock Placer failed'
```

Los cinco puertos son pwm_ah, pwm_al, pwm_bh, pwm_bl y pwm_period_start_o. Conservan IOSTANDARD DEFAULT y no tienen PACKAGE_PIN. Vivado intenta colocarlos como LVCMOS18, mientras los bancos 14, 16, 34 y 35 quedan fijados a 3,3 V por los puertos existentes LVCMOS33. El mensaje no significa que la FPGA carezca de cinco pines físicos libres: faltan restricciones eléctricas y ubicaciones acordadas compatibles con el resto de la tarjeta.

No se asignaron pines ni estándares para sortear el fallo, no se bajaron severidades y no se añadieron waivers. Se detuvo la implementación: **no hubo routing, checkpoint post-route ni phys_opt_design Explore**. El script abortó al fallar wait_on_run antes de llegar a esas operaciones. No existen WNS/TNS/WHS/THS post-routing de esta revisión ni resultados optimizados comparables.

| Resultado disponible | Valor y etapa |
|---|---|
| validate_bd_design y verify_platform | PASS |
| Síntesis nueva | PASS |
| LUT / registros / RAMB36 / DSP | 6843 / 4424 / 11 / 9, en síntesis |
| WNS / TNS | −0,129 ns / −7,364 ns, estimación de síntesis |
| Endpoints setup incumplidos | 78, en síntesis |
| WHS / THS / endpoints hold | +0,022 ns / 0 / 0, en síntesis |
| opt_design | Completado |
| place_design | Falló por E/S |
| Routing / optimización física post-route | No ejecutados |
| Timing post-routing | No disponible |
| Bitstream | No generado |

## DRC, CDC y metodología disponibles

Los reportes completos de síntesis están en `reports/synthesis/`: utilización, clocks, timing, check_timing, excepciones, DRC, CDC, metodología, I/O y checkpoint. El DRC de síntesis conserva NSTD-1/UCIO-1 como Critical Warning y 24 avisos DSP: DPIP-1 (6), DPOP-1 (12), DPOP-2 (6). El DRC de opt_design conserva los dos Critical Warning y 12 avisos DSP: DPIP-1 (6), DPOP-1 (3), DPOP-2 (3). No se debe confundir la reducción tras optimización lógica con corrección de pines o aprobación temporal.

La metodología de síntesis mantiene DPIR-1 (135) sobre entradas DSP conducidas desde registros con reset asíncrono, LUTAR-1 (1), TIMING-9 (1) y TIMING-18 (10). La advertencia DSP propone pipeline/reset síncrono, pero aplicarlo cambiaría RTL y requiere revisión de Kevin; no se hizo. LUTAR-1 sobre el preset de resumeack_reg y TIMING-9 de depuración continúan no concluyentes, no justificados por la simulación PWM–ADC.

report_cdc enumera nueve CDC-3 informativos con ASYNC_REG. check_timing no detecta registros sin reloj ni endpoints internos sin restricciones; sí quedan cinco entradas botones/switches y cinco salidas PWM sin delays, además de la comprobación de ancho de pulso CONVST. El trigger PWM–ADC permanece en el mismo dominio de 100 MHz; ello no resuelve los cruces internos de depuración. Estos reportes son de síntesis, no una auditoría CDC/metodológica post-route.

## Próximo paso y autorizaciones necesarias

Para continuar placement/routing debe acordarse con el equipo el conector, PACKAGE_PIN y estándar eléctrico de las cuatro señales PWM y del diagnóstico de período, comprobando conflictos con JA1, VAUX6 y otros puertos. No corresponde aceptar LVCMOS18 por defecto ni copiar pines arbitrarios. Después deben revisarse E/S/OOC, repetir implementación y evaluar si Explore cierra setup/hold; no se garantiza que lo haga.

Cualquier cambio de pipeline/reset en PWM requiere autorización y nuevas pruebas con Kevin. Cambios en adquisición, tiempos o reconocimiento requieren revisión de Kenneth; algoritmos, parámetros o estrategia temporal del PR requieren revisión de su responsable. No se propone editar fuentes AMD para los avisos de depuración ni reducir reservas para ganar memoria.

El bloqueo físico inmediato son las restricciones PWM. También siguen pendientes timing real, metodología de depuración, reloj OOC, advertencias BSP/RWX, pila dinámica, ejecución del PR y medición de fase/ISR. No se autoriza bitstream ni prueba de potencia.

Evidencia adicional: `%TEMP%/p4_digital_create_20261115_a.*`, `p4_digital_synth_20261115_a.*`, `p4_digital_impl_20261115_a.*`; log y DRC de `microblaze_platform.runs/impl_1/`. Vitis conserva `final_checks.json`, reporte ABI, ELF, mapa y logs en su workspace externo. Las fuentes ajenas y el reporte timing_ruteo.rpt se comprobaron por hash y permanecen intactos.

## Asignación provisional de JC — 16 de noviembre de 2026

Esta revisión posterior conserva el fallo del día anterior como evidencia histórica. Se autorizaron cinco asignaciones provisionales, exclusivamente para validación digital, tomadas del [Basys-3-Master.xdc oficial de Digilent](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc). No constituyen autorización para conectar la etapa de potencia ni sus drivers.

Antes de editar el XDC, Vivado abrió el checkpoint de síntesis y confirmó los nombres de los cinco puertos, la existencia de K17/M18/N17/P18/L17 en xc7a35tcpg236-1 y su disponibilidad. También comprobó JA1 y VAUX6. La búsqueda de constraints del Proyecto 4 no encontró otras asignaciones de los cinco pines propuestos.

| Puerto | PACKAGE_PIN | Conexión Basys 3 | IOSTANDARD |
|---|---|---|---|
| clk_i | W5 | Oscilador 100 MHz | LVCMOS33 |
| reset_i | U18 | BTN C | LVCMOS33 |
| UART_0_rxd / UART_0_txd | B18 / A18 | USB-UART | LVCMOS33 |
| BUTTONS_tri_i[0/1/2] | T18 / W19 / T17 | BTN U/L/R | LVCMOS33 |
| SWITCHES_tri_i[0/1] | V17 / V16 | SW0/SW1 | LVCMOS33 |
| LEDS_tri_o[0/1/2/3] | U16 / E19 / U19 / V19 | LED0/1/2/3 | LVCMOS33 |
| ISR_DIAG_tri_o[0] | J1 | JA1, reservado | LVCMOS33 |
| vauxp6 / vauxn6 | J3 / K3 | JXADC1/JXADC7, VAUX6 | LVCMOS33 |
| pwm_ah | K17 | JC1, provisional | LVCMOS33 |
| pwm_al | M18 | JC2, provisional | LVCMOS33 |
| pwm_bh | N17 | JC3, provisional | LVCMOS33 |
| pwm_bl | P18 | JC4, provisional | LVCMOS33 |
| pwm_period_start_o | L17 | JC7, provisional | LVCMOS33 |

Solo se añadió el bloque de estas cinco salidas a basys3_microblaze_diagnostic.xdc. Una comparación con la copia previa confirma que al retirar ese bloque se recupera exactamente el texto anterior: los demás pines y excepciones permanecen intactos. Las 21 asignaciones son únicas y LVCMOS33. El estándar digital no cambia el rango analógico admisible del XADC.

El XDC propio sigue sin create_clock: Clocking Wizard aporta el reloj de entrada de 10 ns. No se agregaron delays ficticios, false paths ni cambios de severidad. Se conservaron todos los pendientes previos y las fuentes de los demás integrantes.

### Implementación nueva con pines JC

La reconstrucción limpia se ejecutó fuera de Git, en `%TEMP%/p4_jc_20261116_a/`, con Vivado 2026.1 para xc7a35tcpg236-1. create_project.tcl, synthesize.tcl e implement.tcl terminaron con código 0. La validación del Block Design, síntesis, opt_design, placement y routing finalizaron correctamente. Se conservó el checkpoint de referencia antes de ejecutar la comparación post-route `phys_opt_design -directive Explore` prevista por el script existente.

| Resultado post-routing | Referencia | Explore |
|---|---:|---:|
| WNS (ns) | +0,255 | +0,255 |
| TNS (ns) | 0 | 0 |
| Endpoints setup incumplidos | 0 | 0 |
| WHS (ns) | +0,028 | +0,028 |
| THS (ns) | 0 | 0 |
| Endpoints hold incumplidos | 0 | 0 |
| Redes completamente enrutadas | 10 209 / 10 209 | 10 209 / 10 209 |
| Errores de routing | 0 | 0 |

Explore no mejoró ni degradó estos márgenes. El diseño final utiliza 6469 LUT (31,10 %), 4276 registros (10,28 %), 11 RAMB36 (22 %) y 9 DSP (10 %). Cumple setup y hold en los caminos temporizados del dominio de 100 MHz; esto no certifica las interfaces externas todavía sin delays ni la ejecución del software.

El DRC post-route no presenta errores ni Critical Warning: conserva 12 Warning DSP, distribuidos en DPIP-1 (6), DPOP-1 (3) y DPOP-2 (3). Ya no aparecen NSTD-1 ni UCIO-1. La metodología conserva DPIR-1 (135), LUTAR-1 (1), TIMING-9 (1) y TIMING-18 (10). No se modificó el RTL PWM para resolver recomendaciones de pipeline o reset.

LUTAR-1 y TIMING-9 continúan no concluyentes. report_cdc enumera nueve CDC-3 informativos con ASYNC_REG, pero esto no justifica por sí solo todos los cruces internos de depuración. check_timing no encuentra registros sin reloj, relojes múltiples ni endpoints internos sin restricciones. Mantiene cinco entradas botones/switches y cinco salidas PWM sin delays, ocho puertos adicionales sin delay cubiertos por false paths preexistentes, y la comprobación pendiente de ancho de pulso de CONVST. No se añadieron excepciones para ocultarlos.

Los reportes completos, checkpoints de referencia y Explore están en `reports/implementation/reference/` y `reports/implementation/optimized/` dentro de la construcción externa. Se conservan timing, utilización, DRC, metodología, CDC, clocks, check_timing, excepciones, I/O y estado de routing. Los logs de las tres etapas se guardan como `%TEMP%/p4_jc_*_20261116_a.*`.

El bloqueo de placement por los cinco pines queda resuelto. Antes de autorizar un bitstream de diagnóstico deben cerrarse o justificarse los avisos de depuración, los requisitos temporales de E/S, CONVST y la revisión del reloj OOC de memoria. Continúan pendientes las verificaciones BSP, pila y ejecución del software descritas previamente. No se generó bitstream, no se programó la FPGA y no se conectaron drivers ni potencia.
