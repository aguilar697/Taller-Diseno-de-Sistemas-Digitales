# Verificación de reconstrucción MicroBlaze V

Este documento registra la plataforma digital independiente. El montaje del inversor utiliza la [integración de laboratorio con asignación JA](../diseno/integracion_basys3.md).

## Alcance

Se reconstruyó la plataforma desde los scripts nuevos de `scripts/vivado/`, partiendo de una carpeta externa nueva, sin importar el XPR, BD o checkpoints exploratorios. Herramienta: Vivado 2026.1, dispositivo `xc7a35tcpg236-1`. La [guía de implementación](../diseno/implementacion_microblaze.md) describe arquitectura, comandos y limitaciones.

## Resultados de hardware

| Comprobación | Resultado |
|---|---|
| Creación y productos de IP | PASS |
| `validate_bd_design` | PASS |
| Parámetros y conexiones comprobados por `verify_bd.tcl` | PASS |
| RV32, 100 MHz, FPU simple, depuración | Configuración comprobada |
| BRAM compartida, 8192 × 32 bits | Comprobada; dos vistas de 32 KiB de una memoria |
| I-cache 8192 bytes, rango `0x0000–0x7FFF`, sin D-cache | Comprobada |
| Memoria y mapa AXI provisional | Comprobados |
| Reloj de entrada de 10 ns | Uno solo, sin duplicación |
| Asignaciones físicas | Seis puertos con pin y LVCMOS33 |
| Síntesis | PASS |
| LUT de síntesis | 6019 (28,94 %) |
| Registros de síntesis | 3782 (9,09 %) |
| BRAM | 11 RAMB36 (22 %) |
| DSP | 6 (6,67 %) |
| Timing estimado de síntesis | WNS −0,129 ns; TNS −7,364 ns; 78 endpoints setup |
| DRC de síntesis | 12 Warning: 9 DPOP-1 y 3 DPOP-2; sin Error |
| Metodología de síntesis | LUTAR-1 y TIMING-9, ambos Warning |
| Exportación XSA sin bitstream | PASS, tras guardar y regenerar el BD |
| Implementación/post-routing de esta reconstrucción | No ejecutada |
| Bitstream/programación | No realizados |

El WNS positivo de la prueba exploratoria anterior no se atribuye a esta construcción. Los reportes de síntesis no sustituyen timing post-routing. Las advertencias DPOP se refieren al pipeline de DSP dentro de la IP; no se cambió la arquitectura AMD para eliminarlas. LUTAR-1/TIMING-9 conservan su clasificación no concluyente.

El log de síntesis confirma inicialización BRAM con el `riscv_bootloop.elf` generado por AMD, no con el diagnóstico C. La descarga/asociación de la aplicación queda pendiente.

## Software

Las fuentes del diagnóstico y el linker previamente compilados se incorporaron por separado del software PR. `check_elf.py` pasó sobre el ELF exploratorio: RV32/ILP32F, entrada cero, pila alineada a 16 bytes, 11 136 bytes reservados y 21 632 libres. No es evidencia de ejecución en tarjeta.

El flujo Vitis 2026.1 se ejecutó también desde los scripts versionables con el XSA reconstruido y un workspace externo nuevo: plataforma/BSP y aplicación terminaron con código 0. El ELF nuevo pasó `check_elf.py`, mantiene entrada cero y ABI ILP32F, reserva 11 136 bytes y deja 21 632 libres. El compilador RISC-V es GCC 13.4.0; CMake confirma `-march=rv32imf_zicsr_zifencei_zicbom` y `-mabi=ilp32f`. No se ejecutó el programa en hardware.

`objdump` confirma instrucciones `fadd.s` y `feq.s`. `nm` confirma `_boot=0`, `_stack=0x2B80` y ausencia del símbolo `XMicroblaze_RISCV_ConfigTable` en este ELF mínimo. Esta observación no garantiza lo mismo para una aplicación ampliada.

Se reprodujeron dos advertencias `excess elements in struct initializer` en `xmicroblaze_riscv_g.c`. No se corrige ni se oculta la inconsistencia del BSP `standalone_v9_5`. El linker también advierte de un segmento LOAD con permisos RWX: código y datos pertenecen a la misma BRAM y este diagnóstico no establece protección de memoria. El aviso permanece visible; no se deshabilita con opciones de compilación.

## Incidencias y limitaciones

Durante la preparación se corrigieron únicamente scripts nuevos: tratamiento de rutas con espacios en `add_files`, retirada de una escritura a `C_EXT_RESET_HIGH` de solo lectura y comprobación de la cara interna de una interfaz jerárquica con `-boundary_type lower`. La primera exportación avisó de productos potencialmente desactualizados; el script final guarda y genera el BD antes de exportar y esa advertencia desapareció.

Los logs conservan avisos de board part vacío (se utiliza el part explícito), anchos 15/32 en el puerto B de BRAM, referencia temporal a un XCI interno de SmartConnect antes de regenerarlo, y selectores/waivers de IP AMD sin coincidencias. No se añadieron waivers propios ni se suprimieron mensajes. Los avisos de ancho e integración se deben revisar junto con la implementación definitiva; el rango asignado y la profundidad física sí pasaron las comprobaciones.

El lanzador `vitis.bat` instalado elimina comillas de argumentos: el procedimiento usa el nombre relativo del script y rutas externas sin espacios. No se modificó el lanzador del fabricante.

La compatibilidad con Vivado/Vitis 2025.1 sigue sin comprobarse. Antes de una prueba física faltan revisar metodología y timing post-route de la revisión elegida, justificar CDC de depuración y preparar carga/arranque del ELF. PWM, ADC y PR no se integraron.

## Evidencia conservada fuera de Git

Construcción: `%TEMP%/p4repro_20261111_v2/`.

- `microblaze_platform.xpr` y BD/wrapper/IP generados.
- `reports/bd_configuration.txt`.
- `reports/synthesis/`: utilización, clocks, check_timing, excepciones, DRC, metodología, CDC, timing, I/O y checkpoint.
- `platform_microblaze.xsa`, sin bitstream.
- Logs/journals `%TEMP%/p4_rebuild_create_v2.*`, `p4_rebuild_synth_final.*` y `p4_rebuild_export_final.*`.
- Workspace Vitis `%TEMP%/p4repro_vitis_20261111/`, con XPFM, BSP, ELF, mapa, logs de compilación y `elf_validation.json`.

Los intentos iniciales y sus logs también permanecen fuera del repositorio para trazabilidad. No se incorporan estos productos generados a Git.

## Revisión digital con ADC y GPIO — 15 de noviembre de 2026

Esta revisión corresponde al merge local 63ebb78 y a los cambios de plataforma descritos en [integración digital](../diseno/integracion_digital_microblaze.md). No reemplaza los resultados históricos anteriores. Se reconstruyó desde cero en `%TEMP%/p4int_20261115_b/`, importando una copia del XCI real y las fuentes ADC intactas. PWM, ya publicado en main, queda reservado sin instancia en esta etapa.

| Comprobación integrada | Resultado |
|---|---|
| BD, configuración y conexiones | PASS |
| SmartConnect | Un maestro y seis destinos |
| GPIO entradas/salidas | Canales 3+2 y 4+1 bits |
| Timer | Dos contadores de 32 bits, sin cascada |
| Interrupción | Timer a In0 y AXI INTC a MicroBlaze V |
| ADC | AXI4-Lite de 32 bits, ADDR_WIDTH=12, XADC regenerado |
| Memoria principal / caché / FPU | Sin cambios: 32 KiB compartidos / I-cache 8 KiB / simple |
| Síntesis superior | PASS |
| Recursos | 6257 LUT; 4133 registros; 11 RAMB36; 6 DSP; 1 XADC |
| Timing estimado de síntesis | WNS -0,129 ns; TNS -7,364 ns; 78 endpoints setup |
| Hold estimado | WHS +0,022 ns; THS 0 |
| DRC de síntesis | 12 Warning DPOP (9 DPOP-1 y 3 DPOP-2), sin Error |
| Metodología | LUTAR-1 (1), TIMING-9 (1) y TIMING-18 (5), todos Warning |
| Reloj y pins | Un reloj de entrada de 10 ns; todos los puertos con pin y estándar |
| Exportación XSA sin bitstream | PASS |
| Implementación y prueba física | No realizadas |

Los cinco TIMING-18 corresponden a botones y switches sin delays de entrada. No se ocultaron con falsos caminos nuevos. CDC y el tratamiento de esas entradas deben revisarse antes de la validación física. `check_timing` no encuentra registros sin reloj ni endpoints internos sin restricciones; señala también la comprobación de ancho de pulso en CONVST del XADC. No se interpreta esa lista como aprobación de metodología.

Se conserva el aviso Timing 38-316: la BRAM se sintetizó fuera de contexto con período de 20 ns frente a 10 ns en el diseño superior. El reloj real superior se comprobó en 100 MHz, pero la discrepancia de restricciones OOC debe corregirse o justificarse antes de la siguiente validación temporal. No se altera memoria ni se declara cierre post-routing. Persisten el aviso de ancho de BRAM 32/15, los avisos de referencia SystemVerilog y frecuencia no anotada de la interfaz ADC; sus conexiones efectivas a 100 MHz fueron comprobadas en el BD.

La primera pasada `%TEMP%/p4int_20261115_a/` se conserva: falló al usar los nombres de modelo del Timer como parámetros públicos y al buscar el segmento ADC `Reg` en lugar de `reg0`. Los scripts propios se corrigieron a COUNT_WIDTH/enable_timer2/mode_64bit y al segmento real. Vivado impone un mínimo de 4 KiB al bloque inferido: se utiliza el parámetro existente ADDR_WIDTH=12 para evitar alias, sin modificar RTL ajeno.

Los logs de esta revisión quedan en `%TEMP%/p4int_20261115_create_b.*`, `p4int_20261115_synth_b.*` y `p4int_20261115_export_b.*`; los reportes y DCP están en `reports/synthesis/` del proyecto externo. El BSP y el intento PR utilizan el workspace externo `%TEMP%/p4int_vitis_20261115_a/`. No se descarga ningún ELF a la plataforma parcial.

### BSP y macros comprobadas

La plataforma Vitis y el BSP se generaron con retorno cero a partir del XSA de 49 906 bytes, que no contiene bitstream. Se conservaron las dos advertencias `excess elements in struct initializer`. Compilador BSP GCC 13.4.0, `-march=rv32imf_zicsr_zifencei_zicbom`, `-mabi=ilp32f` y SDT; no se alteraron fuentes AMD.

| Macro real en xparameters.h | Valor |
|---|---|
| XPAR_GPIO_INPUTS_BASEADDR | 0x40000000 |
| XPAR_GPIO_OUTPUTS_BASEADDR | 0x40010000 |
| XPAR_UART_BASEADDR | 0x40600000 |
| XPAR_XINTC_0_BASEADDR | 0x41200000 |
| XPAR_TIMER_BASEADDR | 0x41C00000 |
| XPAR_FABRIC_TIMER_INTR | 0 |
| XPAR_TIMER_CLOCK_FREQUENCY | 100000000 |
| XPAR_ADC_SYSTEM_AXI_0_BASEADDR | 0x44A00000 |
| XPAR_ADC_SYSTEM_AXI_0_HIGHADDR | 0x44A00FFF |
| XPAR_PL_ADC_BASEADDR | 0x44A00000 |

No existe `XPAR_ADC_BASEADDR` ni una macro PWM. El primer intento Vitis detuvo correctamente la construcción al buscar aquel nombre ADC supuesto. Se corrigió el script propio para usar el nombre canónico real y se inició un segundo workspace `%TEMP%/p4int_vitis_20261115_b/`, conservando el anterior. No fue necesario editar `direcciones.h`: las definiciones se proporcionan como configuración de compilación de la copia, y PWM_BASE sigue representando solo una reserva.

### Resultado del PR completo: compilación C correcta, enlace fallido

Este apartado conserva el resultado histórico -O0. La revisión posterior descrita en [consolidación de software](../diseno/consolidacion_software_microblaze.md) sí enlaza el PR completo con -Os y ALIGN(16), y reconstruye el BSP local con marco de interrupciones de 272 bytes. En `%TEMP%/p4_pr_repro_20261115_c/` quedaron ELF, mapa y reportes: 32032 bytes reservados, 736 libres, auditoría ABI estática correcta y 191 comprobaciones C más receptor Python correctos. No se ejecutó en FPGA ni se integró PWM en el BD. Persisten las advertencias BSP/RWX, los riesgos de pila y la compatibilidad no comprobada con 2025.1.

El segundo intento generó de nuevo plataforma/BSP con retorno cero y compiló las 18 fuentes C de aplicación, control, drivers y UART. Se verificaron por SHA256 los 36 archivos C/H originales y sus copias. Se activó PLATAFORMA_CON_INTC=1 y se conservaron -O0, RV32/ILP32F, buffer de 1024 muestras y K_REG=1. No se modificaron las fuentes de control ni el BSP.

El enlace no cabe: solicita **39088 bytes (119,29 %), 6320 bytes más que 32768**. El mapa sitúa `_end` y `_stack` en 0x98B0, fuera de BRAM. El linker devuelve error y PR_APP_BUILD=1; no se genera un ELF final válido ni `pr_elf_validation.json`. Este es un resultado del mapa de enlace fallido, no el tamaño de un ELF ejecutable.

| Región del mapa | Tamaño |
|---|---:|
| .text.init | 328 bytes |
| .text, incluyendo alineación interna | 25076 bytes |
| .rodata | 1142 bytes |
| .bss + .sbss | 9060 bytes |
| .heap, incluyendo alineación | 2052 bytes; reserva útil 2048 |
| .stack | 1024 bytes |

Otras secciones y alineaciones completan la ocupación indicada por el linker. Permanecen el aviso LOAD RWX y los dos avisos BSP conocidos. El mapa no contiene el símbolo XMicroblaze_RISCV_ConfigTable; al no existir ELF final no se generaliza esa observación a un ejecutable futuro.

La prueba se detiene aquí, sin reducir buffer/heap/pila, ampliar BRAM ni modificar control. Se propone evaluar después -O2 o -Os como una prueba de configuración separada, manteniendo el algoritmo y los requisitos; no se ejecutó esa variante. El buffer por sí solo ocupa 8192 bytes y no permite inferir la ocupación completa.

Evidencia: `pr_exploratory/build/build.log`, `pr_exploratory/build/diagnostic.map`, objetos y archivos .su; `pr_build_inputs.json` contiene bases y hashes. El nombre `diagnostic.map` procede de nuestra configuración de linker reutilizada. El lanzador Vitis devolvió código externo cero aun mostrando una excepción Python: no interpretar ese código como éxito. Revisar APP_BUILD, logs y la existencia del reporte ELF de validación.

## Integración digital PWM–ADC–MicroBlaze V — 15 de noviembre de 2026

Esta revisión reconstruye la plataforma en `%TEMP%/p4_pwm_20261115_a/`, sin reutilizar checkpoints anteriores. Incorpora las cuatro fuentes PWM reales, intactas, como referencia `pwm_system_axi` con interfaz S_AXI de 32 bits, ADDR_WIDTH=12, MOD_LIMIT_Q15=27853 y MIN_ON_CYCLES=100. No fue necesario empaquetar otra IP. La [arquitectura actual](../diseno/implementacion_microblaze.md#arquitectura-y-conexiones) muestra sus conexiones.

SmartConnect tiene un maestro y siete destinos. M06_AXI llega al PWM en 0x44000000–0x44000FFF; M05_AXI conserva ADC en 0x44A00000–0x44A00FFF. Los demás segmentos no cambian. La comprobación de intervalos no encuentra solapamientos en datos. La vista de instrucciones sigue compartiendo la BRAM de 32 KiB. PWM y ADC reciben 100 MHz y el mismo reset AXI activo bajo. `pwm/pwm_trigger_o` llega directamente a `adc/pwm_trigger_i`, sin constante intermedia.

| Comprobación de esta reconstrucción | Resultado |
|---|---|
| Creación, validate_bd_design y conexiones verificadas | PASS |
| SmartConnect / Timer / INTC / GPIO | 7 destinos / dos contadores de 32 bits / IRQ normal In0 / canales 3+2 y 4+1 |
| Síntesis superior | PASS; no equivale a aprobación física |
| LUT | 6843 / 20800 (32,90 %) |
| Registros | 4424 / 41600 (10,63 %): 4423 FF y un AND/OR |
| BRAM / DSP / XADC | 11 RAMB36 / 9 DSP48E1 / 1 XADC |
| Timing estimado de síntesis | WNS −0,129 ns; TNS −7,364 ns; 78 endpoints setup |
| Hold estimado de síntesis | WHS +0,022 ns; THS 0; 0 endpoints hold |
| Reloj de entrada | Uno de 10 ns; salida de sistema de 100 MHz |
| DRC | 2 Critical Warning: NSTD-1 y UCIO-1; 24 Warning de pipeline DSP |
| Metodología | DPIR-1 (135), LUTAR-1 (1), TIMING-9 (1), TIMING-18 (10), todos Warning |
| XSA sin bitstream | Exportado: 52414 bytes; contiene PWM y ADC |
| Plataforma y BSP local | Construidos con retorno 0 |
| PR completo | 18 fuentes compiladas y enlazadas; PR_APP_BUILD=0 |
| ABI / memoria | ABI_ESTATICA_PASS; 32032 bytes reservados y 736 libres |
| Implementación, bitstream, ejecución y potencia | No realizados |

NSTD-1 y UCIO-1 corresponden exclusivamente a `pwm_ah`, `pwm_al`, `pwm_bh`, `pwm_bl` y `pwm_period_start_o`: faltan PACKAGE_PIN, IOSTANDARD y contrato temporal externo. En esa construcción la ausencia de asignaciones impidió generar bitstream. Los 24 avisos de pipeline se distribuyen en DPIP-1 (6), DPOP-1 (12) y DPOP-2 (6). DPIR-1 señala registros con reset asíncrono que no pueden integrarse en registros DSP. Estas advertencias corresponden a la configuración DSP de esa síntesis.

`check_timing` no encuentra registros sin reloj, endpoints internos sin restricciones ni bucles combinacionales. Quedan cinco botones/switches sin input delay y cinco salidas PWM sin output delay; explican los diez TIMING-18. Las excepciones existentes de reset/UART y salidas de diagnóstico permanecen visibles. También queda la comprobación de ancho de pulso CONVST del XADC. `report_cdc` enumera nueve cruces CDC-3 con ASYNC_REG, incluidos los GPIO; no demuestra que LUTAR-1 o TIMING-9 estén resueltos. Ambos permanecen no concluyentes.

Persiste Timing 38-316: la BRAM se sintetizó OOC con 20 ns frente a los 10 ns del sistema. Debe corregirse o justificarse antes de la revisión temporal definitiva. El peor camino de síntesis está dentro del MicroBlaze V protegido y se muestra con objetos `<hidden>`; no se atribuye un nombre interno sin evidencia. No se reutiliza el WNS positivo de la plataforma anterior ni se interpreta el routing estimado de síntesis como post-routing.

Los logs conservan el desajuste BRAM 32/15, la frecuencia no anotada en una interfaz `s_axi_aclk`, el aviso de referencia SystemVerilog y board part vacío. Las conexiones efectivas y el part explícito sí pasan la verificación. La exportación se realizó mientras terminaban las síntesis OOC: dejó avisos de productos generados todavía ausentes al abrir el proyecto; terminó correctamente y el XSA contiene las dos referencias de módulo. También quedan avisos de puertos opcionales AMD sin usar, entre ellos las salidas generateout del Timer y la IRQ UART no conectada. No se presentan esos avisos como resueltos ni se modifican los IP para ocultarlos.

### Software ligado al XSA con PWM real

Vitis genera `XPAR_PWM_SYSTEM_AXI_0_BASEADDR=0x44000000` y HIGHADDR=0x44000FFF, además de `XPAR_ADC_SYSTEM_AXI_0_BASEADDR=0x44A00000` y HIGHADDR=0x44A00FFF. El flujo comprueba estas macros, las bases GPIO/UART/Timer y `XPAR_FABRIC_TIMER_INTR=0`. Los offsets de `drv_pwm.c/pwm_regs.h` coinciden con CONTROL=0x00, REFERENCE=0x04, DEADTIME=0x08 y TRIGGER_PHASE=0x0C. Los drivers ADC conservan SAMPLE/STATUS/ACK_ID y reconocimiento con token completo; no se editaron sus fuentes.

El workspace nuevo `%TEMP%/p4_pwm_vitis_20261115_a/` selecciona el BSP LOCAL con el backport mínimo de alineación. El manejador generado coincide con el hash parcheado; el original AMD permanece intacto. GCC 13.4.0 utiliza `rv32imf_zicsr_zifencei_zicbom` e `ilp32f`, -Os y secciones independientes con eliminación de secciones no usadas. El linker validado, el buffer de 1024 muestras (8192 bytes), el heap de 2048 y la pila de 1024 no cambian.

La auditoría comprueba el marco de 272 bytes, alineación antes de llamadas C y preservación simétrica de registros enteros, 32 flotantes y FCSR. El ELF reserva 32032 bytes (97,75 %); `size` suma 32022 bytes de secciones, sin incluir todos los huecos de alineación. El margen real es de 736 bytes, no 746. La suficiencia dinámica de pila, la ejecución de interrupciones y la duración completa de ISR siguen pendientes.

Persisten las dos advertencias `excess elements in struct initializer` y LOAD RWX. El backport de alineación no corrige la estructura `XMicroblaze_RISCV_Config`; `nm` confirma que ConfigTable no está vinculada en este ELF, sin garantizarlo para versiones futuras. Compilar y auditar el ELF no valida calibración, control PR, reconocimiento integrado ADC ni arranque real.

Timer 0 mantiene la configuración de software TLR0=9998 para 10000 ciclos (100 us a 100 MHz); Timer 1 mide ciclos sin IRQ. PWM no añade interrupción. El software configura inicialmente 10 kHz, DEADTIME=100 y TRIGGER_PHASE=5000; REFERENCE se aplica al inicio de período. Se conservan period_start externo, trigger interno hacia ADC e ISR_DIAG en JA1 para planificar medición; hace falta asignar diagnóstico o instrumentación interna antes de observarlos juntos. No se afirma fase fija Timer–PWM ni retardo de 1,5 Ts.

### Evidencia y límites de publicación

Hardware: `reports/bd_configuration.txt`, `reports/synthesis/` (utilización, timing, DRC, metodología, CDC, I/O, clocks, excepciones, `pending_pwm_pins.txt` y `platform_synth.dcp`) y `platform_microblaze.xsa` en la carpeta externa indicada. Logs/journals: `%TEMP%/p4_pwm_create_20261115_a.*`, `p4_pwm_synth_20261115_a.*` y `p4_pwm_export_20261115_a.*`.

Software: `pr_build_inputs.json`, `pr_elf_validation.json`, `interrupt_abi.json`, `pr_disassembly.txt`, logs de plataforma/aplicación, ELF y mapa en el workspace externo. Los hashes conservan los C/H importados y originales.

Antes de prueba física faltan pines y requisitos eléctricos PWM, metodología/CDC pendiente, restricciones OOC/E/S, implementación y timing post-routing, carga del ELF, prueba dinámica de pila y medición de ISR/fase. Vivado/Vitis 2025.1 continúa sin comprobarse. No se conecta hardware de potencia.
