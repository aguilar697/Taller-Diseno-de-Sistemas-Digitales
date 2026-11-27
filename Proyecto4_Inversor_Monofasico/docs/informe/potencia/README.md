# Documentos de Procesamiento Electrónico de Potencia

Kevin Aguilar, Kenneth Campos y Kevin Cortés.

| Documento | Contenido | PDF | Fuente editable |
|---|---|---|---|
| Diseño e investigación | Fundamentos del PR, puente H, pérdidas, frecuencia de conmutación, carga nominal y equivalentes estimados, medición, sintonización, discretización, estabilidad y plan de ensayos | [Diseño](diseno_potencia.pdf) | [LaTeX](diseno_potencia.tex) |
| Informe técnico | Parámetros medidos, simulación, seguimiento en el rango nominal, escalones de referencia, cambio de carga, estimación de la carga, comparación con PLECS, fallas y discusión | [Informe](informe_potencia.pdf) | [LaTeX](informe_potencia.tex) |

Los documentos distinguen parámetros nominales, mediciones y estimaciones. El informe incluye una síntesis de resultados y una discusión de las diferencias entre simulación y montaje, con las condiciones de adquisición necesarias para interpretarlas. La sección 8.2 y el anexo B describen la evaluación de Potencia. La demostración propia requiere un inversor con PR discreto en funcionamiento y admite una plataforma digital alternativa. La integración con MicroBlaze V se evalúa por separado. [Instructivo del proyecto](../../enunciado/Proyecto_4_EL3313__Taller_de_Diseño_Digital.pdf).

## Evidencias

- [Campaña final del 26/11](../../../Potencia/mediciones_lab_osciloscopio/final_82a8226_12V/README.md). Mediciones a 12 V fijos con la versión presentada, capturas de ambos escalones, cambio de carga, rizado, tiempo muerto lógico y JB1.

- [Video de la demostración funcional](https://youtu.be/cNjZ2tLcRmQ). El informe incluye el enlace completo, la fotografía del montaje a 24 V y 0,2 A pico y una captura directa del osciloscopio, con las evidencias incorporadas en el PDF.
- [Diseño, circuito, componentes y criterios de validación](../../../Potencia/README.md).
- [Esquemático completo](../../../Potencia/img/esquematico_inversor.svg), [estados de conmutación](../../../Potencia/01_diseno_y_componentes.md#topología-y-alimentaciones) y [asignación PWM de S1–S4](../../diseno/integracion_basys3.md#conexiones).
- [Modelos PLECS y reproducción](../../../modelos/README.md).
- [Resultados de la simulación funcional](../resultados/potencia/lazo_funcional.json) con seis condiciones nominales y tres transitorios.
- [Bitácora de laboratorio](../../../Potencia/04_registro_laboratorio.md) con el montaje, las intervenciones y la identificación del firmware utilizado.
- [Tramas del 21/11](../resultados/potencia/laboratorio/2026-11-21/resultados.md): seguimiento a 0,2 A pico con 12 y 24 V e intentos a 0,5 A.
- [Tramas del 23/11](../resultados/potencia/laboratorio/2026-11-23/resultados.md): rango nominal con 6,6 y 9,9 Ω, escalones de referencia, cambio de carga y una falla capturada.
- [Capturas del osciloscopio del 23/11](../../../Potencia/mediciones_lab_osciloscopio/README.md), con su limitación.
- [Figuras de los informes](figuras/). Las gráficas de seguimiento, saturación, escalón de referencia y cambio de carga se regeneran con [`figuras_informe_potencia.py`](../../../scripts/laboratorio/figuras_informe_potencia.py), que también imprime la impedancia equivalente estimada de la carga. Cada gráfica se presenta después del párrafo que explica el ensayo.

La fotografía `figuras/circuito_completo.JPG` corresponde al montaje aportado por el equipo. La imagen `figuras/osciloscopio_24v_0a2.png` es una copia sin modificaciones de [`scope_08.png`](../../../Potencia/mediciones_lab_osciloscopio/6_6/0.2/24/scope_08.png). Su pie de figura conserva la limitación de rango de los canales; se incluye como registro del ensayo, no como validación del rizado.

Con 12 V fijos y 7,3 Ω DC entre A y B, las referencias de 0,20, 0,50 y 1,00 A pico dieron fundamentales de 176, 390 y 337 mA pico por UART. Los cinco puntos evaluados quedaron fuera de ±10 % y se observó saturación a 0,50 y 1,00 A.

## Regeneración

Desde la raíz del repositorio, en PowerShell, extraer los modelos históricos cuyas huellas coinciden con el JSON de simulación y compilar los informes.

```powershell
$revisionModelos = 'd0c4399edde3763a6ada19d097d144957cf4ee24'
$modelosInforme = Join-Path $env:TEMP ('p4-modelos-' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $modelosInforme | Out-Null
$archivoModelos = Join-Path $modelosInforme 'modelos.zip'
git archive --format=zip -o $archivoModelos $revisionModelos Proyecto4_Inversor_Monofasico/modelos/plecs
Expand-Archive -LiteralPath $archivoModelos -DestinationPath $modelosInforme
python Proyecto4_Inversor_Monofasico/scripts/generar_informes_potencia.py --modelos-simulados (Join-Path $modelosInforme 'Proyecto4_Inversor_Monofasico/modelos/plecs')
```

El generador requiere una distribución LaTeX con pdflatex, IEEEtran, babel en español, circuitikz, amsmath, booktabs, float, cuted, capt-of e hyperref. Genera las tablas de simulación a partir del JSON, verifica las huellas de los modelos y compila ambos documentos. Los archivos auxiliares quedan en `build/informes_potencia/`.
