# Diseño del sistema

El sistema integra una plataforma MicroBlaze V, un periférico PWM, adquisición de corriente y una aplicación de control PR. El diseño modular relaciona las interfaces digitales con la instrumentación y la etapa de potencia del inversor.

## Diagramas generales

- [Primer nivel: objetivo, entradas, salidas y entorno del sistema digital](nivel_1.md).
- [Segundo nivel: bloques, interfaces y secuencia de control](nivel_2.md).

## Diseño del PWM

- [Tercer nivel: bloques funcionales, interfaz y configuración](nivel_3_pwm.md).
- [Cuarto nivel: registros, contadores, comparadores y tiempo muerto](nivel_4_pwm.md).

## Documentación por subsistema

| Subsistema | Responsable | Contenido del diseño |
|---|---|---|
| Plataforma | Daniel Puentes | Block Design, memoria, reloj, reset, mapa de direcciones, interrupciones y reconstrucción |
| PWM y actuación | Kevin Aguilar | Modulación, temporización, señales complementarias, tiempo muerto, registros AXI y disparo de adquisición |
| Adquisición | Kenneth Campos | Medición, acondicionamiento, ADC/XADC, calibración, dato válido y driver |
| Control y software | Kevin Cortés | Ecuación discreta, ejecución periódica, referencia, estados, almacenamiento y comunicación |

Cada documento describe el objetivo del bloque, sus entradas y salidas, su arquitectura, las decisiones adoptadas y los criterios de verificación. Los diagramas generales muestran el límite del sistema y sus interconexiones; los niveles de detalle desarrollan los circuitos o procedimientos internos. Las figuras se almacenan en `img/`.

## Interfaces que requieren acuerdo

| Interfaz | Definiciones necesarias | Responsables |
|---|---|---|
| Plataforma–PWM | Reloj, reset, registros, accesos AXI y asignación de dirección base | Puentes y Aguilar |
| PWM–adquisición | Instante de disparo, duración del pulso, frecuencia y tratamiento de ADC ocupado | Aguilar y Campos |
| Adquisición–control | Unidades, signo, escala, calibración, validez y antigüedad de la muestra | Campos y Cortés |
| Control–PWM | Formato y límites de referencia, saturación y momento de aplicación de la actualización | Cortés y Aguilar |
| Temporización del lazo | Relación entre adquisición, interrupción, cálculo y actuación | Los cuatro integrantes |
| FPGA–potencia | Señales de accionamiento, polaridad, tiempo muerto, acondicionamiento y comportamiento ante fallos | Responsables de actuación y adquisición, coordinados con PEDP |

La dirección base de cada periférico se asigna en el Block Design; sus offsets, permisos, valores de reset y efectos de lectura y escritura se documentan con el periférico. Las frecuencias PWM, el período de control, el tiempo muerto y los componentes se seleccionan mediante el análisis de potencia y temporización.

## Integración y validación

La integración avanza desde la plataforma base y las pruebas individuales hasta el intercambio entre PWM, ADC y software. El modelo de potencia permite evaluar el controlador antes de su puesta en marcha experimental. El plan de cada subsistema incluye casos nominales, límites, reset y fallos identificables.

Las interfaces compartidas se revisan con sus responsables antes de cambiar puertos, registros o parámetros. El [directorio de testbenches](../../src/testbench/README.md) describe los ámbitos de prueba y el [informe](../informe/README.md) organiza los resultados.

[Descripción del proyecto](../../README.md)
