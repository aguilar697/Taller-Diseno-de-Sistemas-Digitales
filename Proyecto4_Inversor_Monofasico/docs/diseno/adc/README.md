# Subsistema ADC/XADC

Implementación digital aislada para Basys 3 (`xc7a35tcpg236-1`), desarrollada y comprobada en **Vivado 2026.1**. La compatibilidad con **2025.1**, versión solicitada para el sistema compartido, sigue pendiente. No se ha verificado la integración con MicroBlaze V ni el hardware físico.

## Fuentes y contrato

- [RTL e IP](../../../src/design/adc/): cuatro módulos SystemVerilog y configuración `xadc_wiz_0.xci`.
- [Testbenches](../../../src/testbench/adc/): seis pruebas, tareas AXI compartidas y estímulo analógico.
- [Contrato C](../../../software/embedded/drivers/adc/adc_regs.h): offsets, máscaras y procedimiento; no es un driver BSP completo.
- [Scripts reproducibles](../../../scripts/verificacion/adc/): importación del XCI, regresión y síntesis aislada.
- [Arquitectura e interfaces](arquitectura.md), [registros y ACK](mapa_registros.md), [temporización](temporizacion_y_sincronizacion.md).
- [Resultados y alcance de las pruebas](verificacion.md), [advertencias](advertencias_sintesis.md), [integración pendiente](integracion_pendiente.md).

Los [niveles tercero](../nivel_3_adc.md) y [cuarto](../nivel_4_adc.md) conservan el contexto del sistema; este directorio documenta la implementación entregada. No se modifican PWM, plataforma MicroBlaze, software de control ni potencia.

## Reproducir en Windows

Ejecutar desde la raíz del clon, con Vivado 2026.1 instalado. Adaptar únicamente `VIVADO_HOME` a la instalación:

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

Para integrar en otro proyecto, añadir los cuatro RTL y una copia importada del XCI, seleccionar `adc_system_axi` como periférico, y acordar los contratos de [integración](integracion_pendiente.md). El periférico no está empaquetado todavía como IP AXI de usuario y no se entrega un Block Design ni restricciones físicas.
