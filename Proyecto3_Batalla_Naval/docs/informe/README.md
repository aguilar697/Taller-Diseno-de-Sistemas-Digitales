# Informe técnico — Batalla Naval

El [informe general](informe_general.md) presenta la solución completa: objetivos, arquitectura, metodología, resultados, análisis y conclusiones. La [fundamentación teórica](fundamentacion_teorica.md) explica los conceptos de procesadores, periféricos y comunicación utilizados en el diseño.

## Informes y evidencias

| Documento | Alcance |
|---|---|
| [CPU y ROM](cpu_verificacion.md) | Operaciones, control multiciclo, memorias, fallos y comparación arquitectónica |
| [VGA y entradas](vga_entradas_verificacion.md) | Generación de video, controles, simulaciones y prueba física del subsistema |
| [Plataforma de datos, comunicación y periféricos MMIO](mmio_verificacion.md) | Integración de bus, RAM, UART e indicadores: 113 verificaciones, cero errores |
| [Lógica del juego](logica_juego_verificacion.md) | Reglas del programa ensamblador por bloque, tiempo del ciclo de servicio y error forzado |
| [Sistema integrado](integracion_verificacion.md) | Regresión RTL, partidas completas, terminal, ensamblador y detector de errores |
| [Reportes de implementación](resultados/implementacion/README.md) | Recursos, temporización y reglas de diseño del sistema completo |

La organización del programa ensamblador se describe en el [diseño del software](../diseno/nivel_3_logica_juego.md) y sus [procedimientos internos](../diseno/nivel_4_logica_juego.md). Sus reglas se prueban por bloque en la [verificación de la lógica del juego](logica_juego_verificacion.md), y su ejecución sobre la CPU se incluye en la verificación integrada.

Las evidencias se encuentran en `resultados/`. Cada informe identifica el módulo evaluado, las condiciones de prueba y los resultados observados. Los manifiestos permiten comprobar las fuentes utilizadas.

La [captura MMIO](resultados/mmio/verificacion_mmio.png) conserva el resultado `TODAS LAS PRUEBAS PASARON` del banco independiente. Las pruebas de la terminal, la melodía y las partidas con CPU/VGA reales se documentan por separado en la verificación integrada. El diseño de la plataforma está en sus [bloques funcionales](../diseno/nivel_3_uart.md) y su [implementación](../diseno/nivel_4_uart.md); el [protocolo UART](../diseno/protocolo_uart_batalla_naval.md) completa el contrato con la PC.

## Reproducción

El [plan de verificación](../diseno/estrategia_implementacion_verificacion.md) relaciona los requisitos con sus pruebas y criterios de aceptación. La [guía de uso](../uso_basys3.md) contiene las dependencias y los comandos para ensamblar, simular e implementar el proyecto.

[Planteamiento de diseño](../diseno/README.md) · [Descripción del proyecto](../../README.md)
