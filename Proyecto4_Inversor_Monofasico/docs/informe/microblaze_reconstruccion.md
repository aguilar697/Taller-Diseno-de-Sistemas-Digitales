# Verificación de reconstrucción MicroBlaze V

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
