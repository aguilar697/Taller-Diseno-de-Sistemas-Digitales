# Software embebido y herramientas de PC

El software embebido ejecuta el controlador PR en MicroBlaze V y accede a los periféricos mediante registros mapeados en memoria. Las herramientas de PC reciben, almacenan y analizan las muestras exportadas por UART.

| Carpeta | Alcance | Coordinación |
|---|---|---|
| `embedded/control/` | Referencia, controlador discreto, rutina periódica y estados de la aplicación | Kevin Cortés |
| `embedded/drivers/pwm/` | Acceso a los registros y configuración del PWM | Kevin Aguilar y Kevin Cortés |
| `embedded/drivers/adc/` | Lectura, estado y escalamiento de la adquisición | Kenneth Campos y Kevin Cortés |
| `embedded/uart/` | Exportación de muestras y atención de eventos de comunicación | Kevin Cortés |
| `pc/` | Recepción, almacenamiento, visualización y análisis de datos | Kevin Cortés |

Los drivers utilizan las direcciones definidas por la plataforma y los contratos de cada periférico. Los formatos de referencia y medición incluyen unidades, signo, escala y límites. La implementación del PR documenta coeficientes, período de control, inicialización y saturación.

El registro y la exportación de datos deben preservar la ejecución periódica del control. Las pruebas comparan el cálculo con un modelo de referencia y comprueban el buffer, el orden de muestras y la transmisión. Los proyectos y ejecutables generados por Vitis se almacenan en el directorio de trabajo; las fuentes C y su configuración de construcción se conservan en el repositorio.

[Diseño del sistema](../docs/diseno/README.md) · [Descripción del proyecto](../README.md)
