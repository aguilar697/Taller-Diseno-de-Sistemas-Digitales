# Pendientes y validación de potencia

## Revisión frente al instructivo

El alcance se toma de la sección 4.3 y del anexo B del [instructivo](../docs/enunciado/Proyecto_4_EL3313__Taller_de_Diseño_Digital.pdf). La siguiente comparación identifica el estado documentado, no una calificación ni una validación física.

| Requisito | Disponible | Trabajo por completar |
|---|---|---|
| Etapa de potencia y carga | Componentes comprados, mediciones LCR, cálculo de margen de tensión y disipación resistiva; diagrama de una rama con IR2110 | Esquema completo con alimentaciones, instrumentación y desconexión; estados de conmutación y caminos de corriente; montaje y comprobaciones |
| Pérdidas y frecuencia | Frecuencias de evaluación y barrido inicial de rizado | Estimaciones de pérdidas de conducción/conmutación con los componentes elegidos y justificación de la frecuencia nominal |
| Planta RL | Parámetros iniciales y simulaciones lineales | Presentar ecuación dinámica, función de transferencia y relación modulación–tensión; contrastar con los parámetros del montaje |
| Controlador PR | Candidatos continuo y discreto; coeficientes reproducibles, estabilidad lineal con retardo y seis ensayos nominales en PLECS | Justificar sintonización final, acordar período de control y latencias; completar anti-windup, medición y transitorios |
| Medición | ACS712 disponible, divisor propuesto y evaluación nominal con filtro y ADC cuantizado | Alimentación a 5 V, calibración, signo, ruido, filtro y precisión físicos; verificar dato convertido y retardo |
| Simulación PLECS | Cuatro originales conservados, PR discreto y copia funcional con tiempo muerto, Ron y medición; nominales y escalones reproducibles | Completar diodos, pérdidas de conmutación, saturación, rizado, tolerancias y contraste con el montaje |
| Demostración e informe | Plan de ensayos y cálculos exploratorios | Pruebas físicas, exportación de datos, extracción de fundamental, rizado y comparación cuantitativa |
| Integración con Taller | Diagramas y contratos propuestos | Implementaciones PWM/ADC, plataforma MicroBlaze, software y ensayos conjuntos; registrar latencias y parámetros comunes |

El diseño de potencia y su informe corresponden a Kevin Aguilar, Kenneth Campos y Kevin Cortés. La plataforma de Daniel Puentes pertenece a Taller. La sección 8.2 separa los 80 puntos propios de PEDP de los 20 de integración; demostrar los primeros también requiere un controlador discreto funcionando físicamente. La organización de ambos informes se conserva en [docs/informe](../docs/informe/README.md).

## Trabajo pendiente

| Orden | Actividad | Resultado necesario |
|---|---|---|
| 1 | Verificar el esquema de accionamiento IR2110 | Revisar el diagrama y la tabla de terminales en diseño y componentes; conseguir auxiliares, comprobar apagado, bootstrap, arranque y tiempo muerto; acordar SD automático y pines con plataforma |
| 2 | Evaluar la adaptación del ACS712 | Probar el divisor de 4,7 kΩ/1 kΩ, calibrar y medir ruido y precisión a 0,2 A; confirmar canal XADC, alineación de dato y filtrado; añadir ganancia si los resultados lo requieren |
| 3 | Completar la carga y la protección | Identificar devanado, comprobar resistencia y comportamiento con corriente; definir cambio de carga, límite de fuente, fusible y desconexión |
| 4 | Completar la simulación con los componentes comprados | Contrastar la copia funcional con mediciones del sensor, accionamiento y carga; completar diodos, pérdidas, saturación y rizado; separar ensayos de bus y carga |
| 5 | Coordinar el lazo digital | Acordar frecuencia PWM, instante de adquisición, período de control, escalas, saturación y coeficientes PR con adquisición y software |
| 6 | Verificar el montaje | Comprobar compuertas sin energizar el bus, iniciar con corriente limitada y registrar los ensayos nominales y transitorios |
| 7 | Completar resultados | Exportar datos, calcular fundamental, fase y rizado, y comparar teoría, PLECS y laboratorio |

La coordinación mantiene actuación con Kevin Aguilar, adquisición con Kenneth Campos y control con Kevin Cortés; la integración digital se acuerda además con Daniel Puentes. Las decisiones de interfaz se comparten antes de modificar puertos, escalas o temporización. La implementación digital y las pruebas del circuito avanzan en paralelo.

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
| Cambio de carga | Variar la resistencia externa al menos 25 %, con L fija y referencia de 0,5 A pico; se propone 6,6 → 9,9 Ω |
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

Los modelos se conservan en [modelos/plecs](../modelos/plecs/), los cálculos reproducibles en [modelos/analisis](../modelos/analisis/README.md) y los resultados que respalden el informe en [docs/informe/resultados](../docs/informe/resultados/). El montaje real, el esquema del acondicionamiento y las mediciones finales permanecen pendientes.

[Potencia](README.md) · [Componentes](01_diseno_y_componentes.md) · [Simulación](02_simulacion_y_resultados.md)
