| Ensayo | Estado | Causa | Ref. pico | Fundamental | Error | ≤10 % | Desfase | PLECS 12 V | PLECS 24 V | ISR máx. | Conv. perdidas |
|---|---|---|---:|---:|---:|---|---:|---|---|---:|---:|
| 01_reposo_bus_off | DETENIDO | ninguna | 0.0 A | — | — | — | — | — | — | 10.75 µs | 0 |
| 02_reposo_bus_24v | DETENIDO | ninguna | 0.0 A | — | — | — | — | — | — | 10.75 µs | 0 |
| 03_pr_12v_0a2 | OPERACIÓN | ninguna | 0.200 A | 0.1899 A | -5.05 % | sí | -3.05° | 0.1935 A / -0.90° | 0.1967 A / -0.45° | 8.57 µs | 0 |
| 04_pr_24v_0a2 | OPERACIÓN | ninguna | 0.200 A | 0.1928 A | -3.62 % | sí | -1.87° | 0.1935 A / -0.90° | 0.1967 A / -0.45° | 8.57 µs | 0 |
| 05_pr_12v_0a5 | OPERACIÓN | ninguna | 0.500 A | 0.3178 A | -36.43 % | no | -43.47° | 0.4839 A / -0.90° | 0.4918 A / -0.45° | 8.57 µs | 0 |
| 06_pr_24v_0a5 | OPERACIÓN | ninguna | 0.500 A | 0.4705 A | -5.91 % | sí | -3.87° | 0.4839 A / -0.90° | 0.4918 A / -0.45° | 8.57 µs | 0 |
| 07_pr_12v_1a | OPERACIÓN | ninguna | 1.000 A | 0.3291 A | -67.09 % | no | -43.53° | 0.9677 A / -0.90° | 0.9836 A / -0.45° | 8.57 µs | 0 |
| 08_pr_24v_1a | OPERACIÓN | ninguna | 1.000 A | 0.7358 A | -26.42 % | no | -26.37° | 0.9677 A / -0.90° | 0.9836 A / -0.45° | 8.57 µs | 0 |

Las tramas 01 y 02 se tomaron con la variante de registro de falla (`scripts/laboratorio/aplicar_captura_falla.py`): una muestra cada 100 µs y la columna `i_ref` con el código bruto del ADC. Sus gráficas se generaron con `analizar_falla.py`. Las tramas 03 a 08 son de `control_inversor` de la rama `kCortes` (d2d60c6).
