# Evidencias de implementación

Los [reportes de implementación](20261008/) corresponden al sistema completo `basys3_top`, enrutado para `xc7a35tcpg236-1` con Vivado 2026.1, las restricciones de Basys 3 y el IP de reloj. El manifiesto identifica las fuentes utilizadas.

| Archivo | Contenido |
|---|---|
| [resultado.json](20261008/resultado.json) | Resumen de implementación e identificación SHA-256 del bitstream y la ROM |
| [manifest.json](20261008/manifest.json) | SHA-256 de las fuentes utilizadas |
| [utilizacion.rpt](20261008/utilizacion.rpt) | Recursos del sistema enrutado |
| [timing.rpt](20261008/timing.rpt) | Setup, hold, ancho de pulso, relojes, caminos y advertencias |
| [drc.rpt](20261008/drc.rpt) | Comprobación final de reglas de diseño |
| [latches.txt](20261008/latches.txt) | Comprobación de ausencia de latches en síntesis |

El [informe general](../../informe_general.md#análisis-de-implementación-y-temporización) analiza estos resultados y las excepciones temporales del XDC. La [guía de uso](../../../uso_basys3.md) explica cómo regenerar el proyecto y el bitstream a partir de las fuentes.
