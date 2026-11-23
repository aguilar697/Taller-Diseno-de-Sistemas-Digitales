# Documentos de Procesamiento Electrónico de Potencia

Kevin Aguilar, Kenneth Campos y Kevin Cortés.

| Documento | Contenido | PDF | Fuente editable |
|---|---|---|---|
| Diseño e investigación | Fundamentos del PR, puente H, pérdidas, frecuencia de conmutación, carga nominal e identificada, medición, sintonización, discretización, estabilidad y plan de ensayos | [Diseño](diseno_potencia.pdf) | [LaTeX](diseno_potencia.tex) |
| Informe técnico | Parámetros medidos, simulación, seguimiento en el rango nominal, escalones de referencia, cambio de carga, identificación de la carga, comparación con PLECS, fallas y discusión | [Informe](informe_potencia.pdf) | [LaTeX](informe_potencia.tex) |

Los dos documentos usan el formato IEEE. La sección 8.2 y el anexo B describen la evaluación de Potencia. La demostración propia requiere un inversor con PR discreto en funcionamiento y admite una plataforma digital alternativa. La integración con MicroBlaze V se evalúa por separado. [Instructivo del proyecto](../../enunciado/Proyecto_4_EL3313__Taller_de_Diseño_Digital.pdf).

## Evidencias

- [Diseño, circuito, componentes y criterios de validación](../../../Potencia/README.md).
- [Modelos PLECS y reproducción](../../../modelos/README.md).
- [Resultados de la simulación funcional](../resultados/potencia/lazo_funcional.json) con seis condiciones nominales y tres transitorios.
- [Registro de puesta en marcha](../../../Potencia/04_registro_laboratorio.md) y [CSV exploratorio del osciloscopio](../resultados/potencia/laboratorio/scope_2.csv).

- [Tramas del 21/11](../resultados/potencia/laboratorio/2026-11-21/resultados.md): seguimiento a 0,2 A pico con 12 y 24 V e intentos a 0,5 A.
- [Tramas del 23/11](../resultados/potencia/laboratorio/2026-11-23/resultados.md): rango nominal con 6,6 y 9,9 Ω, escalones de referencia, cambio de carga y una falla capturada.
- [Capturas del osciloscopio del 23/11](../../../Potencia/mediciones_lab_osciloscopio/README.md), con su limitación.
- [Figuras de los informes](figuras/), regeneradas con [`figuras_informe_potencia.py`](../../../scripts/laboratorio/figuras_informe_potencia.py), que también imprime la impedancia identificada de la carga.

Cumplen el criterio del 10 % los puntos de 0,2 A con 12 y 24 V y el de 0,5 A con 24 V; los escalones de 0,2 a 0,5 A y el cambio de carga a 0,5 A quedaron registrados. El punto de 1 A no se alcanza con la carga actual. Quedan pendientes la medición del rizado y el contraste independiente de la ganancia del sensor.

## Regeneración

Desde la raíz del repositorio:

    python Proyecto4_Inversor_Monofasico/scripts/generar_informes_potencia.py

Se requiere una distribución LaTeX con pdflatex, IEEEtran, babel en español, amsmath, booktabs e hyperref. El script construye las tablas a partir del JSON, verifica las huellas de los modelos y compila dos veces cada documento. Los auxiliares se escriben en el directorio ignorado build/informes_potencia.
