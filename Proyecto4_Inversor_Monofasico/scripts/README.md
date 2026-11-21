# Scripts de construcción y verificación

| Carpeta | Uso | Responsable principal |
|---|---|---|
| `vivado/` | Reconstrucción del Block Design, configuración de IP, fuentes, restricciones e implementación | Daniel Puentes |
| `vitis/` | Plataforma y construcción del software MicroBlaze V | Daniel Puentes, coordinado con Kevin Cortés |
| `verificacion/` | Ejecución de pruebas y recopilación de resultados | Responsable de cada prueba |
| `laboratorio/` | Gráficas y tabla de resultados de las tramas exportadas por UART; variantes de frecuencia | Kevin Cortés |

Cada script documenta su herramienta, versión, argumentos, entradas y salidas. Las rutas se resuelven desde el proyecto y los productos de Vivado/Vitis se escriben fuera del repositorio; las pruebas de PC utilizan `build/`, excluido de Git. La configuración de tarjeta, dispositivo y periféricos debe permitir reconstruir la plataforma desde las fuentes conservadas.

Los procedimientos de ejecución se incorporan junto con los scripts implementados. Las pruebas terminan con un código de error ante fallos y conservan los registros necesarios para reproducir el resultado.

El [procedimiento PWM](../src/testbench/pwm/README.md) utiliza `verificacion/pwm/ejecutar_pruebas_pwm.py` para simulación funcional y prueba de error forzado, `implementar_pwm.py` y su Tcl para implementación independiente, y `agregar_pwm.tcl` para incorporar las fuentes a un proyecto abierto.

[Descripción del proyecto](../README.md)

La [integración completa en Basys 3](../docs/diseno/integracion_basys3.md) utiliza `vivado/integrar_sistema.tcl`, `vivado/construir_integrado.tcl` y `vitis/build_integrated.py`. Conserva el mapa AXI, los pines de laboratorio y el uso del diagnóstico conjunto antes de la aplicación PR.

El flujo integrado reutiliza el BD actual de Puentes. `build_integrated.py` construye diagnóstico, control general y, opcionalmente, el ensayo limitado de 3 V con BSP local corregido. `build_pr_exploratory.py` conserva la reconstrucción de referencia de la plataforma digital con 1024 entradas. Sus ejecutables y mapas de pines no deben confundirse; véase [integración física](../docs/diseno/integracion_basys3.md).
