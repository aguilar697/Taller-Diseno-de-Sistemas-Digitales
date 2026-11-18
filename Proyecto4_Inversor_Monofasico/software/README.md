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

## Compilación y pruebas

El hardware se exporta como XSA para generar el BSP y los ELF con Vitis 2026.1. Las aplicaciones disponibles y los comandos se describen en la [reconstrucción de Basys 3](../docs/diseno/integracion_basys3.md#reconstrucción-y-programas).

Para las pruebas de PC, ejecutar desde la carpeta del Proyecto 4 con Python 3 y un compilador C disponible.

```text
python software/tests/correr_pruebas.py
```

## Recepción del histórico por UART

Instalar `pyserial` y sustituir `COM5` por el puerto USB-UART de la tarjeta. Con `control_inversor.elf`, BTN L solicita el histórico. El receptor verifica el CRC y guarda la trama binaria y un CSV con el prefijo indicado.

```text
python -m pip install pyserial
python software/pc/receptor.py --puerto COM5 --baudios 115200 --salida ensayo
```

Con `--archivo` se analiza una trama binaria guardada. La opción `--graficar` requiere `matplotlib`.

[Diseño del sistema](../docs/diseno/README.md) · [Descripción del proyecto](../README.md)
