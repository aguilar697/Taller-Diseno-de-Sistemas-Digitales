# Scripts de construcción y verificación

| Carpeta | Uso | Responsable principal |
|---|---|---|
| `vivado/` | Reconstrucción del Block Design, configuración de IP, fuentes, restricciones e implementación | Daniel Puentes |
| `vitis/` | Plataforma y construcción del software MicroBlaze V | Daniel Puentes, coordinado con Kevin Cortés |
| `verificacion/` | Ejecución de pruebas y recopilación de resultados | Responsable de cada prueba |

Cada script documenta su herramienta, versión, argumentos, entradas y salidas. Las rutas se resuelven desde el proyecto y los productos generados se escriben en `build/`. La configuración de tarjeta, dispositivo y periféricos debe permitir reconstruir la plataforma desde las fuentes conservadas.

Los procedimientos de ejecución se incorporan junto con los scripts implementados. Las pruebas terminan con un código de error ante fallos y conservan los registros necesarios para reproducir el resultado.

[Descripción del proyecto](../README.md)
