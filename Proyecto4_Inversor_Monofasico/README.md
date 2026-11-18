# Proyecto 4 — Control de corriente de un inversor monofásico

Proyecto conjunto de EL3313 Taller de Diseño Digital y EL4201 Procesamiento Electrónico de Potencia. El sistema regula la corriente de una carga RL mediante un inversor monofásico en puente H y un controlador proporcional-resonante (PR) discreto ejecutado en MicroBlaze V.

La plataforma integra adquisición ADC/XADC, un periférico PWM unipolar personalizado y comunicación UART para exportar las muestras almacenadas. El control se ejecuta periódicamente mediante interrupciones; la generación de señales PWM y la adquisición se coordinan en hardware.

## Organización del equipo

| Responsable | Subsistema | Alcance |
|---|---|---|
| Daniel Puentes | Plataforma MicroBlaze V | Procesador, memoria, reloj, reset, AXI, Timer, Block Design, entorno Vivado/Vitis y reconstrucción |
| Kevin Aguilar | PWM y actuación | Modulación unipolar, señales complementarias, tiempo muerto, AXI4-Lite, registros, frecuencias y disparo de adquisición |
| Kenneth Campos | Adquisición de corriente | ADC/XADC, sincronización, acondicionamiento, escalamiento, calibración y driver de lectura |
| Kevin Cortés | Control PR y software | Controlador discreto, interrupciones, referencia, buffer, UART, GPIO y herramientas de PC |

Cada responsable documenta y verifica su subsistema. Las interfaces entre plataforma, PWM, adquisición y control se acuerdan antes de integrar modificaciones que afecten a otros bloques.

El seguimiento se organiza en cuatro incidencias, una por subsistema. Las contribuciones se integran a `main` mediante pull requests desde las ramas de cada integrante. [Incidencias del Proyecto 4](https://github.com/aguilar697/Taller-Diseno-de-Sistemas-Digitales/issues).

Taller de Diseño Digital comprende a los cuatro integrantes. En Procesamiento Electrónico de Potencia participan Kevin Aguilar, Kenneth Campos y Kevin Cortés. Cada curso tiene su propia documentación y ambos comparten las evidencias de integración cuando corresponde.

## Documentación

- [Documento de diseño](docs/diseno/README.md) con objetivos, diagramas, interfaces y estrategia de verificación.
- [Informe técnico de Taller de Diseño Digital](docs/informe/README.md) con simulaciones, resultados de implementación y análisis de las mediciones.
- [Reconstrucción y conexiones en Basys 3](docs/diseno/integracion_basys3.md).
- [Diseño, simulación e informe de Potencia](Potencia/README.md).

La implementación digital generó bitstream y los bancos funcionales del PWM y la integración PWM–ADC pasaron. En el montaje se comprobó la conmutación a 10 kHz y la lectura del XADC en reposo. El ensayo a 3 V se detuvo durante el sondeo previo al PR y el seguimiento físico en lazo cerrado sigue pendiente.

## Estructura

```text
Proyecto4_Inversor_Monofasico/
├── README.md
├── Potencia/
│   ├── README.md
│   ├── 01_diseno_y_componentes.md
│   ├── 02_simulacion_y_resultados.md
│   ├── 03_pendientes_y_validacion.md
│   └── 04_registro_laboratorio.md
├── docs/
│   ├── diseno/
│   │   └── img/
│   └── informe/
│       └── resultados/
├── src/
│   ├── design/
│   │   ├── microblaze/
│   │   ├── pwm/
│   │   ├── adc/
│   │   └── top/
│   ├── testbench/
│   │   ├── pwm/
│   │   ├── adc/
│   │   └── integration/
│   └── constraints/
├── software/
│   ├── embedded/
│   │   ├── control/
│   │   ├── drivers/
│   │   │   ├── pwm/
│   │   │   └── adc/
│   │   └── uart/
│   └── pc/
├── scripts/
│   ├── vivado/
│   ├── vitis/
│   └── verificacion/
└── modelos/
    ├── analisis/
    └── plecs/
```

Las fuentes, los modelos y la documentación se conservan en estas carpetas. Vivado y Vitis generan proyectos, bitstreams y ejecutables en directorios externos al repositorio. Las pruebas de PC utilizan `build/`, excluido de Git. Las evidencias utilizadas en el informe se almacenan en `docs/informe/resultados/` con sus condiciones de ensayo.

## Herramientas

| Herramienta | Uso |
|---|---|
| Vivado y Vitis | Reconstrucción, implementación, firmware y simulación con XSim. Se verificó la versión 2026.1. La compatibilidad con 2025.1, solicitada por el instructivo, queda pendiente. |
| SystemVerilog | Periféricos personalizados y bancos de prueba |
| C | Drivers y aplicación de control |
| PLECS | Modelado del inversor, la carga y el controlador |
| Python 3 y compilador C | Ejecución de los bancos desde consola y de las pruebas del software en PC. La comunicación serie en PC requiere `pyserial`. |

Para repetir las pruebas desde la carpeta `Proyecto4_Inversor_Monofasico`, usar un directorio nuevo para la salida de XSim y sustituir `RUTA_VIVADO` por el directorio de instalación de Vivado.

```text
python scripts/verificacion/ejecutar_integracion_digital.py SALIDA_PRUEBAS --vivado-home RUTA_VIVADO
python software/tests/correr_pruebas.py
```

Las opciones de los bancos, la generación de ondas y la prueba temporizada se explican en la [guía de verificación RTL](src/testbench/README.md). La compilación para MicroBlaze V y la recepción de datos se describen en la [guía de software](software/README.md).

## Requisitos generales

- MicroBlaze V a 100 MHz, caché de instrucciones de 8 KB y memoria local de 32 KB.
- Interfaz AXI4-Lite para el PWM personalizado, con al menos tres frecuencias seleccionables, tiempo muerto configurable y saturación de referencia.
- Adquisición iniciada por software y sincronizada con PWM.
- Ejecución periódica del PR, almacenamiento de muestras y exportación UART solicitada mediante un botón.
- Puente H con alimentación de 12 a 24 V DC y carga RL justificada.
- Referencias sinusoidales de 50 Hz y amplitudes de 0,2; 0,5 y 1,0 A pico.

Los formatos numéricos, las frecuencias de conmutación, el período de control y el tiempo muerto forman parte del diseño coordinado del sistema.

## Referencia

*Proyecto 4: Control de corriente en un inversor monofásico mediante un regulador PR discreto sobre MicroBlaze V*. Instructivo conjunto de EL3313 Taller de Diseño Digital y EL4201 Procesamiento Electrónico de Potencia, Instituto Tecnológico de Costa Rica, II semestre de 2026.

[Repositorio del curso](../README.md)
