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

## Documentación

- [Diseño e interfaces del sistema](docs/diseno/README.md).
- [Primer nivel: sistema, entradas y salidas](docs/diseno/nivel_1.md).
- [Segundo nivel: arquitectura e interconexiones](docs/diseno/nivel_2.md).
- [Tercer nivel del PWM: bloques e interfaz propuesta](docs/diseno/nivel_3_pwm.md).
- [Cuarto nivel del PWM: circuitos y secuencias](docs/diseno/nivel_4_pwm.md).
- [Organización del informe y las evidencias](docs/informe/README.md).
- [Módulos de hardware](src/design/README.md).
- [Verificación por subsistema](src/testbench/README.md).
- [Software embebido y herramientas de PC](software/README.md).
- [Scripts de construcción y verificación](scripts/README.md).
- [Modelado y simulación de potencia](modelos/README.md).

## Estructura

```text
Proyecto4_Inversor_Monofasico/
├── README.md
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
    └── plecs/
```

Las fuentes, los modelos y la documentación se conservan en estas carpetas. Los proyectos generados, bitstreams, ejecutables y resultados intermedios se producen en `build/`, excluido de Git. Las evidencias utilizadas en el informe se almacenan en `docs/informe/resultados/` con sus condiciones de ensayo.

## Herramientas

| Herramienta | Uso |
|---|---|
| Vivado y Vitis | Plataforma MicroBlaze V, integración de IP, implementación y software embebido; el instructivo especifica la versión 2025.1 |
| SystemVerilog | Periféricos personalizados y bancos de prueba |
| C | Drivers y aplicación de control |
| PLECS | Modelado del inversor, la carga y el controlador |
| Python | Herramientas de adquisición y análisis de datos en PC |

La configuración de tarjeta, dispositivo e IP se documenta junto con los scripts de construcción. Los procedimientos de compilación y ejecución acompañan a las fuentes correspondientes cuando se incorporan al proyecto.

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
