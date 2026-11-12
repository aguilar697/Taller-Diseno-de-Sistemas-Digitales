# Verificación ADC/XADC

## Regresión desde el repositorio

El 11 de noviembre de 2026 se ejecutó `ejecutar_pruebas_adc.ps1 -RunName repo_final_20261111` con Vivado 2026.1, fuentes copiadas en este repositorio y XADC regenerado desde el XCI importado en `build/`. Cada prueba tuvo compilación, elaboración y simulación nuevas. No se utilizaron las carpetas generadas del proyecto de desarrollo.

| Testbench | Resultado | Alcance |
|---|---|---|
| `tb_adc_control` | PASS | Seis casos de control, disparos, lectura DRP y diagnósticos. |
| `tb_adc_top` | PASS | Dos conversiones con el modelo XADC de Vivado, canal y código comprobados. |
| `tb_adc_axi_lite` | PASS, 24/24 | AW/W independientes, backpressure, WSTRB, accesos inválidos, snapshot y ACK_ID. |
| `tb_adc_concurrency` | PASS, 15/15 | ACK válido, antiguo, duplicado, simultáneo, reset y desbordamientos. |
| `tb_adc_system_axi` | PASS | Tres conversiones por AXI y modelo XADC, ACK válido/atrasado/duplicado. |
| `tb_adc_read_coherence` | PASS, 9/9 | Publicaciones entre lecturas y antes de ACK, sobrescrituras, R pendiente, lectores y reset. |

Las seis pruebas terminaron con código de salida cero y `TEST PASSED`; se registraron cero advertencias y cero errores de compilación, elaboración y simulación. Los logs y productos compilados permanecen locales en `build/adc/repo_final_20261111/`. Cada top tiene `commands.txt`, `inputs.json` con SHA256 y los tres logs; `summary.json` resume los resultados. Los pasos para repetirlos están en el [índice](README.md). No se versionan logs temporales ni simulaciones compiladas.

## Prueba dirigida de coherencia

`tb_adc_read_coherence` usa transacciones AXI sobre `adc_system_axi` y el modelo XADC. No presupone atomicidad de dos lecturas. En el escenario crítico se observó:

```text
ESCENARIO ID2_ID3: SAMPLE_ID=2 LIVE_ID=3 ACK_ID=00000002
LECTURA COHERENTE AXI: 9/9 CASOS; TEST PASSED
```

Su scoreboard guarda la palabra procesada y el token esperado, observa el ACK transmitido y su efecto, y falla si se reconoce otra publicación. Los nueve casos verifican:

1. ACK_ID inicialmente cero y sin seguimiento del token vivo antes de leer SAMPLE.
2. SAMPLE2 completado, publicación3 y ACK_ID2: el ACK conserva `new_data` de ID3.
3. Publicación después de leer el token y antes de escribir ACK.
4. Varias sobrescrituras entre SAMPLE y ACK_ID.
5. RDATA detenido durante una publicación, conservando palabra y token.
6. ACK vigente y duplicado sin alterar SAMPLE ni `valid`.
7. Un segundo lector cambia el snapshot: el maestro evita reconocer la pareja mezclada y obtiene otra bajo exclusión.
8. Reset entre lecturas elimina el snapshot y devuelve token cero.
9. Reset después de capturar el token cancela la operación antigua, aun cuando la nueva sesión reutilice el número.

Los casos 7–9 comprueban el contrato del maestro de prueba; no implementan exclusión ni época persistente en hardware ni prueban un BSP. En la revisión local anterior se comprobó además que una copia mutante que devolvía token vivo 3 para SAMPLE2 provocaba `READ_PAIR_ACKED_UNPROCESSED_SAMPLE` después de borrar indebidamente `new_data3`. Esa mutación no forma parte del RTL ni de esta regresión desde el repositorio.

## Desbordamientos y límites de evidencia

La prueba de concurrencia ejecuta 65.537 conversiones con un modelo digital de EOC/DRDY para comprobar la vuelta completa del ID de 16 bits y rechazar tokens antiguos con el mismo ID. Para el límite de 32 bits se posicionan mediante `force/release` únicamente registros del controlador cerca de `0xFFFFFFFE`; no se ejecutan 2^32 conversiones ni se fuerza el IP XADC. Se comprueba token cero persistente, ACK bloqueado y recuperación por reset.

El estímulo [design.txt](../../../src/testbench/adc/stimuli/design.txt) conserva los tiempos y valores originales; solo se eliminaron espacios finales. El código nominal `0xE66` corresponde aproximadamente a 0,9 V **simulados**, no a amperios ni a una medición física. Ver [temporización](temporizacion_y_sincronizacion.md).

## Síntesis

La síntesis aislada se reproduce con `sintetizar_adc.tcl`; sus resultados y restricciones incompletas se detallan en [advertencias de síntesis](advertencias_sintesis.md). No se declara cierre temporal del sistema ni compatibilidad con Vivado 2025.1. Los pendientes de MicroBlaze V, PWM y hardware se mantienen en [integración](integracion_pendiente.md).
