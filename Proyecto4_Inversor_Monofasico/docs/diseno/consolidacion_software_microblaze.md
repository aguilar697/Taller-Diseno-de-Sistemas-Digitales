# Consolidación de software MicroBlaze V e integración PWM

Este documento registra la plataforma digital independiente. El montaje del inversor utiliza la [integración de laboratorio con asignación JA](integracion_basys3.md).

## Alcance y reconstrucción

La revisión del 15 de noviembre de 2026 conserva 100 MHz, RV32IMF/ilp32f, FPU simple, BRAM compartida de 32 KiB e I-cache de 8 KiB. No modifica las fuentes de control PR, ADC o PWM. La plataforma actual integra PWM real; los resultados de software anteriores a esa integración se identifican por separado. No se ejecuta el programa sobre hardware, no se genera bitstream ni se conecta potencia. Vivado/Vitis 2025.1 sigue sin comprobarse.

Desde una terminal de Vitis 2026.1, usando rutas externas nuevas:

```powershell
vitis -s scripts/vitis/build_pr_exploratory.py <plataforma.xsa> <workspace_externo_nuevo>
```

El comando se ejecuta desde la carpeta del Proyecto 4. `XILINX_VITIS` identifica la instalación; también se admite `--vitis-root`. El script deja BSP, fuentes importadas, bibliotecas, ELF, mapas y reportes fuera de Git. Una salida existente detiene el proceso. Se comprueban hashes de las fuentes originales y sus copias.

## BSP local controlado

`prepare_local_bsp.py` copia Standalone 9.5 y comprueba su versión y el SHA256 original del manejador: `c228226efcaec75c3734742680136cf80efb2a9a94e3fb412b1b5562157ffa79`. No escribe en la instalación AMD. Rechaza otra versión, un archivo ya parcheado, una salida existente o un parche con cambios adicionales.

El parche `scripts/vitis/patches/standalone_9_5_trap_align16.patch` cambia únicamente la fórmula del tamaño del marco para redondearlo a 16 bytes. Procede del [commit oficial AMD 8b6084392322](https://github.com/Xilinx/embeddedsw/commit/8b60843923226004179ba4479a737382e8bde4d9), presente en la rama 2026.2. No se importa esa versión completa ni se presenta como un hotfix oficial de 2026.1. Nuestro backport requiere validación funcional.

El flujo selecciona explícitamente el repositorio LOCAL con `set_embedded_sw_repo` y comprueba el hash del manejador generado. El marco pasa de 260 a 272 bytes: conserva posiciones y operaciones de guardado/restauración, con doce bytes de relleno al final. Se preservan los registros enteros, los 32 registros flotantes y FCSR. No se añade soporte de interrupciones anidadas.

`check_interrupt_abi.py` revisa símbolos funcionales, desensamblado, marco, contexto simétrico, atributos y memoria del ELF. Rechaza el manejador anterior de 260 bytes. Es una auditoría estática específica de esta implementación, no una prueba de ejecución de instrucciones ni de funcionamiento en FPGA.

## Linker y resultados de software

`scripts/vitis/pr_lscript.ld` es idéntico byte por byte al linker temporal validado: `_boot=0`, región de 32 KiB, heap de 2048 bytes y pila de 1024 bytes alineada a 16. `ALIGN(16)` reemplaza el relleno de código a 2048 bytes, sin cambiar los vectores. El arranque termina en 0x148; ocho bytes de relleno sitúan el código siguiente en 0x150. El modo directo de `mtvec` requiere alineación de cuatro bytes, no 2048.

La aplicación utiliza `-Os`, `-ffunction-sections`, `-fdata-sections` y `--gc-sections`, sin fast-math. El BSP conserva sus opciones de compilación -O2. Se mantienen PLATAFORMA_CON_INTC=1, los coeficientes, K_REG=1 y el buffer de 1024 muestras de ocho bytes.

| Verificación desde cero | Resultado |
|---|---|
| Plataforma y BSP local | Construcción correcta |
| Fuentes de aplicación | 18 compiladas y enlazadas |
| ELF | RISC-V ELF32 little-endian, ilp32f, entrada 0 |
| Memoria reservada / libre | 32032 / 736 bytes |
| Heap / pila / buffer | 2048 / 1024 / 8192 bytes |
| Auditoría de interrupciones | ABI_ESTATICA_PASS; marco de 272 bytes |
| Pruebas existentes en PC | 191 comprobaciones C y receptor Python correctos |
| Manejador antiguo / doble aplicación del parche | Ambos rechazados |
| Ejecución FPGA | No realizada |

La reconstrucción quedó en `%TEMP%/p4_pr_repro_20261115_c/`: `pr_elf_validation.json`, `interrupt_abi.json`, `pr_disassembly.txt`, `pr_build_inputs.json`, `final_checks.json`, `host_tests.log` y logs de plataforma/aplicación. Las pruebas en PC utilizan sus configuraciones originales, algunas con buffers reducidos para pruebas unitarias; el ELF objetivo conserva 1024 muestras. Los intentos previos a/b se conservan y no se consideran resultados exitosos.

La pila conserva 1024 bytes. El análisis previo sugiere aproximadamente 592–608 bytes contando primer plano e interrupción, pero no certifica una cota máxima. Faltan llamadas indirectas, casos excepcionales y marca de agua dinámica con control/exportación concurrentes. Las advertencias `XMicroblaze_RISCV_Config` y LOAD RWX siguen pendientes. LUTAR-1 y TIMING-9 continúan no concluyentes. No se afirma cierre de timing ni tiempo real de ISR por enlazar.

## PWM real y compatibilidad

El PWM publicado en main está en `src/design/pwm/pwm_system_axi.sv`. Depende de `pwm_axi_lite.sv`, `pwm_core.sv` y `pwm_deadtime.sv`; las cuatro fuentes permanecen intactas. No necesita empaquetado de IP para una referencia de módulo, pero sí administración de fuentes `All`.

Parámetros reales: ADDR_WIDTH=6, MOD_LIMIT_Q15=27853 y MIN_ON_CYCLES=100.

| Interfaz | Ancho y sentido desde PWM |
|---|---|
| s_axi_aclk / s_axi_aresetn | Entradas: 100 MHz / activo bajo |
| s_axi_awaddr / s_axi_araddr | Entradas: ADDR_WIDTH bits |
| s_axi_awprot / s_axi_arprot | Entradas: 3 bits |
| s_axi_wdata / s_axi_rdata | Entrada / salida: 32 bits |
| s_axi_wstrb | Entrada: 4 bits |
| AW/W/AR valid-ready | Handshakes de un bit |
| s_axi_bresp / s_axi_rresp | Salidas: 2 bits, OKAY o SLVERR |
| B/R valid-ready | Handshakes de un bit |
| pwm_ah, pwm_al, pwm_bh, pwm_bl | Cuatro salidas digitales |
| pwm_trigger_o / pwm_period_start_o | Eventos de un ciclo, no relojes |

| Offset | Registro |
|---|---|
| 0x00 | CONTROL: enable[0], freq_sel[2:1]; lectura de running[3] |
| 0x04 | REFERENCE: 16 bits con signo Q1.15, saturación ±27853 |
| 0x08 | DEADTIME: ciclos, 32 bits |
| 0x0C | TRIGGER_PHASE: ciclos, 32 bits |

FREQ_SEL=0/1/2 corresponde a 10/20/25 kHz. DEADTIME y TRIGGER_PHASE se configuran con PWM apagado; las configuraciones inválidas se rechazan con SLVERR. Reset deja salidas y configuración inactivas: programar DEADTIME antes de habilitar.

Las interfaces PWM/SmartConnect/ADC usan AXI4-Lite de 32 bits y el mismo dominio de 100 MHz/reset activo bajo. Las conexiones pasan `validate_bd_design` y las comprobaciones explícitas de la plataforma; esto no sustituye simulaciones funcionales ni mediciones integradas.

## Integración digital del PWM real

`scripts/vivado/create_project.tcl` invoca `prepare_pwm_sources` de `prepare_pwm_integration.tcl`. Después de crear la plataforma base, `create_bd.tcl` llama `integrate_pwm_digital`: agrega las cuatro fuentes, amplía SmartConnect de seis a siete destinos y conecta M06_AXI a PWM/S_AXI. La instancia usa ADDR_WIDTH=12 para evitar alias dentro de la ventana inferida de 4 KiB, sin editar RTL de Kevin. Vivado acepta la referencia de módulo y sus atributos S_AXI, sin empaquetado adicional.

Ventana activa comprobada: 0x44000000–0x44000FFF. No se solapa con GPIO entradas 0x40000000, GPIO salidas 0x40010000, UART 0x40600000, INTC 0x41200000, Timer 0x41C00000 ni ADC 0x44A00000. `verify_platform` comprueba bases, tamaños y ausencia de solapamientos de datos. No cambia ningún offset de registro.

El procedimiento sustituye únicamente el trigger constante del ADC por `pwm_trigger_o` y conserva `pwm_period_start_o` como salida de diagnóstico junto con pwm_ah/pwm_al/pwm_bh/pwm_bl. Los pines se asignan en el XDC, no en este procedimiento. La reconstrucción externa `%TEMP%/p4_pwm_20261115_a/` pasó validación del BD cuando todavía faltaban esas asignaciones; ese estado es histórico. El mapa JC del 16 de noviembre ya fue verificado para la plataforma digital. El script de síntesis no oculta DRC ni autoriza bitstream.

Al habilitar el PWM comienza el contador y se aplica la referencia inicial; durante operación, una REFERENCE nueva se aplica al siguiente comienzo de período. Los eventos `pwm_period_start_o` y `pwm_trigger_o` duran un ciclo y no crean dominios de reloj. Timer conserva sus dos contadores y su única IRQ en In0 de INTC: el PWM no añade interrupción. La relación de fase y el presupuesto completo de ISR deben medirse, no deducirse de compartir reloj.

El flujo Vitis actual exige las macros reales `XPAR_PWM_SYSTEM_AXI_0_BASEADDR/HIGHADDR` y `XPAR_ADC_SYSTEM_AXI_0_BASEADDR/HIGHADDR`, comprobando ambas ventanas de 4 KiB. Ya no acepta una reserva PWM sin hardware. Conserva 18 fuentes, -Os, linker validado, buffer de 1024 muestras, heap de 2048 y pila de 1024 bytes. Los resultados de esta reconstrucción se registran en el [informe](../informe/microblaze_reconstruccion.md).

La reconstrucción del 15 de noviembre con PWM terminó síntesis (6843 LUT, 4424 registros, 11 RAMB36 y 9 DSP), exportación XSA y enlace PR correctamente. El workspace `%TEMP%/p4_pwm_vitis_20261115_a/` registra ABI_ESTATICA_PASS, marco de 272 bytes y los mismos 32032 bytes reservados / 736 libres. En aquella revisión la síntesis estimaba WNS −0,129 ns y TNS −7,364 ns, y NSTD-1/UCIO-1 señalaban las salidas PWM sin asignar. La implementación posterior con JC completó routing y cerró setup/hold, según el [informe integrado](../informe/verificacion_digital_integrada_microblaze.md#implementación-nueva-con-pines-jc). No es una aprobación física; se conservan los avisos BSP/RWX y metodología, sin waivers.

Las asignaciones verificadas para validación digital son pwm_ah/JC1/K17, pwm_al/JC2/M18, pwm_bh/JC3/N17, pwm_bl/JC4/P18 y pwm_period_start_o/JC7/L17, todas LVCMOS33. Se conservan JA1 y VAUX6. Cualquier conexión física posterior debe respetar este mapa y pasar por validación eléctrica del equipo. Faltan permiso externo de actuación y medición de fase PWM–ADC–Timer: compartir reloj no fija la fase de habilitaciones por AXI. Esta asignación JC se usó para la verificación digital independiente.
