# Documentos de Procesamiento Electrónico de Potencia

Autores: Kevin Aguilar, Kenneth Campos y Kevin Cortés.

Se preparan dos documentos: **diseño e investigación** e **informe técnico final**. Los borradores contienen los cálculos y simulaciones disponibles; las mediciones, figuras y conclusiones experimentales están pendientes.

| Documento | Contenido | PDF | Fuente editable |
|---|---|---|---|
| Diseño e investigación | Requisitos, puente H, dimensionamiento RL, accionamiento, medición, PR discreto, estabilidad y plan de pruebas | [Diseño](diseno_potencia.pdf) | [LaTeX](diseno_potencia.tex) |
| Informe técnico | Montaje, metodología, resultados de simulación, espacios para mediciones y comparación cuantitativa | [Informe](informe_potencia.pdf) | [LaTeX](informe_potencia.tex) |

El formato IEEE se utiliza como propuesta de presentación. La sección 8.2 y el anexo B del [instructivo](../../enunciado/Proyecto_4_EL3313__Taller_de_Diseño_Digital.pdf) establecen contenidos y evaluación de Potencia, pero no exigen expresamente ese formato. Debe confirmarse cualquier indicación adicional del docente. El anexo A sí exige Markdown para los documentos de Taller de Diseño Digital.

## Correspondencia con la evaluación

| Rubro de Potencia | Peso | Documento y evidencias |
|---|---|---|
| Diseño e investigación | 20 % | Documento de diseño, cálculos, modelo de planta, PR, estabilidad y plan |
| Demostración funcional propia | 50 % | Montaje con control PR discreto; seguimiento nominal, cambios de referencia y carga; registros analizados en el informe |
| Integración con Taller | 20 % | Interfaces, versiones, medición sincronizada y pruebas con MicroBlaze V; sección de integración del informe |
| Informe técnico | 10 % | Parámetros reales, resultados reproducibles, comparación, discusión y referencias |

El anexo B.1 distribuye la evaluación del diseño entre investigación (25 %), etapa y carga (30 %), modelo y control (30 %) y plan de validación (15 %). El anexo B.4 evalúa rigor técnico (30 %), resultados reproducibles (40 %), discusión (20 %) y presentación y referencias (10 %). Estos porcentajes son internos a cada rubro.

La demostración y la integración no se sustituyen con los PDF. Una plataforma digital alternativa permite realizar la demostración propia según la sección 8.2; el rubro de integración se evalúa por separado.

## Evidencias que acompañarán la entrega

Para que la revisión no dependa del acceso al repositorio, la entrega debe acompañarse con un archivo de evidencias que incluya:

- Modelos PLECS utilizados y parámetros de cada ensayo.
- Scripts y datos de simulación que permitan reproducir tablas y cálculos.
- Datos originales de laboratorio, capturas identificadas y configuración de los instrumentos.
- Esquemático final, componentes instalados, calibración y versión del controlador.

Las seis condiciones nominales simuladas y los tres transitorios funcionales se conservan en [lazo_funcional.json](../resultados/potencia/lazo_funcional.json). Son simulaciones con hipótesis explícitas; no representan mediciones del circuito comprado. Los modelos originales de PLECS se conservan sin editar.

## Pendientes de laboratorio

1. Completar el esquemático, auxiliares, accionamiento y apagado; verificar compuertas y tiempo muerto antes de energizar el puente.
2. Caracterizar ACS712 y acondicionamiento; confirmar el rango de entrada del XADC, calibración, ruido y resolución útil.
3. Medir R y L del montaje y comprobar el comportamiento del devanado bajo operación.
4. Registrar seguimiento a 50 Hz con 0,2; 0,5 y 1 A pico, indicando bus y frecuencias. Extraer amplitud y fase sobre al menos cinco períodos completos.
5. Medir el rizado de conmutación separado de la componente de baja frecuencia; comparar con el límite de 0,20 A pico a pico.
6. Ensayar cambios de referencia de 0,2 a 0,5 A y de 0,5 a 1 A, y cambio de resistencia externa de al menos 25 % a 0,5 A, conservando L.
7. Conservar referencia, corriente, tensión de carga y PWM en cada ensayo; comparar con simulación y explicar discrepancias.
8. Documentar la integración y reemplazar los apartados pendientes por resultados y conclusiones respaldados.

El error máximo de amplitud nominal es 10 %. La fase se reporta; no se agrega un límite que no figure en el instructivo. Para transitorios se indican picos, evolución y criterio de establecimiento. Las capturas exploratorias del chat no se incorporan como evidencia final.

## Regeneración

Desde la raíz del repositorio:

    python Proyecto4_Inversor_Monofasico/scripts/generar_informes_potencia.py

Se requiere una distribución LaTeX con pdflatex, IEEEtran, babel en español, amsmath, booktabs e hyperref. El script obtiene las tablas del JSON, comprueba las huellas de los modelos asociados y compila dos veces cada documento. Los auxiliares quedan en la carpeta ignorada build/informes_potencia; solo los PDF y las fuentes editables pertenecen a esta carpeta.

Las fuentes comparten estilo, autores y referencias en [comun.tex](comun.tex). Las tablas generadas se editan mediante sus datos de origen. Antes de enviar, se deben revisar ambos PDF, retirar la indicación de borrador únicamente cuando corresponda y verificar que no queden apartados pendientes.
