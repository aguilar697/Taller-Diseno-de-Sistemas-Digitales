# Evidencias de verificación por simulación

Esta carpeta reúne evidencias complementarias de las simulaciones realizadas durante la verificación funcional de los módulos del Proyecto 1.

Los archivos fuente de los testbenches se encuentran en:

```text
../../../src/testbench/
```

Las capturas presentadas a continuación corresponden a ejecuciones realizadas en Vivado y complementan el análisis incluido en el informe técnico.

## Resultados disponibles

| Testbench | Función verificada | Evidencia |
|---|---|---|
| `button_conditioner_tb.sv` | Sincronización, debounce y generación de pulsación única | [Ver captura](./button_conditioner_tb_run.png) |
| `buttons_frontend_tb.sv` | Acondicionamiento conjunto de los ocho botones | [Ver captura](./buttons_frontend_tb_run.png) |
| `difficulty_ctrl_tb.sv` | Reducción progresiva de la ventana de tiempo | [Ver captura](./difficulty_ctrl_tb_run.png) |
| `game_fsm_tb.sv` | Transiciones y señales principales de la FSM | [Ver captura](./game_fsm_tb_run.jpeg) |
| `game_over_timer_tb.sv` | Temporización del estado Game Over | [Ver captura](./game_over_timer_tb_run.png) |
| `hit_evaluator_tb.sv` | Detección de aciertos y pulsaciones incorrectas | [Ver captura](./hit_evaluator_tb_run.png) |
| `score_counters_tb.sv` | Conteo de aciertos, fallos y fallos consecutivos | [Ver captura](./score_counters_tb_run.png) |
| `sevenseg_driver_tb.sv` | Multiplexación y control de displays | [Ver captura](./sevenseg_driver_tb_run.png) |
| `tick_gen_tb.sv` | Generación de la base temporal | [Ver captura](./tick_gen_tb_run.png) |
| `turn_timer_tb.sv` | Temporización de la ventana activa y timeout | [Ver captura](./turn_timer_tb_run.png) |
| `uart_rx_tb.sv` | Recepción de tramas UART y generación de `data_valid` | [Ver captura](./uart_rx_tb_run.png) |

---

## Documentación relacionada

- [Informe técnico](../README.md)
- [Documentación de diseño](../../diseno/README.md)
- [README principal del Proyecto 1](../../../README.md)