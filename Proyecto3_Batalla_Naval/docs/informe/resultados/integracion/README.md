# Evidencias de simulación integrada

La carpeta `20261007/` conserva los resultados funcionales de la revisión documentada en [verificación integrada](../../integracion_verificacion.md).

| Archivos | Contenido |
|---|---|
| `manifest.json` | SHA-256 de las fuentes utilizadas en la regresión |
| `resumen.json` | Resultado de los 33 testbenches y de la partida J1 |
| `*_simulacion.txt` | Consolas originales de compilación y simulación |
| `tramas.txt`, `estado_sistema.txt`, `buzzer.txt` | Salidas observadas de la partida J1 |
| `j2_adicionales.json`, `j2_manifest.json`, `j2_simulacion.txt` | Resumen, fuentes y consola de la partida J2 |
| `guion_j2.txt`, `tramas_j2_esperadas.txt`, `j2_tramas.txt`, `j2_estado_sistema.txt` | Estímulos, referencia y resultados complementarios |
| `terminal_pruebas.txt`, `ensamblador_pruebas.txt` | Resultados de las 31 y 5 pruebas Python |

Los logs conservan las rutas del entorno de ejecución y la versión de XSim. No son reportes de síntesis o temporización. Las ejecuciones pueden reproducirse con los scripts del proyecto; los directorios temporales y archivos generados de `build/` no forman parte del entregable.
