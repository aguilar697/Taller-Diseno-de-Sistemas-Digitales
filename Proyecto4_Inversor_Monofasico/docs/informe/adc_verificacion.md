# Verificación del periférico ADC/XADC

## Responsabilidad e interfaz entregada

Kenneth Campos entrega `adc_system_axi`, periférico AXI4-Lite de datos de 32 bits, reloj de 100 MHz y reset activo bajo. Encapsula el banco de registros, `adc_control` y el XADC Wizard configurado para VAUX6. Acepta disparos por software y un evento PWM síncrono. La [arquitectura](../diseno/adc/arquitectura.md), el [mapa de registros](../diseno/adc/mapa_registros.md), el [header C](../../software/embedded/drivers/adc/adc_regs.h) y los [pendientes de integración](../diseno/adc/integracion_pendiente.md) definen el contrato.

Los offsets son CONTROL 0x00, STATUS 0x04, SAMPLE 0x08, ERROR 0x0C y ACK_ID 0x10. SAMPLE conserva ID de 16 bits y código de 12 bits. Su lectura captura también el token completo de 32 bits que devuelve ACK_ID. El controlador reconoce solo la publicación identificada por ese token. El software coordina lectores y reset según el mapa.

## Prueba del periférico con PWM y XADC

El 15 de noviembre de 2026 se compiló y ejecutó [tb_adc_pwm_axi.sv](../../src/testbench/adc/tb_adc_pwm_axi.sv) con Vivado/XSim 2026.1, regenerando el IP desde el XCI del repositorio en una carpeta nueva. Instancia los dos periféricos completos `pwm_system_axi` y `adc_system_axi`; conecta `pwm_trigger_o` con `pwm_trigger_i` y utiliza el modelo XADC de Vivado con el estímulo `design.txt`.

El maestro del testbench selecciona los dos buses AXI únicamente cuando no hay transacciones pendientes. Se ejercitan los cinco canales AXI de cada esclavo. La selección del maestro pertenece al banco de prueba; SmartConnect, MicroBlaze V y AXI Timer requieren una verificación posterior en el Block Design integrado.

```mermaid
flowchart LR
    TB[Maestro AXI del testbench] --> PWM[pwm_system_axi]
    TB --> ADC[adc_system_axi]
    PWM -->|Disparo de un ciclo| ADC
    ADC --> XADC[Modelo XADC de Vivado]
    XADC -->|Resultado VAUX6 por DRP| ADC
```

| Caso | Comportamiento comprobado | Resultado |
|---|---|---|
| 1 | Reset, valores iniciales ADC y SLVERR para offset no implementado | PASS |
| 2 | Configuración PWM mediante AXI, AW/W separados, D=100 y fase=5000 | PASS |
| 3 | Cuatro adquisiciones, SAMPLE/ACK_ID por AXI y referencia PWM aplicada al siguiente inicio de período | PASS |
| 4 | Leer SAMPLE5, publicar muestra6 y reconocer token5 conserva new_data6; overrun queda indicado | PASS |
| 5 | RREADY detenido en SAMPLE6 durante publicación7 conserva palabra y token6 | PASS |
| 6 | ACK válido y duplicado; ACK antiguo no consume otra publicación; CONTROL.bit1 devuelve SLVERR | PASS |
| 7 | Apagado por AXI detiene las salidas PWM y nuevos disparos | PASS |
| 8 | Reset común invalida muestra, snapshot y errores persistentes | PASS |

Los monitores comprueban cada ciclo el pulso PWM, CONVST y DEN de un ciclo, la dirección DRP 0x16, VAUX6, ausencia de solapamiento lógico, tiempo muerto y correspondencia entre disparos, conversiones y publicaciones. La sobrescritura de los casos 4/5 es deliberada y debe producir overrun; las cuatro adquisiciones nominales se comprueban sin errores.

## Resultados medidos en simulación

| Indicador | Resultado |
|---|---|
| Casos completos | 8/8, TEST PASSED |
| Período PWM | 10000 ciclos, 100 µs, 10 kHz |
| Fase del disparo | 5000 ciclos, 50 µs |
| Disparo a CONVST | 1 ciclo, 10 ns |
| CONVST a SAMPLE | 112 ciclos, 1,12 µs, en las ocho conversiones |
| Disparo a SAMPLE | 113 ciclos, 1,13 µs |
| Separación mínima entre órdenes de cada rama | 100 ciclos, 1 µs |
| Disparos / conversiones / publicaciones | 8 / 8 / 8 |
| Código analógico simulado | 0xE66, aproximadamente 0,9 V |
| Duración del banco | 902950 ns |

Las primeras palabras leídas fueron `0x00010E66`, `0x00020E66`, `0x00030E66` y `0x00040E66`. La lectura nominal del maestro ocurre en fase 100 del período siguiente y obtiene la última publicación completa. Esta fase es un estímulo elegido por el banco; la relación entre el Timer y el PWM reales sigue pendiente de medición.

El resultado positivo tuvo códigos de salida cero en compilación, elaboración y simulación, con cero advertencias y errores. La compilación y los logs se conservan localmente en `build/adc/periferico_pwm_axi_entrega_20261115/`. Cada ejecución genera comandos, hashes SHA256, logs y un CSV de eventos `adc_peripheral_trace.csv`. El CSV identifica la muestra leída o reconocida y la publicación viva por separado. El [resumen de evidencia](resultados/adc/periferico_pwm_axi.json) conserva las huellas de las fuentes y los resultados que acompañan este informe.

Se ejecutó además una prueba negativa con una copia local de `adc_control` que omite comparar los tokens al reconocer. El mismo banco falló después de transmitir ACK5 mientras estaba publicada la muestra6, con `ADC_PERIPHERAL_FAILED: new_data despues del reconocimiento`, a 601930 ns. La compilación y elaboración terminaron correctamente; el fallo esperado procede de la propiedad comprobada. Esta copia y sus logs permanecen en `build/adc/periferico_pwm_axi_mutacion_entrega_20261115/`; el RTL de producción conserva su hash. El ensayo demuestra que el test detecta la reaparición de la carrera ACK.

## Alcance y evidencias anteriores

Las seis [pruebas ADC originales](../diseno/adc/verificacion.md) cubren control, AXI, XADC, ACK, desbordamientos y coherencia. Sus fuentes funcionales se conservan. La prueba nueva añade PWM completo y ambos esclavos AXI al modelo XADC. El [banco PWM–ADC previo](../../src/testbench/pwm/tb_pwm_adc.sv) utiliza `adc_control` y respuestas digitales EOC/DRDY; ambos bancos tienen alcances complementarios.

La síntesis aislada del ADC del 11 de noviembre conserva 130 LUT, 243 registros y un XADC, con cero errores y 16 advertencias de puertos sin carga. Sus [restricciones y advertencias](../diseno/adc/advertencias_sintesis.md) siguen siendo parte del alcance de esa síntesis. En esta preparación se añadieron estímulos y documentación; los módulos sintetizables y el XCI conservaron sus hashes. La síntesis del sistema completo, su timing, la ejecución del firmware y las mediciones físicas requieren evidencias de la construcción integrada.

## Reproducción

Desde la raíz del repositorio, indicar la instalación local de Vivado 2026.1 y un nombre nuevo:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\Proyecto4_Inversor_Monofasico\scripts\verificacion\adc\ejecutar_pruebas_adc.ps1 -VivadoHome 'C:\AMDDesignTools\2026.1\Vivado' -Tops tb_adc_pwm_axi -RunName periferico_adc_nuevo
```

El script mantiene los seis tops predeterminados y admite esta prueba mediante `-Tops tb_adc_pwm_axi`. Las rutas a fuentes, estímulo e IP se resuelven desde el repositorio. La compatibilidad con Vivado/Vitis 2025.1 continúa pendiente de comprobación.

## Revisión del XDC disponible y entrega a plataforma

El 15 de noviembre, `origin/dPuentes` seguía en `bbe7fce`. Su archivo `basys3_microblaze_diagnostic.xdc` asigna los seis puertos siguientes, sin repetir pines:

| Función publicada | Pin FPGA |
|---|---|
| Reloj de 100 MHz | W5 |
| Reset externo | U18 |
| UART RX / TX | B18 / A18 |
| Botón / LED de diagnóstico | T18 / U16 |

El XDC fija LVCMOS33 y los valores de configuración de banco; el reloj procede de Clocking Wizard. Sus excepciones se limitan a entradas físicas asíncronas y salidas UART/LED. Esta revisión es estática sobre el diseño de diagnóstico publicado. El mensaje de integración más reciente de Daniel describe otra construcción, cuyo XDC y wrapper siguen pendientes de compartir.

El [ejemplo oficial XADC de Digilent](https://github.com/Digilent/Basys-3-XADC/blob/master/src/constraints/Basys3_Master.xdc) asigna VAUX6 a J3 para `vauxp6` y K3 para `vauxn6`. Corresponden al par XA1 del conector JXADC según el [Master XDC](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc). Esa reserva es compatible con los seis pines del diagnóstico publicado. La revisión definitiva requiere los nombres reales del wrapper integrado, revisión de placa y el conjunto completo de constraints. El rango de señal del ADC se mantiene en 0–1 V conforme al acondicionamiento documentado.

Daniel necesita el periférico `adc_system_axi`, sus cuatro RTL, el XCI regenerado, una ventana AXI que cubra ACK_ID 0x10, reloj común de 100 MHz y reset de periféricos activo bajo. El disparo se conecta directamente desde PWM en ese dominio. ADC no incorpora una IRQ propia; la ISR se coordina con Timer/INTC. Se verificará la inferencia o empaquetado de la interfaz AXI en el proyecto integrado.

Para completar la revisión XDC quedan pendientes el wrapper y XDC integrados, las cinco salidas PWM/diagnóstico acordadas con Kevin Aguilar, los puertos VAUX6, el informe de placement y las restricciones temporales completas. La calibración de cero y ganancia firmada del ACS712 sigue pendiente; este informe acredita funcionamiento digital en simulación.
