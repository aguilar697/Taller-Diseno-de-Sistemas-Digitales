# Modelos de potencia y control

Los modelos permiten estudiar el puente H y la carga RL antes de integrar la etapa física con el control digital. Las decisiones de componentes se documentan en [Potencia](../Potencia/README.md).

| Archivo o directorio | Contenido |
|---|---|
| [plecs/proyecto4.plecs](plecs/proyecto4.plecs) | Archivo inicial de trabajo |
| [plecs/proyecto4_lazo_abierto.plecs](plecs/proyecto4_lazo_abierto.plecs) | Puente ideal con PWM unipolar y carga RL |
| [plecs/proyecto4_lazo_cerrado.plecs](plecs/proyecto4_lazo_cerrado.plecs) | PR continuo y ensayo de cambio resistivo a 12 V |
| [analisis/](analisis/README.md) | Cálculo de rizado PWM–RL, pruebas y comprobación lineal del PR inicial |

La [descripción de las simulaciones](../Potencia/02_simulacion_y_resultados.md) identifica los parámetros guardados y las limitaciones de cada modelo. Los bloques preparados para variar el bus no están conectados eléctricamente en el archivo de lazo cerrado; el ensayo conectado modifica la carga resistiva.

Los modelos actuales no incluyen el acondicionamiento del ACS712, los drivers ni la implementación discreta del controlador. Su actualización y los ensayos físicos forman parte del [plan de validación](../Potencia/03_pendientes_y_validacion.md).

Los resultados temporales se generan en `build/`, excluido de Git. Los datos utilizados en el informe se conservan en `docs/informe/resultados/` con sus condiciones de ensayo.

[Descripción del proyecto](../README.md)
