# Integración física en Basys 3

El proyecto de laboratorio reutiliza el [Block Design de MicroBlaze V](integracion_digital_microblaze.md), con sus periféricos, reloj de 100 MHz y reset. El top `inversor_basys3` añade el permiso SW15 y conecta el PWM al conector JA. La plataforma digital independiente de Puentes conserva su asignación JC: los dos proyectos tienen constraints distintos.

## Mapa y temporización

| Periférico | Base | Ventana |
|---|---|---|
| GPIO entradas / salidas | `0x40000000` / `0x40010000` | 64 KiB cada uno |
| UART Lite | `0x40600000` | 64 KiB |
| AXI INTC | `0x41200000` | 64 KiB |
| AXI Timer | `0x41C00000` | 64 KiB |
| PWM | `0x44000000` | 4 KiB |
| ADC | `0x44A00000` | 4 KiB |

`direcciones.h` obtiene las bases de `xparameters.h` y rechaza el mapa anterior. Se necesitan bitstream, XSA, BSP y ELF construidos para la misma plataforma. Las ventanas no representan memoria física adicional.

El PWM opera a 10 kHz, con 100 ciclos de tiempo muerto (1 µs) y disparo ADC en fase 5000. La ISR lee la última conversión completa, reconoce ACK_ID y después procesa el arranque o parada. La nueva referencia se aplica al siguiente período PWM. La fase efectiva respecto al Timer depende de los accesos AXI y del despacho de interrupción: se debe medir en FPGA.

## Conexiones

| Basys 3 | Destino |
|---|---|
| JA1 / JA2 | HIN (10) / LIN (12) del IR2110 izquierdo |
| JA3 / JA4 | HIN (10) / LIN (12) del IR2110 derecho |
| JA7 | Inicio de período PWM, pulso de 10 ns |
| JB1 | Diagnóstico de ejecución de la ISR |
| JXADC1 | VAUX6 positivo: salida del divisor del ACS712 |
| JXADC7 | VAUX6 negativo: retorno analógico unido por cable corto a GND |
| JXADC5 u 11 | GND; referencia del divisor y de VAUX6 negativo |
| BTN C | Reset general |
| BTN U / D / L | Arranque / parada o reconocimiento / selección o exportación, según el ELF |
| SW0–SW1 | Amplitud del controlador general: 0,2; 0,5 o 1 A pico |
| SW15 | Permiso de las cuatro órdenes PWM |
| USB-UART | 115200 bit/s, 8N1 |

**JXADC7 es una entrada analógica, no un pin GND interno.** OUT del ACS712 pasa primero por 4,7 kΩ; el nodo medido tiene 1 kΩ a GND. No conectar OUT directamente a la FPGA. La fuente externa de 3,3 V no se une en paralelo con la salida de alimentación de la Basys.

SW15 bajo bloquea inmediatamente las cuatro órdenes. Para habilitar, el top sincroniza el permiso con el reloj AXI y espera un inicio de período. SD (pin 11) sigue siendo independiente: alto apaga el IR2110. SW15 no sustituye SD, el apagado de fuentes ni la limitación de corriente.

## Reconstrucción y programas

Se ha trabajado con Vivado/Vitis 2026.1; la compatibilidad con 2025.1 sigue pendiente. Usar directorios nuevos fuera del repositorio y rutas cortas. Desde la carpeta del Proyecto 4:

```text
vivado -mode batch -source scripts/vivado/integrar_sistema.tcl -tclargs SALIDA_HW
vivado -mode batch -source scripts/vivado/construir_integrado.tcl -tclargs SALIDA_HW/inversor_integrado.xpr
vitis -s scripts/vitis/build_integrated.py SALIDA_HW/inversor_integrado.xsa SALIDA_SW --incluir-laboratorio
```

El flujo comprueba el BD y setup/hold antes del bitstream. Vitis utiliza una copia local del BSP con la [corrección de alineación del trap](consolidacion_software_microblaze.md#bsp-local-controlado), sin editar la instalación AMD. Los ELF se auditan en formato, memoria y contexto de interrupción; cada aplicación conserva un manifiesto con las huellas del XSA y de sus fuentes.

| Ejecutable | Uso |
|---|---|
| `diagnostico_integrado.elf` | Timer, ADC, UART y prueba finita de PWM con modulación fija; sin PR |
| `lazo_laboratorio.elf` | [Ensayo limitado](../../software/embedded/integration/lazo_laboratorio.md) a bus de 3 V; ajuste de cero y comprobación de respuesta antes del PR |
| `control_inversor.elf` | Aplicación general. Rechaza el arranque si `MEDICION_CALIBRADA=0`; requiere cero y ganancia firmada medidos para el montaje |

La construcción de laboratorio usa heap nulo y pila de 2 KiB. El controlador general conserva 102,4 ms de registro mediante 512 entradas y K_REG=2; el ensayo limitado usa 256 y K_REG=4. No cambia el período de control de 100 µs. La auditoría estática no reemplaza la medición de pila ni del tiempo completo de interrupción en hardware.

## Carga y verificación

```text
xsdb scripts/vitis/cargar_integrado.tcl BITSTREAM.bit PROGRAMA.elf
python software/tests/correr_pruebas.py
python scripts/verificacion/ejecutar_integracion_digital.py SALIDA_PRUEBAS --vivado-home RUTA_VIVADO
```

Cargar con bus apagado, SW15 abajo, ambos SD altos y sensor alimentado. El cargador configura de nuevo la FPGA antes del ELF: reiniciar únicamente el procesador no limpia errores persistentes del ADC ni reinicia todos los periféricos.

El banco del permiso sustituye la plataforma por un modelo. La prueba AXI usa PWM y ADC reales con un modelo digital del XADC. Ninguna ejecuta el procesador ni valida la electrónica analógica. Los resultados físicos y las condiciones para continuar se mantienen en el [registro de laboratorio](../../Potencia/04_registro_laboratorio.md).

## Resultados de la construcción integrada

La revisión local basada en `main` (`261e991`) generó bitstream, XSA y tres ELF con Vivado/Vitis 2026.1. El [manifiesto de verificación](../informe/resultados/integracion_basys3/verificacion.json) identifica las fuentes y los productos construidos.

| Comprobación | Resultado |
|---|---|
| Bancos RTL | 7 PASS, incluida la habilitación del top y la integración AXI PWM–ADC |
| Error forzado en integración AXI | Detectado por el monitor; ejecución negativa sin mensaje de aprobación |
| Software en PC | 201 comprobaciones C sin fallos y receptor UART aprobado |
| Análisis numérico | 18 pruebas aprobadas |
| Setup / hold, sistema ruteado | WNS +0,289 ns / WHS +0,042 ns; cero endpoints con fallo |
| Diagnóstico: memoria reservada / libre | 14 256 / 18 512 bytes |
| Control general: memoria reservada / libre | 28 576 / 4 192 bytes |
| Ensayo PR limitado: memoria reservada / libre | 28 224 / 4 544 bytes |
| Interrupciones en los tres ELF | Auditoría estática aprobada; marco de 272 bytes y contexto FPU preservado |
| Ejecución física de esta construcción | Pendiente |

Las reservas incluyen la pila de 2 KiB; el espacio libre no es una medida de uso máximo de pila. Los [reportes de timing](../informe/resultados/integracion_basys3/timing.rpt), [CDC](../informe/resultados/integracion_basys3/cdc.rpt) y [DRC](../informe/resultados/integracion_basys3/drc.rpt) conservan el alcance del análisis. Los puertos externos asíncronos tienen excepciones temporales; el cierre interno a 100 MHz no demuestra los retardos de los cables ni el tiempo muerto entre compuertas reales.

DRC conserva doce advertencias sobre registros internos de DSP. Metodología informa advertencias de reset asíncrono, dos de LUT en resets y una `TIMING-9`; el análisis CDC detallado no presenta cruces críticos. No se han ocultado mediante waivers. La liberación del permiso externo se sincroniza antes de habilitar por período. La validación del reset, de la ISR y de los transitorios analógicos en la tarjeta sigue pendiente.
