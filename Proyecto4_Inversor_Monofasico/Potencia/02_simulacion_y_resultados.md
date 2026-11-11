# Simulación de potencia y control

## Desarrollo inicial

Las primeras simulaciones se realizaron con un puente H ideal, PWM unipolar y carga RL lineal. En lazo abierto se observó la tensión conmutada y la corriente de carga; posteriormente se incorporó un PR continuo para estudiar el seguimiento de corriente y la respuesta a cambios de alimentación y resistencia.

Los ensayos exploratorios incluyeron referencias de 0,2; 0,5 y 1 A pico a 50 Hz, alimentación de 12 y 24 V, cambios de bus y aumento de resistencia. Las gráficas revisadas mostraron recuperación del seguimiento después de las perturbaciones y reducción de la modulación al aumentar el bus. Se conservan como observaciones preliminares: las capturas y los datos originales de esos ensayos no están incorporados como evidencias en este directorio.

La comparación cuantitativa final requiere repetir los casos con parámetros identificados, exportar datos y analizar las ventanas indicadas en el [plan de validación](03_pendientes_y_validacion.md). El máximo instantáneo y la corriente RMS de un scope no sustituyen la amplitud de la fundamental.

## Modelos conservados

| Archivo | Configuración guardada |
|---|---|
| [proyecto4.plecs](../modelos/plecs/proyecto4.plecs) | Archivo inicial de trabajo; puente a 12 V, L = 4,7 mH, resistencia externa de 6,6 Ω y resistencia serie de 1 Ω |
| [proyecto4_lazo_abierto.plecs](../modelos/plecs/proyecto4_lazo_abierto.plecs) | PWM unipolar a 10 kHz, referencia de modulación sinusoidal a 50 Hz y misma carga inicial |
| [proyecto4_lazo_cerrado.plecs](../modelos/plecs/proyecto4_lazo_cerrado.plecs) | PR continuo, referencia de 0,5 A pico, L = 9,3 mH, devanado de 0,6 Ω y cambio de resistencia externa de 6,6 a 9,9 Ω |
| [proyecto4_lazo_cerrado_modeloREAL.plecs](../modelos/plecs/proyecto4_lazo_cerrado_modeloREAL.plecs) | Copia de trabajo con bus de 24 V, L = 10 mH y devanado de 0,6 Ω; conserva MOSFET ideales con Ron = 0 y aún no incluye IR2110 ni ACS712 |

Los archivos indican formato PLECS 5.0. El modelo de lazo cerrado tiene duración de 1 s, selección automática de solver, tolerancia relativa de 10⁻⁵ y paso máximo de 1 µs. La inductancia es constante y los interruptores se modelan con MOSFET y diodo ideales, con resistencia de conducción nula. No representan todavía el IRF540N, el transformador no lineal ni el ACS712 adquirido.

### Ensayo conectado en el modelo de lazo cerrado

La fuente que alimenta el puente es `V_dc`, fijada en 12 V. La resistencia `R3`, de 3,3 Ω, está inicialmente puenteada por `S1`; `Step2` abre ese interruptor a los 0,205 s y eleva la resistencia externa de 6,6 a 9,9 Ω. La referencia permanece en 0,5 A pico.

También aparecen una fuente controlada `V` y los bloques `Step` y `Step1`, preparados para cambios de 12 a 24 V a los 0,205 s y retorno a 12 V a los 0,405 s. Esa fuente no tiene sus terminales eléctricos conectados al puente. Por tanto, ejecutar el archivo tal como está guardado reproduce el cambio resistivo a 12 V, no el ensayo de variación del bus.

## Controlador utilizado

El candidato continuo combina una acción proporcional y una resonante de ancho de banda finito:

```math
C(s)=K_p+\frac{2K_r\omega_c s}{s^2+2\omega_c s+\omega_0^2}.
```

| Parámetro | Valor |
|---|---|
| Kp | 12 V/A |
| Kr | 200 V/A |
| Frecuencia de referencia y resonancia | 50 Hz |
| ωc | 2π·2 rad/s |
| Normalización de la salida | Ganancia fija de 1/12 V⁻¹ |
| Límites de modulación | −0,85 a +0,85 |
| Frecuencia PWM | 10 kHz |

El bloque resonante utiliza numerador `[5026.548245743669 0]` y denominador `[1 25.132741228718345 98696.04401089359]`, con estados iniciales nulos. La normalización fija no es una medición del bus: al cambiar Vdc cambia la ganancia de la planta vista por el controlador.

Las señales complementarias se obtienen mediante inversores lógicos, sin tiempo muerto. El modelo tampoco incluye adquisición muestreada, cuantización, retardo de cálculo ni anti-windup. La sintonización y discretización del PR final se deben revisar con esos efectos y con el acondicionamiento de corriente.

## Análisis numéricos reproducibles

Se mantienen dos herramientas de apoyo en [modelos/analisis](../modelos/analisis/README.md):

- `rizado_pwm_rl.py`: integra exactamente la respuesta RL entre conmutaciones y compara la corriente conmutada con una planta promediada sometida a la misma referencia. El rizado se obtiene como el máximo pico a pico local de la diferencia, por período PWM.
- `analizar_pr_inicial.py`: comprueba estabilidad continua por Routh y seguimiento a 50 Hz de un conjunto de plantas del diseño inicial. No verifica el controlador discreto ni el circuito físico.

El [barrido inicial de rizado](../docs/informe/resultados/potencia/rizado_inicial/condiciones.json) contiene 144 escenarios: buses de 12 y 24 V; inductancias de 4,7 y 10 mH; PWM de 10, 20 y 25 kHz; resistencias de devanado supuestas de 0,5; 1 y 3 Ω; carga externa nominal de 6,8 Ω y modificada de 8,5 Ω. Se descartan cinco ciclos de 50 Hz y se analizan otros cinco. Estos valores pertenecen al estudio inicial y no son la lista de componentes comprados.

La comprobación del PR utiliza resistencias totales de 7,6 y 9,8 Ω; inductancias de 4,23; 4,7 y 5,17 mH; y buses de 12, 18 y 24 V. Se conserva para reproducir la evaluación inicial, no como validación de la carga con transformador.

Los [CSV y figuras del barrido](../docs/informe/resultados/potencia/rizado_inicial/) corresponden a cálculos numéricos. No son exportaciones de PLECS ni mediciones de laboratorio. Las instrucciones de ejecución y las dependencias están junto a los scripts.

## Alcance de los resultados

Las simulaciones respaldan la elección de la topología y permiten estudiar el margen de tensión y la respuesta del lazo ideal. Falta verificar el comportamiento con los drivers, las pérdidas, el tiempo muerto, la medición real y el control discreto. La inductancia medida con el LCR a pequeña señal no acredita el comportamiento del transformador durante los ensayos de potencia.

[Potencia](README.md) · [Componentes](01_diseno_y_componentes.md) · [Pendientes](03_pendientes_y_validacion.md)
