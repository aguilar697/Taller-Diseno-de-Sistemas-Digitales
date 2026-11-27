# Estado de validación de potencia

## Revisión frente al instructivo

El alcance se toma de la sección 4.3 y del anexo B del [instructivo](../docs/enunciado/Proyecto_4_EL3313__Taller_de_Diseño_Digital.pdf). El [informe experimental](../docs/informe/potencia/informe_potencia.pdf) presenta las mediciones, su contraste con PLECS y las discrepancias.

| Requisito | Evidencia de la campaña final | Trabajo por completar |
|---|---|---|
| Etapa de potencia y carga | Puente H con IRF540N e IR2110. Tiempo muerto lógico de 1,00 µs en ambas ramas | Caracterizar el devanado y verificar las transiciones en compuerta |
| Rizado | Residuo bruto de 166, 180 y 251 mA pp para 0,20, 0,50 y 1,00 A. Tras el filtrado diagnóstico, 47, 48 y 49 mA pp | Repetir la medición a 1,00 A con instrumentación diferencial |
| Planta y sensado | Comparación con PLECS y contraste entre UART y caída en 3,4 Ω | Verificar la ganancia del ACS712 y medir la impedancia en operación |
| Seguimiento de 50 Hz | Error a 7,3 Ω de −12,1 %, −22,0 % y −66,3 %. A 10,6 Ω, −15,4 % y −31,7 % | Cuantificar el margen de actuación y comparar el seguimiento con distintos divisores del PR bajo las mismas condiciones de carga |
| Cambios de referencia | Establecimiento de ≈75 ms para 0,20 → 0,50 A y ≈60 ms para 0,50 → 1,00 A. En el segundo escalón la amplitud final disminuyó | Verificar la recuperación de la amplitud solicitada |
| Cambio de carga | 7,3 → 10,6 Ω DC (+45 %) a 0,50 A pico y L fija. Establecimiento de 20–40 ms y caída de ≈12 % respecto a la amplitud previa | Verificar la recuperación de la amplitud solicitada |
| Integración con Taller | PR, PWM, XADC y exportación UART. ISR de hasta 8,94 µs en operación | Medir período efectivo y jitter en JB1, también durante la exportación UART |

[Capturas, tramas y condiciones de ensayo](mediciones_lab_osciloscopio/final_82a8226_12V/README.md).

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
| Cambio de carga | Variar la resistencia externa al menos 25 % con L fija y referencia de 0,5 A pico. El ensayo final empleó 7,3 → 10,6 Ω DC entre A y B |
| Control | Justificar sintonización, discretización, estabilidad y retardo del PR implementado |
| Carga inductiva | Documentar los valores utilizados, resistencia del devanado y condición del primario; verificar corriente y disipación. El instructivo no exige curvas de saturación ni caracterización magnética especializada |
| PWM digital | Ofrecer al menos tres frecuencias seleccionables y justificar la frecuencia nominal, el tiempo muerto y la saturación |
| Puesta en marcha | Verificar compuertas y tiempo muerto antes de energizar el puente; documentar limitación de corriente y desconexión ante fallos |

En la campaña final el bus se mantuvo fijo a 12 V durante los cambios de referencia y de carga.

La amplitud se evaluará mediante:

```math
E_A=100\frac{|I_{1,pk}-I_{ref,pk}|}{I_{ref,pk}}.
```

No debe reemplazarse I₁,pk por el máximo instantáneo de una señal con rizado. La THD se calculará únicamente sobre una ventana estacionaria y con la fundamental correctamente identificada, no sobre todo un transitorio.

## Registro de los ensayos

Cada ensayo debe identificar alimentación, resistencia externa, resistencia del devanado, inductancia usada en el modelo, frecuencia PWM, tiempo muerto, período de control, escala de corriente, coeficientes PR y condiciones iniciales. Las gráficas deben mostrar señales, unidades, escalas y la ventana evaluada.

Los modelos se conservan en [modelos/plecs](../modelos/plecs/), los cálculos reproducibles en [modelos/analisis](../modelos/analisis/README.md) y los resultados que respalden el informe en [docs/informe/resultados](../docs/informe/resultados/). El registro de laboratorio identifica las condiciones ya comprobadas y los ensayos físicos pendientes.

[Potencia](README.md) · [Componentes](01_diseno_y_componentes.md) · [Simulación](02_simulacion_y_resultados.md)
