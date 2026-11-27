# Herramientas de laboratorio

Análisis de las tramas que exporta `control_inversor` por UART y compilación de variantes de captura y frecuencia. Las condiciones de los ensayos del 21 y 23 de noviembre constan en la [bitácora](../../Potencia/04_registro_laboratorio.md).

| Herramienta | Uso |
|---|---|
| `graficar_ensayos.py` | Una gráfica por trama `.bin`: corriente medida, referencia y modulación con los límites de ±0,85. El título incluye estado, amplitud, error de la fundamental y desfase |
| `resumen_ensayos.py` | Tabla `resultados.md` con estado, causa de falla, fundamental, error, criterio del 10 %, desfase, predicción de PLECS a 12 y 24 V, ISR máxima y conversiones perdidas |
| `compilar_variante_frecuencia.ps1` | Compila el software a 20 o 25 kHz en una copia fuera del repositorio, ajustando `FREQ_SEL`, `F_SW_HZ`, `TRIGGER_PHASE` y `N_PWM_POR_CONTROL`. Copia las fuentes en `SALIDA/fuente` y compila en `SALIDA/sw` |
| `compilar_variante_parche.ps1` | Compila `control_inversor` con uno de los parches siguientes en una copia fuera del repositorio |
| `aplicar_captura_falla.py` | Parche de registro de falla: una muestra cada 100 µs (51,2 ms), la columna `i_ref` lleva el código bruto del ADC y los errores de STATUS, y tras una falla se graban 20 muestras más y se congela el registro. Exportar con BTNL antes de reconocer con BTND |
| `analizar_falla.py` | Decodifica una trama del registro de falla: código, corriente, m, errores y validez alrededor de la primera muestra anormal, con gráfica |
| `aplicar_captura_transitorio.py` | Parche de captura centrada: BTNL o un cambio de amplitud en marcha exportan la trama 51,2 ms después, con la mitad antes y la mitad después del evento |
| `aplicar_captura_larga.py` | La misma captura con ventana de 409,6 ms (`K_REG = 8`): la trama sale 204,8 ms después del evento |
| `aplicar_captura_carga.py` | Captura para el cambio de carga: ventana de 819,2 ms (`K_REG = 16`); con BTNL la trama sale 50 ms después y guarda ~0,77 s anteriores. Primero se retira el puente y enseguida se pulsa BTNL |
| `analizar_transitorio.py` | Detecta un cambio de amplitud de la referencia y reporta el pico y el establecimiento de la envolvente, si este se observa dentro de la captura |
| `analizar_cambio_carga.py` | Estima el cambio por un cruce sostenido de la amplitud de m. Admite la marca `--evento-ms` cuando el instante se conoce por otro medio. Reporta la caída y los errores antes y después |
| `analizar_osciloscopio.py` | Amplitud de 50 Hz de la resta CH1−CH2 del osciloscopio, descartando las muestras en 0 de los canales saturados |
| `figuras_informe_potencia.py` | Figuras de los [informes de Potencia](../../docs/informe/potencia/README.md) a partir de las tramas y del [CSV de 0,20 A](../../Potencia/mediciones_lab_osciloscopio/final_82a8226_12V/regimen/0a2_scope_16.csv); estima además la impedancia de la carga a 50 Hz a partir de `m·Vdc`, la caída por tiempo muerto y la fundamental de la corriente |

`graficar_ensayos.py` y `resumen_ensayos.py` usan el decodificador y el ajuste de fundamental de [`receptor.py`](../../software/pc/receptor.py). El resumen reserva las columnas de cumplimiento para las capturas de régimen y conserva la sección de notas.

## Captura y análisis

Desde la carpeta del Proyecto 4, con `pyserial` (y `matplotlib` para las gráficas):

```text
python software/pc/receptor.py --puerto COM8 --espera 120 --salida CARPETA/ensayo --graficar
python scripts/laboratorio/graficar_ensayos.py CARPETA
python scripts/laboratorio/resumen_ensayos.py CARPETA
```

El receptor espera una trama, verifica el CRC, guarda `ensayo.bin` y `ensayo.csv`, imprime el análisis y muestra la gráfica. Con el controlador general, cada pulsación de BTNL solicita una trama de los últimos 102,4 ms. Para otra trama hay que volver a lanzar el receptor.

Los analizadores de escalón y cambio de carga requieren NumPy y Matplotlib. Si se usa detección automática, un cambio menor de 0,03 en la envolvente de m o sin persistencia de un ciclo se reporta como indeterminado. El ajuste centrado usa muestras a ambos lados de cada instante. La última parte de la captura queda fuera del cálculo de establecimiento.

## Variantes de frecuencia

El período de control lo fija el Timer (100 µs) y no depende del PWM.

- **20 kHz:** entran dos períodos PWM por control (`N_PWM_POR_CONTROL = 2`, `TRIGGER_PHASE = 2500`) y el PR conserva sus coeficientes. Las pruebas de PC suponen un período por control: con N = 2 hay que avanzar `adc_n` en dos dentro del modelo de planta de `test_aplicacion.c`, ajustar la comprobación de continuidad del registro y llamar a `analizar(t, 2)` en `test_receptor.py`. Con esos ajustes, las 37 comprobaciones de la aplicación y la prueba del receptor pasan.
- **25 kHz:** corresponden 2,5 períodos por control, así que solo se usa `diagnostico_integrado`, que no ejecuta el PR.

Ninguna de las dos variantes se ensayó en la tarjeta.

## Variantes con parche

Los parches modifican solo `control/aplicacion.c`; el control y la supervisión no cambian. Con el registro de falla, las pruebas de PC que leen `i_ref` del registro fallan por diseño, porque esa columna ya no es la referencia. Con la captura de transitorio pasan si la prueba de exportación espera a que empiece la trama.

El 23/11 en la tarjeta ([`laboratorio/2026-11-23`](../../docs/informe/resultados/potencia/laboratorio/2026-11-23/resultados.md)): el registro de falla se usó en los dos reposos (01–02), la captura de 102 ms en los escalones 24–28 y la de 410 ms en los escalones 31–36 y en el cambio de carga (37). La captura para cambio de carga se compiló pero no se usó. Con 102 ms, sincronizar a mano BTNL con el retiro del puente no resultó; con 410 ms sí.
