# Pendientes y validación de potencia

## Trabajo pendiente

| Orden | Actividad | Resultado necesario |
|---|---|---|
| 1 | Verificar el esquema de accionamiento IR2110 | Revisar el diagrama y la tabla de terminales en diseño y componentes; conseguir auxiliares, comprobar apagado, bootstrap, arranque y tiempo muerto; acordar SD automático y pines con plataforma |
| 2 | Evaluar la adaptación del ACS712 | Probar el divisor de 4,7 kΩ/1 kΩ, calibrar y medir ruido y precisión a 0,2 A; confirmar canal XADC, alineación de dato y filtrado; añadir ganancia si los resultados lo requieren |
| 3 | Completar la carga y la protección | Identificar devanado, comprobar resistencia y comportamiento con corriente; definir cambio de carga, límite de fuente, fusible y desconexión |
| 4 | Preparar la simulación con los componentes comprados | Crear una copia de los modelos iniciales e incorporar los parámetros de los componentes, tiempo muerto, medición y control discreto; conservar los archivos originales y separar los ensayos de bus y carga |
| 5 | Coordinar el lazo digital | Acordar frecuencia PWM, instante de adquisición, período de control, escalas, saturación y coeficientes PR con adquisición y software |
| 6 | Verificar el montaje | Comprobar compuertas sin energizar el bus, iniciar con corriente limitada y registrar los ensayos nominales y transitorios |
| 7 | Completar resultados | Exportar datos, calcular fundamental, fase y rizado, y comparar teoría, PLECS y laboratorio |

La coordinación mantiene el reparto del proyecto: actuación con Kevin Aguilar, adquisición con Kenneth Campos, control con Kevin Cortés y plataforma con Daniel Puentes. Las decisiones de interfaz se comparten antes de modificar puertos, escalas o temporización.

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
