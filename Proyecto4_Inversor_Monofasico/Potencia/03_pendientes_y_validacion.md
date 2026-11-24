# Estado de validación de potencia

## Revisión frente al instructivo

El alcance se toma de la sección 4.3 y del anexo B del [instructivo](../docs/enunciado/Proyecto_4_EL3313__Taller_de_Diseño_Digital.pdf). El [informe experimental](../docs/informe/potencia/informe_potencia.pdf) presenta las mediciones, su contraste con PLECS y las discrepancias.

| Requisito | Disponible | Trabajo por completar |
|---|---|---|
| Etapa de potencia y carga | Puente H con IRF540N e IR2110, carga con 6,6 y 9,9 Ω externos, dimensionamiento y cambio de carga en marcha | Caracterizar el devanado de reemplazo en la banda de operación |
| Pérdidas y frecuencia | Estimaciones de conducción y conmutación, comparación de frecuencias y selección de 10 kHz | Confirmar el rizado experimental |
| Planta RL y PR | Modelo nominal en PLECS, comparación experimental e impedancia aparente estimada | Comprobar la impedancia con tensión y corriente medidas de forma independiente |
| Medición | Cero y signo comprobados, escala nominal aplicada y tramas del XADC | Contrastar la ganancia y el ruido con una referencia independiente |
| Seguimiento de 50 Hz | Dentro de ±10 % a 0,2 A con ambos buses y a 0,5 A con 24 V. Fuera de tolerancia a 0,5 A con 12 V y a 1 A con ambos buses | Mejorar el margen del montaje para los puntos fuera de tolerancia |
| Cambio de referencia | Seis ensayos de 0,2 a 0,5 A con 24 V y 6,6 Ω | Ensayar 0,5 a 1 A con la misma carga cuando el punto de 1 A sea viable |
| Cambio de carga | +50 % con inductancia fija a 0,5 A pico y 24 V. Amplitud dentro de ±10 % antes y después | Completar las trazas de tensión, corriente independiente y PWM del transitorio |
| Integración con Taller | Lazo físico con MicroBlaze V, PWM, XADC y exportación UART en operación | Medir período efectivo, jitter y relación entre disparo, ISR y actuación |

El diseño de potencia y su informe corresponden a Kevin Aguilar, Kenneth Campos y Kevin Cortés. La plataforma de Daniel Puentes pertenece a Taller. La sección 8.2 separa los 80 puntos propios de PEDP de los 20 de integración; demostrar los primeros también requiere un controlador discreto funcionando físicamente. La organización de ambos informes se conserva en [docs/informe](../docs/informe/README.md).

## Mediciones por completar

1. Repetir una condición estable a 24 V y 0,5 A con corriente independiente, tensión aplicada y PWM registrados en la misma prueba. Para el rizado se requiere una ventana corta, con los canales dentro de escala y una tasa de muestreo que resuelva la conmutación.
2. Caracterizar el devanado y contrastar el cero y la ganancia del ACS712 en ambos sentidos. Con esa evidencia, seleccionar la carga que ofrezca margen para llegar a 1 A y repetir el seguimiento y el escalón de 0,5 a 1 A.
3. Medir el período y jitter en JB1 durante operación extendida, incluida la exportación UART. Documentar por separado el ancho del pulso de diagnóstico y el intervalo entre flancos sucesivos.

## Condiciones de aceptación

El [instructivo del proyecto](../docs/enunciado/Proyecto_4_EL3313__Taller_de_Diseño_Digital.pdf), secciones 4.3 y 8.2, establece los requisitos de potencia y puesta en marcha. La siguiente tabla organiza las comprobaciones; no representa ensayos aprobados.

| Aspecto | Comprobación |
|---|---|
| Circuito | Puente H, alimentación de 12–24 V DC, carga RL justificada y PWM unipolar |
| Corriente nominal | Referencias sinusoidales de 50 Hz y 0,2; 0,5 y 1,0 A pico |
| Seguimiento | Error de amplitud de la fundamental ≤10 % en los tres puntos nominales |
| Ventana de análisis | Al menos cinco períodos completos de 50 Hz, equivalentes a 100 ms, después del establecimiento |
| Fase | Medir y reportar el desfase respecto a la referencia |
| Rizado | Conmutación ≤0,20 A pico a pico, separada de la componente de baja frecuencia |
| Cambio de referencia | Ensayar 0,2 → 0,5 A y 0,5 → 1 A pico sin cambiar la carga |
| Cambio de carga | Variar la resistencia externa al menos 25 % con L fija y referencia de 0,5 A pico. El ensayo registrado empleó 6,6 → 9,9 Ω |
| Control | Justificar sintonización, discretización, estabilidad y retardo del PR implementado |
| Carga inductiva | Documentar los valores utilizados, resistencia del devanado y condición del primario; verificar corriente y disipación. El instructivo no exige curvas de saturación ni caracterización magnética especializada |
| PWM digital | Ofrecer al menos tres frecuencias seleccionables y justificar la frecuencia nominal, el tiempo muerto y la saturación |
| Puesta en marcha | Verificar compuertas y tiempo muerto antes de energizar el puente; documentar limitación de corriente y desconexión ante fallos |

Como condición adicional de diseño se ensayarán cambios de bus de 12 a 24 V y de 24 a 12 V, además de variaciones graduales. Se registrarán los picos y la recuperación del seguimiento. Esta prueba complementa los cambios de referencia y carga exigidos.

La amplitud se evaluará mediante:

```math
E_A=100\frac{|I_{1,pk}-I_{ref,pk}|}{I_{ref,pk}}.
```

No debe reemplazarse I₁,pk por el máximo instantáneo de una señal con rizado. La THD se calculará únicamente sobre una ventana estacionaria y con la fundamental correctamente identificada, no sobre todo un transitorio.

## Registro de los ensayos

Cada ensayo debe identificar alimentación, resistencia externa, resistencia del devanado, inductancia usada en el modelo, frecuencia PWM, tiempo muerto, período de control, escala de corriente, coeficientes PR y condiciones iniciales. Las gráficas deben mostrar señales, unidades, escalas y la ventana evaluada.

Los modelos se conservan en [modelos/plecs](../modelos/plecs/), los cálculos reproducibles en [modelos/analisis](../modelos/analisis/README.md) y los resultados que respalden el informe en [docs/informe/resultados](../docs/informe/resultados/). El registro de laboratorio identifica las condiciones ya comprobadas y los ensayos físicos pendientes.

[Potencia](README.md) · [Componentes](01_diseno_y_componentes.md) · [Simulación](02_simulacion_y_resultados.md)
