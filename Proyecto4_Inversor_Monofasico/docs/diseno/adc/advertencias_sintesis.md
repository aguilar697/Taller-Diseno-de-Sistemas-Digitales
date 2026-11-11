# Síntesis y advertencias

Se ejecutó nuevamente la síntesis desde el repositorio el 11 de noviembre de 2026 con Vivado 2026.1: `sintetizar_adc.tcl sintesis_repo_20261111`. Se regeneró XADC desde una copia importada del XCI y se sintetizó `adc_system_axi` fuera de contexto para `xc7a35tcpg236-1`, con reloj de 10 ns. No se abrió el proyecto original ni se generó bitstream.

Resultado: **0 errores, 0 advertencias críticas y 16 advertencias de síntesis**; 130 LUT, 243 registros, 1 XADC y 0 latches. WNS estimado de 5,483 ns, TNS 0. Estos valores no demuestran cierre temporal integrado.

| Mensaje | Cantidad | Clasificación | Acción |
|---|---|---|---|
| Synth 8-7129: `do_i[3:0]` sin carga | 4 | Esperadas | Se conserva DO[15:4] para el código de 12 bits. No añadir lógica para consumir los bits descartados. |
| Synth 8-7129: AWPROT/ARPROT sin carga | 12 | Esperadas bajo el contrato actual | Seis bits lógicos reportados en esclavo y wrapper. No existe política local de privilegios; acordarla si la plataforma la necesita. |
| Timing 38-242: HD.CLK_SRC sin fijar | 1 adicional al análisis temporal | Resolver en integración | Usar la ubicación real del buffer del diseño superior para estimar retardo y skew; no inventar una ubicación para silenciar el aviso. |
| check_timing: 55 entradas y 39 salidas sin delays | No forman parte de las 16 anteriores | Restricciones incompletas | Definir el entorno real y verificar el diseño integrado y ruteado antes de declarar cierre temporal. |

No se identificó una corrección funcional necesaria en el RTL por esos avisos. No se ocultan con atributos ni se modifica el IP para eliminarlos. Los informes regenerables quedan en `build/adc/sintesis_repo_20261111/utilization.rpt` y `timing_post_synthesis.rpt`; el log de esta ejecución está localmente en `build/adc/preparacion_20261111/synthesis.log`. La [guía](README.md) explica cómo obtener informes nuevos.

Vivado también informa que Windows limita ciertas rutas normales a 260 caracteres cuando el proyecto descartable queda en una ruta larga (`ProjectBase 1-489`). Es informativo y no bloqueó las ejecuciones aquí realizadas. Si otro clon encuentra ese límite, utilizar una ruta más corta para el repositorio. La compatibilidad con Vivado 2025.1 continúa sin verificar.
