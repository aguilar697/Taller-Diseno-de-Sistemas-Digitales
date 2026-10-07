# Informe técnico — Batalla Naval

## Verificación por subsistema

| Subsistema | Informe y evidencias |
|---|---|
| 1. Procesador RISC-V y ROM | [Verificación del CPU y la ROM](cpu_verificacion.md) |
| 2. VGA y entradas J1 | [Verificación VGA y entradas](vga_entradas_verificacion.md): pruebas unitarias, aceptación 27/27, reportes temporales y evidencia física independiente |
| 3. Plataforma de datos, UART y PC | [Verificación MMIO](mmio_verificacion.md); regresión RTL y pruebas de terminal en el [informe integrado](integracion_verificacion.md) |
| 4. Programa ensamblador | [Procedimientos del juego](../diseno/nivel_4_logica_juego.md), [fuentes y ensamblado](../../src/software_riscv/README.md) y [ejecución integrada](integracion_verificacion.md) |

## Integración y reproducción

El [informe de integración](integracion_verificacion.md) identifica la revisión incorporada y el alcance de las pruebas funcionales. Las evidencias recientes incluyen logs de los 33 testbenches, manifiesto de fuentes, tramas y estado de RAM. La [guía de ejecución](../uso_basys3.md) explica dependencias, generación de ROM, simulación, proyecto Vivado, restricciones, IP y controles físicos.

## Evidencias necesarias para el cierre de implementación

La simulación funcional integrada está documentada. El equipo reporta comprobación física de la rama `kCortes`; ese reporte no reemplaza los archivos de evidencia de la revisión final. Para completar el cierre se deben incorporar:

1. Reportes de utilización, DRC y temporización del sistema completo, asociados al top `basys3_top`, al XDC y a la imagen ROM de la versión entregada.
2. Evidencias de la partida completa en placa: VGA, controles, terminal, sonidos, marcador y reinicios; identificar el bitstream utilizado.
3. Simulación post-implementación temporizada del sistema completo, asociada a la misma revisión y restricciones de los reportes.
4. Trazabilidad de requisitos al enunciado y pruebas, bibliografía y conclusiones del equipo, con las cifras de la implementación final.

Los reportes físicos y temporales ya presentes del Subsistema 2 conservan su alcance independiente. La validación del juego no permite afirmar cierre temporal del sistema completo sin sus reportes correspondientes.

[Planteamiento de diseño](../diseno/README.md) · [Descripción del proyecto](../../README.md)
