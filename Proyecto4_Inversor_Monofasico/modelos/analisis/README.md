# Análisis numérico de potencia

Estas herramientas conservan los estudios iniciales de la carga RL y el controlador continuo. Sus parámetros no corresponden todavía al montaje físico completo. El [documento de simulación](../../Potencia/02_simulacion_y_resultados.md) explica el alcance y la relación con PLECS.

| Herramienta | Función |
|---|---|
| `rizado_pwm_rl.py` | Respuesta RL por integración exponencial entre conmutaciones; rizado local respecto a la respuesta promediada |
| `test_rizado_pwm_rl.py` | Comprobaciones del cálculo y contraste con integración numérica independiente |
| `analizar_pr_inicial.py` | Estabilidad por Routh y seguimiento a 50 Hz para 18 plantas continuas del diseño inicial |

## Ejecución

Se requiere Python 3.10 o posterior. Los cálculos y las pruebas usan la biblioteca estándar; las figuras opcionales requieren Matplotlib. Desde la raíz del repositorio:

```powershell
python -B -m unittest discover -s Proyecto4_Inversor_Monofasico/modelos/analisis -p "test_*.py" -v
python -B Proyecto4_Inversor_Monofasico/modelos/analisis/analizar_pr_inicial.py
python -B Proyecto4_Inversor_Monofasico/modelos/analisis/rizado_pwm_rl.py
```

El último comando genera el barrido en `Proyecto4_Inversor_Monofasico/build/potencia/rizado/`, excluido de Git. El script admite `--salida` para escoger otro directorio y `--graficas` para producir SVG.

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

Los estudios excluyen saturación magnética, semiconductores reales, tiempo muerto, sensor y ADC. La comprobación del PR tampoco incorpora discretización ni retardos. Los resultados son cálculos reproducibles, no mediciones de laboratorio.

[Modelos](../README.md) · [Potencia](../../Potencia/README.md)
