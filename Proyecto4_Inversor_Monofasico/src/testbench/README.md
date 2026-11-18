# Verificación del hardware

Los bancos de prueba se organizan por subsistema y utilizan comprobaciones automáticas con resultados esperados. Una discrepancia o un tiempo de espera excedido debe producir un diagnóstico y finalizar la prueba con error.

| Carpeta | Responsable | Cobertura |
|---|---|---|
| `pwm/` | Kevin Aguilar | Generación PWM, tiempo muerto, interfaz AXI4-Lite y disparo de adquisición |
| `adc/` | Kenneth Campos | Inicio de conversión, muestras conocidas, disponibilidad y sincronización |
| `integration/` | Responsables de los bloques conectados, coordinados por Daniel Puentes | Transacciones PWM–ADC, relación temporal entre adquisición y actuación y permiso físico del top |

## PWM

- Lectura y escritura de registros, valores de reset y escrituras por bytes.
- Canales AXI de dirección y datos de escritura con distintos instantes de llegada, y respuestas bajo espera del receptor.
- Frecuencias seleccionables, referencia y saturación en los límites definidos.
- Tiempo muerto y ausencia de solapamiento lógico entre señales complementarias de cada rama.
- Habilitación, deshabilitación y cambios de configuración según la política documentada.
- Instante y duración del disparo de adquisición.
- Comportamiento del periférico después de implementación mediante simulación temporizada.

## Adquisición e integración

`tb_pwm_adc_axi` usa un maestro AXI de prueba, los dos periféricos RTL y un modelo digital del XADC. Comprueba la publicación de muestras, el reconocimiento por token y la actualización de referencia en la frontera de período. `tb_permiso_basys3` usa un modelo de la plataforma para comprobar el permiso SW15. El ensayo con la IP de XADC de Vivado se reproduce según la [guía del ADC](../../docs/informe/adc_verificacion.md#cómo-repetir-la-prueba-en-vivado).

## Reproducción en XSim

Desde la carpeta del Proyecto 4, ejecutar con Python 3 y Vivado/XSim. `SALIDA_PRUEBAS` debe ser un directorio nuevo y puede quedar fuera del repositorio.

```text
python scripts/verificacion/ejecutar_integracion_digital.py SALIDA_PRUEBAS --vivado-home RUTA_VIVADO
```

Con `--solo-integracion` se ejecuta `tb_pwm_adc_axi`, incluidos los casos nominal y de error forzado. El script guarda un resumen y los logs en la carpeta de salida. Para generar el WDB de Vivado y el VCD, ejecutar el siguiente comando en `SALIDA_PRUEBAS/tb_pwm_adc_axi`, con `xsim` disponible y la ruta al Tcl sustituida por su valor real.

```text
xsim tb_pwm_adc_axi -tclbatch RUTA_PROYECTO/scripts/verificacion/ondas_pwm_adc.tcl -wdb pwm_adc.wdb
```

La prueba temporizada se ejecuta aparte con una netlist ruteada y sus retardos SDF. El procedimiento se describe en la [guía de verificación PWM](../../docs/informe/pwm_verificacion.md).

Los modelos de simulación identifican sus simplificaciones. Los comandos y dependencias de cada prueba se incorporan junto con su banco y los [scripts de verificación](../../scripts/README.md). Las evidencias seleccionadas se documentan en el [informe](../../docs/informe/README.md).

[Descripción del proyecto](../../README.md)
