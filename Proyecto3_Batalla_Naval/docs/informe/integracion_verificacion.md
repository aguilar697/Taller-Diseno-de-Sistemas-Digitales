# Verificación funcional del sistema integrado

## Versión y alcance

Regresión realizada el 7 de octubre de 2026 con Vivado/XSim 2026.1, dispositivo objetivo `xc7a35tcpg236-1` y reloj principal de 100 MHz. Se incorporaron los cambios de `origin/kCortes` en `5ad7250`: distribución física de LEDs y melodía de victoria. El código CPU/ROM coincide con esa rama.

La revisión conserva correcciones locales de recuperación de terminal, validación del ensamblador, sincronización UART/reset y flujo de reproducción. Para la melodía se ajustó el parámetro de primera nota en el wrapper MMIO y se conservaron anchos de contador capaces de representar parámetros que sean potencias de dos. El [manifiesto](resultados/integracion/20261007/manifest.json) identifica las fuentes de la simulación mediante SHA-256; no se presenta esta revisión local como un commit publicado.

## Resultados

| Prueba | Resultado y comprobaciones |
|---|---|
| Regresión RTL | 33 testbenches aprobados; [resumen](resultados/integracion/20261007/resumen.json) y logs por módulo |
| CPU/ROM | 567 instrucciones en 11 programas, 29 operaciones y reset en 10 estados; ROM con 9 comprobaciones |
| Controles Basys 3 | 79 comprobaciones: asignación física, filtro, sincronización de reset y las tres fases en LED11–LED13 |
| Buzzer | Frecuencias y apagado de órdenes; cuatro notas de victoria; duración por nota y fin de secuencia; máximos de prueba de 16 y 32 ciclos |
| Terminal PC | 31 pruebas aprobadas: parser, protocolo, validación, turnos y recuperación por reinicio |
| Ensamblador | 5 pruebas aprobadas: codificaciones, extremos de constantes, instrucciones no admitidas y capacidad de ROM |
| Partida con victoria J1 | 44 tramas comparadas con el guion; 128 casillas más 11 variables RAM y dos registros de salida; reinicio conservando marcador |
| Partida con victoria J2 | 50 tramas comparadas con la referencia; 139 palabras RAM y dos registros de salida; rechazos de fase, identificador, orientación, traslape, coordenadas y disparo repetido; nueva partida conserva la victoria J2 |

La imagen ROM corresponde a las fuentes y utiliza 1739 palabras de las 2048 disponibles. Los logs Python se conservan junto con los resultados RTL. El ensayo complementario de victoria J2 terminó correctamente; sus resultados se documentan en [j2_adicionales.json](resultados/integracion/20261007/j2_adicionales.json).

## Metodología de la partida

`tb_battleship_system` conecta CPU, ROM del juego, RAM, bus, UART, entradas, VGA y salidas. El guion introduce acciones de botones y bytes UART en 8N1 a 115200 baud. Se comprueban colocaciones válidas e inválidas, rotación, acciones fuera de turno, disparos repetidos, hundimientos, victoria y nueva partida.

El script compara cada trama producida con la referencia y consulta RAM antes de reiniciar la partida. Además verifica que las notificaciones sean aceptadas por el parser de la terminal. Los píxeles de VGA se generan con un modelo funcional de reloj de 25 MHz habilitado únicamente en simulación mediante `BN_FUNCTIONAL_CLOCK`. La implementación usa el IP real, no ese modelo.

## Reproducción

Desde la raíz de `Proyecto3_Batalla_Naval`:

```powershell
python scripts/ensamblar_programa.py --check
python -m unittest discover -s scripts -p "test_*.py" -v
python -m unittest discover -s src/software_pc -v
python scripts/verificar_sistema_completo.py --all
python scripts/verificar_partida_j2.py
```

Las ejecuciones nuevas generan resultados en `build/`, que queda excluido de Git. Las evidencias seleccionadas de esta regresión se conservan en `docs/informe/resultados/integracion/20261007/`. Los logs incluyen las rutas locales del entorno de ejecución; el manifiesto permite relacionar la prueba con el contenido de las fuentes.

## Límites de la evidencia

Estas pruebas son simulación funcional, sin retardos posteriores a implementación. No demuestran por sí mismas cumplimiento temporal, consumo de recursos, funcionamiento eléctrico de buzzer ni imagen física de monitor. El equipo reporta funcionamiento en placa de la rama `kCortes`; los reportes y capturas del bitstream final deben añadirse para respaldar esa comprobación y relacionarla con la revisión local.

El periférico UART conserva un único byte RX, sin FIFO ni indicador de overflow. La prueba recibe bytes consecutivos con el programa actual y verifica sus tramas; una carga que retrase el servicio RX puede reemplazar un byte sin consumir. Esa limitación permanece explícita en el contrato de integración.

[Índice del informe](README.md) · [Ejecución en Basys 3](../uso_basys3.md)
