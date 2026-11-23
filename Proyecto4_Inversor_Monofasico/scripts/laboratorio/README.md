# Herramientas de laboratorio

Análisis de las tramas que exporta `control_inversor` por UART (botón BTNL) y compilación de variantes de frecuencia. Se usaron en la sesión del 21/11 registrada en la [bitácora](../../Potencia/04_registro_laboratorio.md).

| Herramienta | Uso |
|---|---|
| `graficar_ensayos.py` | Una gráfica por trama `.bin`: corriente medida, referencia y modulación con los límites de ±0,85. El título incluye estado, amplitud, error de la fundamental y desfase |
| `resumen_ensayos.py` | Tabla `resultados.md` con estado, causa de falla, fundamental, error, criterio del 10 %, desfase, predicción de PLECS a 12 y 24 V, ISR máxima y conversiones perdidas |
| `compilar_variante_frecuencia.ps1` | Compila el software a 20 o 25 kHz en una copia fuera del repositorio, ajustando `FREQ_SEL`, `F_SW_HZ`, `TRIGGER_PHASE` y `N_PWM_POR_CONTROL`. Copia las fuentes en `SALIDA/fuente` y compila en `SALIDA/sw` |
| `compilar_variante_parche.ps1` | Compila `control_inversor` con uno de los parches siguientes en una copia fuera del repositorio |
| `aplicar_captura_falla.py` | Parche de registro de falla: una muestra cada 100 µs (51,2 ms), la columna `i_ref` lleva el código bruto del ADC y los errores de STATUS, y tras una falla se graban 20 muestras más y se congela el registro. Exportar con BTNL antes de reconocer con BTND |
| `analizar_falla.py` | Decodifica una trama del registro de falla: código, corriente, m, errores y validez alrededor de la primera muestra anormal, con gráfica |
| `aplicar_captura_transitorio.py` | Parche de captura centrada: BTNL o un cambio de amplitud en marcha exportan la trama 51,2 ms después, con la mitad antes y la mitad después del evento |
| `analizar_transitorio.py` | Envolvente de un ciclo, instante del evento, pico posterior y tiempo hasta quedar dentro de ±10 % |
| `figuras_informe_potencia.py` | Figuras de los [informes de Potencia](../../docs/informe/potencia/README.md) a partir de las tramas, e impedancia de la carga a 50 Hz: fundamental de `m·Vdc`, menos la caída por tiempo muerto, dividida por la fundamental de la corriente |

Las dos herramientas de Python usan el decodificador y el análisis de [`receptor.py`](../../software/pc/receptor.py), así que dan los mismos números que el receptor.

## Captura y análisis

Desde la carpeta del Proyecto 4, con `pyserial` (y `matplotlib` para las gráficas):

```text
python software/pc/receptor.py --puerto COM8 --espera 120 --salida CARPETA/ensayo --graficar
python scripts/laboratorio/graficar_ensayos.py CARPETA
python scripts/laboratorio/resumen_ensayos.py CARPETA
```

El receptor espera una trama, la valida, guarda `ensayo.bin` y `ensayo.csv`, imprime el análisis y muestra la gráfica. Cada BTNL envía una sola trama con los últimos 102,4 ms. Para otra trama hay que volver a lanzar el receptor.

## Variantes de frecuencia

El período de control lo fija el Timer (100 µs) y no depende del PWM.

- **20 kHz:** entran dos períodos PWM por control (`N_PWM_POR_CONTROL = 2`, `TRIGGER_PHASE = 2500`) y el PR conserva sus coeficientes. Las pruebas de PC suponen un período por control: con N = 2 hay que avanzar `adc_n` en dos dentro del modelo de planta de `test_aplicacion.c`, ajustar la comprobación de continuidad del registro y llamar a `analizar(t, 2)` en `test_receptor.py`. Con esos ajustes, las 37 comprobaciones de la aplicación y la prueba del receptor pasan.
- **25 kHz:** corresponden 2,5 períodos por control, así que solo se usa `diagnostico_integrado`, que no ejecuta el PR.

Ninguna de las dos variantes se ensayó en la tarjeta.

## Variantes con parche

Los parches modifican solo `control/aplicacion.c`; el control y la supervisión no cambian. Con el registro de falla, las pruebas de PC que leen `i_ref` del registro fallan por diseño, porque esa columna ya no es la referencia. Con la captura de transitorio pasan si la prueba de exportación espera a que empiece la trama.

El registro de falla se usó el 23/11 para los dos reposos de [`laboratorio/2026-11-23`](../../docs/informe/resultados/potencia/laboratorio/2026-11-23/resultados.md). La captura de transitorio no se ha ensayado en la tarjeta.
