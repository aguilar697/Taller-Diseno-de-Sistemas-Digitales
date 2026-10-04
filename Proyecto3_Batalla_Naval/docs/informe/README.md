# Informe técnico — Batalla Naval

## Verificación por subsistema

| Subsistema | Informe y evidencias |
|---|---|
| 1. Procesador RISC-V y ROM | [Verificación del CPU y la ROM](cpu_verificacion.md) |
| 2. VGA y entradas J1 | [Verificación del VGA y entradas del Jugador 1](vga_entradas_verificacion.md) |
| 3. Plataforma de datos, UART y PC | **EN PROCESO** |
| 4. Programa ensamblador | **EN PROCESO** |

## Integración del sistema

**EN PROCESO**

## Pendientes para completar el informe

La documentación disponible permite revisar por separado el CPU y el subsistema VGA/entradas. El cierre del informe requiere completar los siguientes puntos con resultados de la versión integrada:

1. **Contexto y referencias.** Incorporar objetivos y requisitos del enunciado, fundamento teórico con fuentes y bibliografía. Identificar la versión del enunciado utilizada y relacionar cada requisito con su diseño, prueba y evidencia.
2. **Reproducción del proyecto.** Documentar versión de Vivado, dispositivo, archivos fuente, módulos superiores, restricciones, importación y generación de la IP de reloj, y comandos de simulación e implementación. Para el software, incluir herramientas, dependencias, compilación del ensamblador, generación de la imagen de ROM y ejecución de la aplicación PC. Comprobar el procedimiento desde un clon limpio.
3. **Evidencia de implementación.** Incorporar los reportes originales de utilización y temporización del subsistema VGA, confirmar la unidad del valor publicado como `0.5 RAMB18` y adjuntar los registros de sus simulaciones. Completar la síntesis y el análisis temporal del CPU y posteriormente del sistema integrado, identificando el módulo superior y las restricciones de cada ejecución.
4. **Contratos de integración.** Comprobar en RTL la latencia de las lecturas MMIO, el comportamiento UART acordado y la inicialización de VRAM. Precisar el comportamiento ante accesos simultáneos a la misma posición de VRAM, la selección del primer jugador, el formato y límite de los contadores del display y los tiempos de los efectos del buzzer.
5. **Subsistemas pendientes.** Incorporar el cuarto nivel del programa RISC-V, el código y las pruebas de la plataforma de datos, la aplicación PC y el programa del juego, junto con sus respectivos informes.
6. **Validación del sistema completo.** Registrar pruebas de la comunicación entre jugadores, colocación y disparos válidos e inválidos, turnos, hundimiento, victoria, reinicio y tratamiento de errores. Incluir la comprobación visual en monitor VGA y evidencias de funcionamiento físico del juego integrado.
7. **Análisis final.** Consolidar resultados, recursos, cumplimiento temporal, advertencias, limitaciones y conclusiones. Actualizar los estados de avance únicamente cuando exista evidencia que respalde su cierre.

Los resultados de cada ejecución deben permitir identificar el testbench o módulo superior, la versión del código, la herramienta y el alcance de la prueba. Los extractos de consola y las capturas complementan el análisis; los reportes de implementación permiten comprobar las cifras de recursos y temporización.

[Planteamiento de diseño](../diseno/README.md) · [Descripción del proyecto](../../README.md)
