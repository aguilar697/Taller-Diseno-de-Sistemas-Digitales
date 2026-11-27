# Capturas del osciloscopio del 23/11

La [campaña final del 26/11](final_82a8226_12V/README.md) corresponde a la versión presentada y al bus fijo de 12 V. Las capturas de esta página corresponden al 23/11.

Resta CH1−CH2 (función F1) sobre una resistencia de 3,3 Ω de la carga, con el osciloscopio Agilent DSO-X 2002A a 10 ms/div. Cada carpeta corresponde a una condición: `carga/referencia en A pico/bus en V`. Cada una tiene una imagen de la pantalla y el CSV de la resta (2000 puntos en 100 ms, uno cada 50 µs).

| Carpeta | Tramas del XADC de la misma condición |
|---|---|
| `6_6/0.2/12`, `6_6/0.2/24` | 18 y 19 de [`laboratorio/2026-11-23`](../../docs/informe/resultados/potencia/laboratorio/2026-11-23/resultados.md) |
| `6_6/0.5/12`, `6_6/0.5/24` | 20 y 21 |
| `6_6/1/12`, `6_6/1/24` | 22 y 23 |
| `9_9/0.2/12`, `9_9/0.2/24` | 11 y 12 |
| `9_9/0.5/12`, `9_9/0.5/24` | 14 y 15 |
| `9_9/1/12`, `9_9/1/24` | 16 y 17 |

**Limitación.** Los canales estaban en una escala para la caída de la resistencia. Cuando los extremos de la resistencia suben a +Vbus, los dos canales saturan en el mismo valor y la resta exporta 0: la mitad de las muestras de cada CSV es 0 exacto. Con la mitad válida no se resuelve el rizado de conmutación y la amplitud de 50 Hz no es consistente con la del XADC, así que estas capturas no sirven para el rizado ni para contrastar la ganancia del sensor. [`analizar_osciloscopio.py`](../../scripts/laboratorio/analizar_osciloscopio.py) calcula la amplitud con las muestras válidas.

Para repetir la medición: los dos canales a 5 V/div con el cero 2–3 divisiones arriba del fondo, Math F1 = 1 − 2, longitud máxima del CSV, 5 ms/div para la amplitud y 20 µs/div para el rizado, y una captura con las dos puntas en el mismo extremo como piso de error.
