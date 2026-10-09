# Evidencias de simulación integrada

Los [registros de simulación](20261008/) reúnen 34 testbenches RTL, dos partidas completas, pruebas Python y un ensayo de detección de errores del banco general.

| Archivos | Contenido |
|---|---|
| `version.json`, `manifest.json` | Revisión, condiciones de ejecución y hashes de las fuentes |
| `resumen.json`, `<testbench>.txt` | Resultados y registros de consola de los 34 testbenches |
| `tramas.txt`, `estado_sistema.txt`, `buzzer.txt` | Mensajes, RAM y eventos de salida de la partida con victoria J1 |
| `j2_adicionales.json`, `j2_manifest.json`, `j2_simulacion.txt` | Resultado, fuentes y consola de la partida con victoria J2 |
| `guion_j2.txt`, `tramas_j2_esperadas.txt` | Estímulos y mensajes esperados para J2 |
| `j2_tramas.txt`, `j2_estado_sistema.txt` | Mensajes y estado de memoria observados para J2 |
| `terminal_pruebas.txt`, `ensamblador_pruebas.txt`, `rom_verificada.txt` | Pruebas Python y correspondencia entre ensamblador e imagen ROM |
| `error_forzado.txt`, `error_forzado_resultado.json` | Fallo deliberado detectado por el TB general |
| `foto_batalla.png`, `foto_resultado.png`, `capturas_vga.json` | Cuadros reconstruidos de la salida RGB simulada y sus hashes |

Los registros de consola conservan la salida de las herramientas. La interpretación de los resultados está en el [informe integrado](../../integracion_verificacion.md). Los reportes de síntesis y temporización se encuentran en [implementación](../implementacion/README.md).
