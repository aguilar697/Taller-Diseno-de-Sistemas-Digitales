# Análisis numérico de potencia

Estas herramientas conservan los estudios iniciales y permiten evaluar el candidato PR discreto. Sus modelos no representan todavía el montaje físico completo. El [documento de simulación](../../Potencia/02_simulacion_y_resultados.md) explica el alcance y la relación con PLECS.

| Herramienta | Función |
|---|---|
| `rizado_pwm_rl.py` | Respuesta RL por integración exponencial entre conmutaciones; rizado local respecto a la respuesta promediada |
| `test_rizado_pwm_rl.py` | Comprobaciones del cálculo y contraste con integración numérica independiente |
| `analizar_pr_inicial.py` | Estabilidad por Routh y seguimiento a 50 Hz para 18 plantas continuas del diseño inicial |
| `pr_discreto.py` / `test_pr_discreto.py` | Tustin preajustado, estabilidad discreta con retardo, redondeo de coeficientes y seguimiento promediado |
| `verificar_pr_plecs.py` | Seis ensayos nominales del puente conmutado con PR discreto; usa una copia temporal instrumentada |
| `preparar_modelo_funcional.py` | Regenera `proyecto4_funcional.plecs` desde el PR discreto; sobrescribe únicamente esa copia generada |
| `ensayar_lazo_funcional.py` | Nominales, cambios de referencia/carga y comprobación de órdenes lógicas |
| `test_ensayos_funcionales.py` | Extracción de fundamental con armónicos y detección de solapamiento y huecos |

## Ejecución

Se requiere Python 3.10 o posterior. Los cálculos y las pruebas usan la biblioteca estándar; las figuras opcionales requieren Matplotlib. Desde la raíz del repositorio:

```powershell
python -B -m unittest discover -s Proyecto4_Inversor_Monofasico/modelos/analisis -p "test_*.py" -v
python -B Proyecto4_Inversor_Monofasico/modelos/analisis/analizar_pr_inicial.py
python -B Proyecto4_Inversor_Monofasico/modelos/analisis/rizado_pwm_rl.py
python -B Proyecto4_Inversor_Monofasico/modelos/analisis/pr_discreto.py
```

`rizado_pwm_rl.py` genera el barrido en `Proyecto4_Inversor_Monofasico/build/potencia/rizado/`, excluido de Git. Admite `--salida` para escoger otro directorio y `--graficas` para producir SVG. `pr_discreto.py` muestra sus resultados en la terminal.

Para repetir los ensayos de PLECS, abrir PLECS Standalone y habilitar su interfaz RPC local en las preferencias, con puerto 1080. El script no modifica esas preferencias ni los modelos originales:

```powershell
python -B Proyecto4_Inversor_Monofasico/modelos/analisis/verificar_pr_plecs.py
```

El resultado se genera en `build/potencia/pr_discreto_plecs.json`. Se puede escoger otro destino con `--salida` y otro puerto con `--puerto`. La copia temporal se cierra al terminar. El [registro conservado](../../docs/informe/resultados/potencia/pr_discreto_plecs.json) incluye los parámetros, la ventana, el método y la huella SHA-256 del modelo.

La copia funcional ya está generada. Para reconstruirla y repetir sus ensayos:

```powershell
python -B Proyecto4_Inversor_Monofasico/modelos/analisis/preparar_modelo_funcional.py
python -B Proyecto4_Inversor_Monofasico/modelos/analisis/ensayar_lazo_funcional.py
```

El segundo comando genera métricas y trazas resumidas en `build/potencia/lazo_funcional/`; admite `--salida` y `--puerto`. Los CSV exportados cada 100 µs sirven para observar transitorios y no para medir rizado de conmutación. Las métricas de fundamental se calculan a partir de datos cada 2 µs. Se conserva el [resumen de resultados](../../docs/informe/resultados/potencia/lazo_funcional.json), con hipótesis y exclusiones.

## Resultados conservados

El [barrido inicial](../../docs/informe/resultados/potencia/rizado_inicial/) incluye:

| Archivo | Contenido |
|---|---|
| `condiciones.json` | Hipótesis, método, ventana temporal y exclusiones |
| `barrido_rizado.csv` | Parámetros y métricas de los 144 escenarios |
| `ventana_rizado.csv` | Tensión y corrientes del ejemplo, con su residuo de conmutación |
| `comparacion_rizado.svg` | Comparación de escenarios nominales |
| `ventana_rizado.svg` | Detalle de cuatro períodos PWM |

Se descartan cinco ciclos de 50 Hz y se analizan otros cinco. La métrica principal es `rizado_residuo_max_pp_a`. Las columnas de envolvente y cota para modulación constante son referencias analíticas, no límites generales para cualquier transitorio.

Los estudios iniciales excluyen saturación magnética, semiconductores reales, tiempo muerto, sensor y ADC. `analizar_pr_inicial.py` evalúa únicamente el PR continuo. La copia funcional añade Ron, tiempo muerto, sensor nominal y ADC ideal cuantizado; continúa excluyendo ruido real, bootstrap, pérdidas de conmutación y comportamiento magnético. Los resultados numéricos y de PLECS se identifican por separado y no son mediciones de laboratorio.

[Modelos](../README.md) · [Potencia](../../Potencia/README.md)
