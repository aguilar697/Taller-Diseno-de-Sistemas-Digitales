# Modelos de potencia y control

`plecs/` contiene los modelos del inversor monofásico, la carga RL y el controlador PR utilizados en el diseño y la comparación con las mediciones.

Cada modelo identifica versión de PLECS, parámetros, unidades, frecuencia de conmutación, período de control, condiciones iniciales y procedimiento de ejecución. Las simulaciones cubren los puntos nominales y los cambios de referencia y carga definidos en el [plan de resultados](../docs/informe/README.md#ensayos-de-corriente).

La contribución de actuación se coordina con Kevin Aguilar; la cadena de medición, con Kenneth Campos; y el controlador y su implementación, con Kevin Cortés, conforme al reparto del proyecto. Los parámetros compartidos deben corresponder a los documentados para la implementación digital y la etapa de potencia.

Los archivos del modelo forman parte de las fuentes. Los resultados temporales de simulación se generan en el directorio de trabajo y las evidencias utilizadas en el informe se conservan en `docs/informe/resultados/`.

[Descripción del proyecto](../README.md)
