# Documentos de Procesamiento Electrónico de Potencia

Kevin Aguilar, Kenneth Campos y Kevin Cortés.

| Documento | Contenido | PDF | Fuente editable |
|---|---|---|---|
| Diseño e investigación | Fundamentos del PR, puente H, pérdidas, frecuencia de conmutación, carga nominal y equivalentes estimados, medición, sintonización, discretización, estabilidad y plan de ensayos | [Diseño](diseno_potencia.pdf) | [LaTeX](diseno_potencia.tex) |
| Informe técnico | Parámetros medidos, simulación, seguimiento en el rango nominal, escalones de referencia, cambio de carga, estimación de la carga, comparación con PLECS, fallas y discusión | [Informe](informe_potencia.pdf) | [LaTeX](informe_potencia.tex) |

Los documentos distinguen parámetros nominales, mediciones y estimaciones. El informe incluye una síntesis de resultados y una discusión de las diferencias entre simulación y montaje, con las condiciones de adquisición necesarias para interpretarlas. La sección 8.2 y el anexo B describen la evaluación de Potencia. La demostración propia requiere un inversor con PR discreto en funcionamiento y admite una plataforma digital alternativa. La integración con MicroBlaze V se evalúa por separado. [Instructivo del proyecto](../../enunciado/Proyecto_4_EL3313__Taller_de_Diseño_Digital.pdf).

## Evidencias

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

Los ensayos documentan el seguimiento a 0,2 A con 12 y 24 V, el seguimiento a 0,5 A con 24 V, los cambios de referencia entre 0,2 y 0,5 A y el aumento resistivo del 50 %. El análisis relaciona la saturación del mando a 1 A con la impedancia de la carga y distingue los resultados del modelo de las mediciones del montaje.

## Regeneración

Desde la carpeta del Proyecto 4, ejecutar:

```text
python scripts/laboratorio/figuras_informe_potencia.py
python scripts/generar_informes_potencia.py
```

El primer comando requiere NumPy y Matplotlib. El segundo requiere una distribución LaTeX con pdflatex, IEEEtran, babel en español, circuitikz, amsmath, booktabs, float, cuted, capt-of e hyperref. Genera las tablas de simulación a partir del JSON, verifica las huellas de los modelos y compila ambos documentos. Los archivos auxiliares quedan en `build/informes_potencia/`.
