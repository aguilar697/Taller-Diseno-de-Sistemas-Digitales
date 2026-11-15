# Modelos de potencia y control

Los modelos permiten estudiar el puente H y la carga RL antes de integrar la etapa física con el control digital. Las decisiones de componentes se documentan en [Potencia](../Potencia/README.md).

| Archivo o directorio | Contenido |
|---|---|
| [plecs/proyecto4.plecs](plecs/proyecto4.plecs) | Archivo inicial de trabajo |
| [plecs/proyecto4_lazo_abierto.plecs](plecs/proyecto4_lazo_abierto.plecs) | Puente ideal con PWM unipolar y carga RL |
| [plecs/proyecto4_lazo_cerrado.plecs](plecs/proyecto4_lazo_cerrado.plecs) | PR continuo y ensayo de cambio resistivo a 12 V |
| [plecs/proyecto4_lazo_cerrado_modeloREAL.plecs](plecs/proyecto4_lazo_cerrado_modeloREAL.plecs) | PR continuo con L de 10 mH, cambios de bus y carga; conserva interruptores ideales |
| [plecs/proyecto4_pr_discreto.plecs](plecs/proyecto4_pr_discreto.plecs) | Candidato PR a 10 kHz con un período de retardo; parámetros iniciales de 12 V y 0,5 A pico |
| [plecs/proyecto4_funcional.plecs](plecs/proyecto4_funcional.plecs) | Tiempo muerto, Ron, medición nominal y cuantización; ensayos de referencia y carga |
| [analisis/](analisis/README.md) | Rizado PWM–RL, control continuo/discreto y ensayos automatizados de PLECS |

La [descripción de las simulaciones](../Potencia/02_simulacion_y_resultados.md) identifica los parámetros guardados y las limitaciones de cada modelo. Los bloques preparados para variar el bus no están conectados eléctricamente en el archivo de lazo cerrado; el ensayo conectado modifica la carga resistiva.

La copia funcional representa el acondicionamiento nominal y las órdenes con tiempo muerto. No reproduce el circuito eléctrico del IR2110, el ruido real del sensor ni el transformador no lineal. Los candidatos PR aún no incluyen anti-windup. La incorporación de datos físicos y los ensayos del montaje forman parte del [plan de validación](../Potencia/03_pendientes_y_validacion.md).

Los resultados temporales se generan en `build/`, excluido de Git. Los datos utilizados en el informe se conservan en `docs/informe/resultados/` con sus condiciones de ensayo.

[Descripción del proyecto](../README.md)
