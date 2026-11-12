# Diagnóstico mínimo MicroBlaze V

Aplicación de plataforma, separada de `embedded/control/` y de los drivers PWM/ADC. No ejecuta PR, no configura potencia y no habilita interrupciones del Timer.

- `main.c`: UART Lite 115200 8N1 por polling, suma entera y float, global, pila y máscara `diagnostic_status`.
- `lscript.ld`: una región física de 32 KiB, heap de 2048 bytes y pila de 1024 bytes alineada a 16; incluye comprobaciones de límites. Derivado del linker de standalone, conservando su licencia MIT.
- `UserConfig.cmake`: configuración de aplicación de Vitis, warnings visibles y mapa de enlace. Las opciones RV32/FPU se obtienen del BSP y se verifican después de construir.

No se versiona el BSP ni se parchean fuentes AMD. El problema conocido de `XMicroblaze_RISCV_Config` debe revisarse también en aplicaciones futuras. El éxito del build es una validación estática, no un resultado en FPGA.

Construcción y limitaciones: [guía de implementación](../../../docs/diseno/implementacion_microblaze.md).
