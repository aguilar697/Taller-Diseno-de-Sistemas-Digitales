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
| [proyecto4_lazo_cerrado_modeloREAL.plecs](../modelos/plecs/proyecto4_lazo_cerrado_modeloREAL.plecs) | Copia de trabajo con L = 10 mH, devanado de 0,6 Ω y fuente controlada conectada para 12 → 24 → 12 V; conserva MOSFET ideales con Ron = 0, sin IR2110 ni ACS712 |
| [proyecto4_pr_discreto.plecs](../modelos/plecs/proyecto4_pr_discreto.plecs) | Copia con PR discreto, muestreo de 100 µs y retardo de una muestra; configuración inicial de 12 V, 0,5 A pico y carga total de 7,2 Ω con L = 10 mH |
| [proyecto4_funcional.plecs](../modelos/plecs/proyecto4_funcional.plecs) | Copia de evaluación con tiempo muerto, Ron, sensor nominal, divisor, filtro y cuantización; permite cambios de referencia y carga |

Los archivos indican formato PLECS 5.0. El modelo de lazo cerrado tiene duración de 1 s, selección automática de solver, tolerancia relativa de 10⁻⁵ y paso máximo de 1 µs. La inductancia es constante y los interruptores se modelan con MOSFET y diodo ideales, con resistencia de conducción nula. No representan todavía el IRF540N, el transformador no lineal ni el ACS712 adquirido.

### Ensayo conectado en el modelo de lazo cerrado

La fuente que alimenta el puente es `V_dc`, fijada en 12 V. La resistencia `R3`, de 3,3 Ω, está inicialmente puenteada por `S1`; `Step2` abre ese interruptor a los 0,205 s y eleva la resistencia externa de 6,6 a 9,9 Ω. La referencia permanece en 0,5 A pico.

También aparecen una fuente controlada `V` y los bloques `Step` y `Step1`, preparados para cambios de 12 a 24 V a los 0,205 s y retorno a 12 V a los 0,405 s. Esa fuente no tiene sus terminales eléctricos conectados al puente. Por tanto, ejecutar el archivo tal como está guardado reproduce el cambio resistivo a 12 V, no el ensayo de variación del bus.

En `proyecto4_lazo_cerrado_modeloREAL.plecs`, en cambio, `V` sí alimenta el puente. La fuente DC independiente, aunque muestra 24 V en sus parámetros, está desconectada. Ese archivo reproduce el cambio de bus y el cambio resistivo guardados, por lo que no constituye un ensayo nominal fijo a 24 V. Los cuatro archivos originales se conservan sin modificaciones.

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

## Candidato PR discreto

La copia [proyecto4_pr_discreto.plecs](../modelos/plecs/proyecto4_pr_discreto.plecs) conserva el puente ideal y discretiza ambas ramas del controlador. Se propone inicialmente Ts = 100 µs, equivalente a una actualización por período del PWM de 10 kHz y 200 muestras por ciclo de 50 Hz. Este período está pendiente de coordinación con adquisición y software; debe comprobarse que la conversión, el cálculo y la escritura terminan dentro del plazo disponible.

Se usa Tustin con preajuste a 50 Hz: la sustitución es s = κ(1−z⁻¹)/(1+z⁻¹), con κ = ω₀/tan(ω₀Ts/2). El preajuste conserva la ubicación de la resonancia. Las ganancias continuas se mantienen como candidato, sin presentarlas como sintonización definitiva. [Imperix, controlador proporcional resonante](https://imperix.com/doc/implementation/proportional-resonant-controller).

Con denominador normalizado, la recurrencia de la rama resonante es:

```math
r[k]=b_0e[k]+b_1e[k-1]+b_2e[k-2]-a_1r[k-1]-a_2r[k-2].
```

| Coeficiente | Valor para Ts = 100 µs |
|---|---|
| b₀ | 0,2509707453602995 |
| b₁ | 0 |
| b₂ | −0,2509707453602995 |
| a₁ | −1,996504651666988 |
| a₂ | 0,9974902925463971 |

La salida calculada es vPR[k] = 12e[k] + r[k]. El bloque `Retardo 1Ts` aplica vPR[k−1]/12; después se limita la modulación a ±0,85. La normalización permanece fija en 12 V incluso en los ensayos a 24 V, de modo que se comprueba también el cambio de ganancia del lazo. El retardo de 100 µs es una hipótesis de actualización, no una latencia medida del hardware. Los bloques discretos usan coeficientes en potencias descendentes de z. [Plexim, Discrete Transfer Function](https://www.plexim.com/sites/default/files/plecsmanual-5-0.pdf).

El [software de control](../software/embedded/control/control_pr.c) comparte los coeficientes del candidato y añade una actualización condicional de estados ante saturación. Los modelos PLECS aquí evaluados no incluyen esa lógica ni toda la aritmética del firmware; sus resultados no sustituyen la validación del software integrado.

### Resultados nominales

Se ejecutaron seis ensayos conmutados en PLECS Standalone 5.0, con L constante de 10 mH, resistencia externa de 6,6 Ω y devanado de 0,6 Ω. La fundamental se obtuvo por proyección seno/coseno a 50 Hz en [0,4; 0,5) s, cinco períodos completos, con exportación uniforme cada 1 µs. El registro de [condiciones y resultados](../docs/informe/resultados/potencia/pr_discreto_plecs.json) identifica la huella del modelo ensayado.

| Bus | Referencia pico | Fundamental de iL | Error de amplitud absoluto | Fase |
|---|---|---|---|---|
| 12 V | 0,2 A | 0,193541 A | 3,230 % | −0,899° |
| 12 V | 0,5 A | 0,483850 A | 3,230 % | −0,899° |
| 12 V | 1,0 A | 0,967687 A | 3,231 % | −0,899° |
| 24 V | 0,2 A | 0,196722 A | 1,639 % | −0,452° |
| 24 V | 0,5 A | 0,491804 A | 1,639 % | −0,452° |
| 24 V | 1,0 A | 0,983605 A | 1,640 % | −0,452° |

La modulación máxima en esas ventanas fue inferior a 0,85. Estos resultados verifican seguimiento nominal del candidato ideal. No verifican todavía rizado conforme al método final, recuperación de saturación, anti-windup, sensor/ADC, tiempo muerto, accionamiento, pérdidas ni comportamiento magnético del transformador.

El análisis promediado independiente comprueba estabilidad discreta mediante recursión de Schur, retención de orden cero exacta de la planta RL y un período de retardo. Los doce casos combinan R total de 7,2/10,5 Ω, L de 6,984/9,291/10 mH y bus de 12/24 V; resultan estables en pequeña señal y con error de amplitud inferior al 4,7 %. El barrido de L es una evaluación de sensibilidad, no una extrapolación de la medición a 50 Hz. También se comprueba el redondeo de coeficientes a float32; esto no valida toda la aritmética del software embebido.

### Uso de la copia

En los comandos de inicialización de los parámetros de simulación se encuentran `Vbus`, `Iref`, `Lcarga`, `Rdev`, `Rext` y `T_cambio_R`. La configuración guardada es el ensayo nominal de 12 V y 0,5 A pico. El cambio resistivo queda fuera de la simulación (`T_cambio_R = 2` s); para ensayarlo a 0,5 A se puede usar 0,205 s, añadiendo los 3,3 Ω de `Rextra`. El bus permanece fijo: ambos valores de `Step` son `Vbus` y `Step1` aporta cero. Los scopes mantienen VAB/iL y referencia/iL/modulación.

Los coeficientes se recalculan al inicializar el modelo. Si se modifica Ts, debe hacerse en esos comandos y volver a evaluar estabilidad y respuesta; no basta con cambiar únicamente el tiempo de un bloque. El ensayo nominal automatizado se reproduce con `verificar_pr_plecs.py`, según las instrucciones de [análisis](../modelos/analisis/README.md).

## Evaluación funcional de accionamiento y medición

La copia `proyecto4_funcional.plecs` añade los siguientes efectos conservando los parámetros del candidato PR:

- Cuatro bloques `Turn-on Delay`, con 1 µs de retardo de encendido y apagado inmediato. Representan las órdenes lógicas con tiempo muerto; no modelan VGS ni la alimentación bootstrap. [Plexim, Turn-on Delay](https://docs.plexim.com/plecs/5.0/components-by-category/turnondelay/).
- Ron constante de 44 mΩ por MOSFET, valor máximo especificado para el IRF540N a VGS = 10 V y 25 °C. No se representa su variación térmica. Los diodos permanecen ideales y las pérdidas de conmutación quedan pendientes. [Infineon, IRF540N](https://www.infineon.com/assets/row/public/documents/24/49/infineon-irf540n-datasheet-en.pdf).
- Sensor nominal de 185 mV/A, offset de 2,5 V y aproximación de un polo a 80 kHz. El ancho de banda del módulo comprado depende de su filtrado y debe medirse; este polo no constituye una identificación del módulo. [Allegro, ACS712](https://www.allegromicro.com/-/media/Files/Datasheets/ACS712-Datasheet.ashx).
- Divisor de 4,7 kΩ/1 kΩ y evaluación de un condensador de 10 nF en el nodo ADC: τ ≈ 8,25 µs. Ese condensador es una propuesta de evaluación, no una selección final ni una prueba de establecimiento de la entrada XADC.
- Retención cada 100 µs, cuantización ideal por redondeo a pasos de 1/4096 V, límites de 0 a 4095/4096 V y reconstrucción en amperios. Se supone calibración perfecta del cero y de la sensibilidad, sin ruido, deriva ni error de alimentación. La incorporación del offset después de los filtros representa un sensor ya alimentado y establecido antes de iniciar el control.

Los ensayos nominales conservan bus fijo, R total de 7,2 Ω y L constante de 10 mH. La ventana de fundamental es [0,4; 0,5) s, exportada cada 2 µs. Las [condiciones y métricas](../docs/informe/resultados/potencia/lazo_funcional.json) se generan con `ensayar_lazo_funcional.py`:

| Bus | Referencia pico | Fundamental de iL | Error absoluto de amplitud |
|---|---|---|---|
| 12 V | 0,2 A | 0,191277 A | 4,36 % |
| 12 V | 0,5 A | 0,480439 A | 3,91 % |
| 12 V | 1,0 A | 0,962310 A | 3,77 % |
| 24 V | 0,2 A | 0,194173 A | 2,91 % |
| 24 V | 0,5 A | 0,487551 A | 2,49 % |
| 24 V | 1,0 A | 0,977180 A | 2,28 % |

También se ensayaron a 12 V los cambios de referencia 0,2 → 0,5 A y 0,5 → 1 A, manteniendo la fase de la senoide y aplicando el cambio a 0,205 s. Ambos recuperaron el seguimiento en la ventana final. El segundo alcanzó una modulación máxima de aproximadamente 0,836, cercana al límite de 0,85; falta estudiar saturación y anti-windup antes de cerrar el controlador físico.

El cambio de resistencia externa de 6,6 a 9,9 Ω, a 0,5 A pico y 12 V, produjo una fundamental final de 0,471903 A en la copia funcional: error de 5,62 %. En el PR ideal se obtuvo 0,476705 A, con error de 4,66 %. El modelo mantuvo corriente acotada durante los ensayos; estos casos temporales no sustituyen una comprobación general de robustez con todos los retardos y tolerancias.

La comprobación de las cuatro órdenes, entre 0,100 y 0,101 s con muestreo de 100 ns, detectó actividad en todas ellas, cero muestras de solapamiento y 40 intervalos completos de apagado simultáneo, con mínimo observado de 1 µs. El resultado corresponde al modelo lógico de PLECS; no verifica las compuertas físicas ni el PWM en RTL.

El campo de error RMS de medición del registro compara la corriente instantánea con la reconstrucción retenida e incluye filtrado, muestreo y rizado. No es la exactitud del ACS712 ni la resolución del XADC. La validación del rizado, el ruido a 0,2 A, el bootstrap, los diodos y el transformador permanece pendiente.

Para reproducir los cambios en PLECS se pueden modificar los comandos de inicialización:

| Ensayo | Parámetros |
|---|---|
| Nominal | `Vbus = 12` o `24`; `Iref = 0.2`, `0.5` o `1`; `T_cambio_ref = 2`; `T_cambio_R = 2` |
| Referencia 0,2 → 0,5 A | `Iref = 0.2`; `Iref_final = 0.5`; `T_cambio_ref = 0.205`; `T_cambio_R = 2` |
| Referencia 0,5 → 1 A | `Iref = 0.5`; `Iref_final = 1`; `T_cambio_ref = 0.205`; `T_cambio_R = 2` |
| Resistencia externa 6,6 → 9,9 Ω | `Iref = 0.5`; `T_cambio_ref = 2`; `T_cambio_R = 0.205` |

Se cambia una perturbación por ensayo. `Vnorm` permanece en 12 V para reproducir estos resultados. El cambio de bus, las otras frecuencias PWM y los errores de calibración requieren ensayos adicionales.

## Análisis numéricos reproducibles

Se mantienen herramientas de apoyo en [modelos/analisis](../modelos/analisis/README.md):

- `rizado_pwm_rl.py`: integra exactamente la respuesta RL entre conmutaciones y compara la corriente conmutada con una planta promediada sometida a la misma referencia. El rizado se obtiene como el máximo pico a pico local de la diferencia, por período PWM.
- `analizar_pr_inicial.py`: comprueba estabilidad continua por Routh y seguimiento a 50 Hz de un conjunto de plantas del diseño inicial. No verifica el controlador discreto ni el circuito físico.
- `pr_discreto.py` y sus pruebas: calculan los coeficientes y comprueban estabilidad y seguimiento con planta promediada, muestreo y retardo.
- `verificar_pr_plecs.py`: ejecuta los seis puntos nominales del candidato discreto en una copia temporal instrumentada de PLECS.
- `preparar_modelo_funcional.py` y `ensayar_lazo_funcional.py`: generan y evalúan la copia con tiempo muerto y medición nominal; conservan los modelos anteriores.

El [barrido inicial de rizado](../docs/informe/resultados/potencia/rizado_inicial/condiciones.json) contiene 144 escenarios: buses de 12 y 24 V; inductancias de 4,7 y 10 mH; PWM de 10, 20 y 25 kHz; resistencias de devanado supuestas de 0,5; 1 y 3 Ω; carga externa nominal de 6,8 Ω y modificada de 8,5 Ω. Se descartan cinco ciclos de 50 Hz y se analizan otros cinco. Estos valores pertenecen al estudio inicial y no son la lista de componentes comprados.

La comprobación del PR utiliza resistencias totales de 7,6 y 9,8 Ω; inductancias de 4,23; 4,7 y 5,17 mH; y buses de 12, 18 y 24 V. Se conserva para reproducir la evaluación inicial, no como validación de la carga con transformador.

Los [CSV y figuras del barrido](../docs/informe/resultados/potencia/rizado_inicial/) corresponden a cálculos numéricos. No son exportaciones de PLECS ni mediciones de laboratorio. Las instrucciones de ejecución y las dependencias están junto a los scripts.

## Alcance de los resultados

Las simulaciones respaldan la elección de la topología y permiten estudiar el margen de tensión y la respuesta del lazo ideal. Falta verificar el comportamiento con los drivers, las pérdidas, el tiempo muerto, la medición real y el control discreto. La inductancia medida con el LCR a pequeña señal no acredita el comportamiento del transformador durante los ensayos de potencia.

## Próxima simulación

Las copias con PR discreto y efectos funcionales permiten evaluar muestreo, retardo, tiempo muerto y medición nominal. La siguiente revisión debe incorporar datos del montaje y completar las comprobaciones físicas, conservando los cuatro originales:

1. Representar la resistencia externa nominal de 6,6 Ω, el devanado de aproximadamente 0,6 Ω y una inductancia de evaluación de 9,3–10 mH, identificando la frecuencia de las mediciones disponibles. La inductancia a 50 Hz todavía no se declara medida.
2. Incorporar resistencia de conducción y caída de diodos justificadas, órdenes con tiempo muerto y apagado; los retardos de accionamiento se modelan como hipótesis identificadas, pendientes de contrastar con mediciones.
3. Representar el sensor mediante offset, sensibilidad, divisor, filtro y muestreo/retención. Los valores nominales permiten evaluar escalas y retardo; la calibración y el ruido deben proceder de las pruebas del módulo.
4. Acordar el período de control con software y adquisición, discretizar el PR y estudiar estabilidad, saturación y retardo de actualización antes de cerrar sus coeficientes.
5. Ejecutar por separado los tres puntos nominales, los cambios de referencia y el cambio resistivo; conservar condiciones, datos y método de extracción de fundamental y rizado. La variación del bus es una comprobación adicional.

El MOSFET habitual de PLECS se controla con una señal lógica y puede incorporar Ron; esa entrada no es una compuerta eléctrica cuya tensión se pueda medir. Los efectos del accionamiento se pueden representar funcionalmente sin disponer de un bloque IR2110. La comprobación del bootstrap, VGS, resistencia de compuerta y parásitos requiere un modelo eléctrico detallado o mediciones de banco. [Plexim, modelo MOSFET](https://docs.plexim.com/plecs/5.0/components-by-category/mosfet/).

PLECS Spice permite incorporar netlists de semiconductores y drivers compatibles, pero es un complemento de PLECS Standalone con licencia independiente. Antes de usarlo deben comprobarse disponibilidad de licencia y compatibilidad de los modelos. El esquema de cableado del driver se mantiene en el [documento de componentes](01_diseno_y_componentes.md), aunque la simulación del lazo utilice una representación funcional. [Plexim, PLECS Spice](https://www.plexim.com/products/plecs/plecs_spice).

[Potencia](README.md) · [Componentes](01_diseno_y_componentes.md) · [Pendientes](03_pendientes_y_validacion.md)
