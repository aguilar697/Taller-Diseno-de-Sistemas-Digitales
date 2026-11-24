# Subsistema ADC/XADC

Periférico ADC/XADC para Basys 3 (`xc7a35tcpg236-1`). Las pruebas aisladas y la construcción digital integrada se hicieron en **Vivado 2026.1**. La compatibilidad con **2025.1**, versión solicitada, sigue pendiente. En laboratorio se comprobó la lectura en reposo y la adquisición durante el control PR y la exportación UART. El montaje usa el cero y el signo obtenidos en la puesta en marcha; la ganancia conserva el valor nominal del sensor y del divisor. Los [resultados integrados](../../informe/README.md#operación-a-12-y-24-v) distinguen el seguimiento registrado del contraste independiente de esa escala.

## Fuentes y contrato

- [RTL e IP](../../../src/design/adc/): cuatro módulos SystemVerilog y configuración `xadc_wiz_0.xci`.
- [Testbenches](../../../src/testbench/adc/): siete pruebas, tareas AXI compartidas y estímulo analógico.
- [Contrato C](../../../software/embedded/drivers/adc/adc_regs.h): offsets, máscaras y procedimiento; no es un driver BSP completo.
- [Scripts reproducibles](../../../scripts/verificacion/adc/): importación del XCI, regresión y síntesis aislada.
- [Arquitectura e interfaces](arquitectura.md), [registros y ACK](mapa_registros.md), [temporización](temporizacion_y_sincronizacion.md).
- [Resultados y alcance de las pruebas](verificacion.md), [advertencias](advertencias_sintesis.md), [integración y validación pendiente](integracion_pendiente.md).
- [Informe del periférico ADC con PWM, AXI y XADC](../../informe/adc_verificacion.md): prueba conjunta y resultados reproducibles.

Los [niveles tercero](../nivel_3_adc.md) y [cuarto](../nivel_4_adc.md) describen la relación del ADC con el sistema. Este directorio detalla su funcionamiento y las pruebas del periférico.

## Reproducir en Windows

Ejecutar desde la raíz del clon, con Vivado 2026.1 instalado. Adaptar únicamente `VIVADO_HOME` a la instalación:

En Windows, ubicar el clon en una ruta corta, por ejemplo `C:\proyectos\taller`. Vivado puede fallar al generar el IP si las rutas de sus productos superan el límite de 260 caracteres, aunque las fuentes estén presentes.

```powershell
$env:VIVADO_HOME = 'C:\AMDDesignTools\2026.1\Vivado'
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Proyecto4_Inversor_Monofasico\scripts\verificacion\adc\ejecutar_pruebas_adc.ps1 -RunName regresion_adc
```

El nombre debe ser nuevo. `ExecutionPolicy Bypass` se limita a ese proceso. El script resuelve las fuentes respecto a su ubicación, admite `-VivadoHome`, regenera el IP en `Proyecto4_Inversor_Monofasico/build/adc/<nombre>/ip/` y compila cada test desde cero. No abre el proyecto local de desarrollo ni necesita sus productos generados. Conserva logs, comandos, hashes SHA256 y `summary.json` dentro de `build/`, excluido de Git. Para seleccionar pruebas, pasar `-Tops` como arreglo desde una sesión PowerShell:

```powershell
& .\Proyecto4_Inversor_Monofasico\scripts\verificacion\adc\ejecutar_pruebas_adc.ps1 -Tops @('tb_adc_read_coherence') -RunName lectura_adc
```

La síntesis también regenera el IP de manera independiente:

```powershell
New-Item -ItemType Directory -Force .\Proyecto4_Inversor_Monofasico\build\adc | Out-Null
& "$env:VIVADO_HOME\bin\vivado.bat" -mode batch -nojournal -log .\Proyecto4_Inversor_Monofasico\build\adc\sintesis_adc.log -source .\Proyecto4_Inversor_Monofasico\scripts\verificacion\adc\sintetizar_adc.tcl -tclargs sintesis_adc
```

El flujo valida la versión 2026.1 y se detiene con otras versiones: no migra ni actualiza el IP automáticamente. El XCI conserva su configuración original, incluidos metadatos de rutas del desarrollo; **se debe importar una copia con `preparar_ip.tcl`**, como hacen ambos scripts, en lugar de generar productos directamente sobre el XCI versionado. Los wrappers y bibliotecas Xilinx se obtienen de Vivado y no se duplican en Git.

La construcción del sistema usa `adc_system_axi` como referencia de módulo e importa el XCI en el proyecto generado. El mapa y las restricciones están en la [guía de Basys 3](../integracion_basys3.md).
