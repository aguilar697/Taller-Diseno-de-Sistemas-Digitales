# Documentos de Procesamiento Electrónico de Potencia

Kevin Aguilar, Kenneth Campos y Kevin Cortés.

| Documento | Contenido | PDF | Fuente editable |
|---|---|---|---|
| Diseño e investigación | Puente H, dimensionamiento de carga RL, accionamiento, medición, PR discreto, estabilidad y plan de ensayos | [Diseño](diseno_potencia.pdf) | [LaTeX](diseno_potencia.tex) |
| Informe técnico | Simulación, lecturas de banco, métodos de medida y análisis del sondeo de corriente | [Informe](informe_potencia.pdf) | [LaTeX](informe_potencia.tex) |

Los dos documentos usan el formato IEEE. La sección 8.2 y el anexo B describen la evaluación de Potencia. La demostración propia requiere un inversor con PR discreto en funcionamiento y admite una plataforma digital alternativa. La integración con MicroBlaze V se evalúa por separado. [Instructivo del proyecto](../../enunciado/Proyecto_4_EL3313__Taller_de_Diseño_Digital.pdf).

## Evidencias

- [Diseño, circuito, componentes y criterios de validación](../../../Potencia/README.md).
- [Modelos PLECS y reproducción](../../../modelos/README.md).
- [Resultados de la simulación funcional](../resultados/potencia/lazo_funcional.json) con seis condiciones nominales y tres transitorios.
- [Registro de puesta en marcha](../../../Potencia/04_registro_laboratorio.md) y [CSV exploratorio del osciloscopio](../resultados/potencia/laboratorio/scope_2.csv).

La entrega de EL4201 puede acompañarse con estos archivos fuera de Git. El ensayo físico disponible se detuvo en el sondeo de corriente. Quedan por registrar el seguimiento del PR, el desfase, el rizado, los transitorios y la integración física en el rango nominal.

## Regeneración

Desde la raíz del repositorio:

    python Proyecto4_Inversor_Monofasico/scripts/generar_informes_potencia.py

Se requiere una distribución LaTeX con pdflatex, IEEEtran, babel en español, amsmath, booktabs e hyperref. El script construye las tablas a partir del JSON, verifica las huellas de los modelos y compila dos veces cada documento. Los auxiliares se escriben en el directorio ignorado build/informes_potencia.
