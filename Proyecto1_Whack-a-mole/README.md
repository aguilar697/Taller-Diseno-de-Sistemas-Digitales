# Proyecto 1 — Whack-a-Mole

Proyecto desarrollado para el curso **EL3313 Taller de Diseño Digital**, correspondiente al **II Semestre de 2026**.

El proyecto consiste en una implementación electrónica del juego **Whack-a-Mole** mediante una arquitectura híbrida compuesta por:

- un **subsistema de lógica discreta**, encargado de generar y transmitir la posición pseudoaleatoria;
- un **subsistema implementado en FPGA**, encargado del control completo del juego.

Ambos subsistemas poseen referencias temporales independientes y se comunican mediante un enlace serial **UART 8N1**.

---

## Estado del proyecto

**Proyecto finalizado y validado en hardware.**

La implementación fue probada utilizando:

- tarjeta **Digilent Basys 3**;
- FPGA **Xilinx Artix-7 XC7A35T**;
- circuito de lógica discreta externo;
- ocho pulsadores;
- ocho LEDs de posición;
- displays de siete segmentos de la Basys 3.

Durante las pruebas se verificaron la comunicación UART, detección de botones, puntaje, dificultad progresiva, temporización de los turnos, Game Over y reinicio automático.

---

## Objetivo

Diseñar e implementar un sistema digital híbrido que integre lógica combinacional, lógica secuencial, máquinas de estados, comunicación serial asíncrona, sincronización de señales externas, generación pseudoaleatoria y visualización de resultados.

El jugador debe responder a la posición indicada mediante uno de ocho pulsadores externos mientras la FPGA controla el tiempo disponible, aciertos, fallos y dificultad de cada partida.

---

## Arquitectura general

El sistema se divide en dos subsistemas principales:

```text
                   SUBSISTEMA DISCRETO
                  ┌──────────────────────┐
                  │ Generación temporal  │
                  │ LFSR                 │
mole_request ────►│ Decodificador 3 → 8 │────► LEDs
                  │ Transmisor UART      │
                  └──────────┬───────────┘
                             │
                             │ serial_data
                             ▼
                  ┌──────────────────────┐
                  │    SUBSISTEMA FPGA   │
                  │                      │
                  │ UART RX              │
                  │ FSM del juego        │
                  │ Botones              │
                  │ Temporizadores       │
                  │ Puntaje              │
                  │ Dificultad           │
                  │ Displays             │
                  └──────────────────────┘
```

La FPGA solicita una nueva posición mediante:

```text
mole_request
```

El circuito discreto responde mediante:

```text
serial_data
```

---

## Funcionamiento general

Cada turno sigue la siguiente secuencia:

1. La FPGA activa `mole_request`.
2. El circuito discreto actualiza el generador pseudoaleatorio.
3. La palabra generada se decodifica para activar el indicador correspondiente.
4. La posición se transmite hacia la FPGA mediante UART.
5. La FPGA recibe el byte.
6. Se habilita la ventana de tiempo del turno.
7. El jugador presiona uno de los ocho botones externos.
8. La FPGA determina si ocurrió un acierto, una pulsación incorrecta o un timeout.
9. Se actualizan los contadores y la dificultad.
10. Después de tres fallos consecutivos se activa el estado de Game Over.
11. El sistema reinicia automáticamente una nueva partida.

---

## Subsistema discreto

El subsistema discreto se implementa mediante circuitos integrados de la familia **74xx** y componentes externos.

Sus principales funciones son:

- generar una referencia temporal independiente;
- detectar una solicitud de la FPGA;
- generar una secuencia pseudoaleatoria mediante un LFSR;
- decodificar la palabra de posición;
- controlar los LEDs;
- formar una trama UART;
- transmitir la posición hacia la FPGA.

La información de posición utiliza una palabra de tres bits, por lo que el camino de datos y el decodificador permiten representar ocho combinaciones posibles:

| Palabra | Valor |
|---|---:|
| `000` | 0 |
| `001` | 1 |
| `010` | 2 |
| `011` | 3 |
| `100` | 4 |
| `101` | 5 |
| `110` | 6 |
| `111` | 7 |

El LFSR de tres bits implementado utiliza una secuencia de los **siete estados no nulos**. El estado `000` constituye un estado atrapado para la red de realimentación y, por esta razón, no forma parte de la secuencia normal del generador.

La descripción completa del circuito puede consultarse en:

[**Diseño detallado del subsistema discreto**](./docs/diseno/subsistema_discreto/README.md)

---

## Comunicación UART

La comunicación desde el circuito discreto hacia la FPGA utiliza:

| Parámetro | Valor |
|---|---|
| Baud rate | **9600 baud** |
| Start bit | 1 |
| Datos | 8 bits |
| Paridad | Ninguna |
| Stop bit | 1 |
| Formato | **8N1** |

Conceptualmente:

```text
REPOSO | START | D0 D1 D2 D3 D4 D5 D6 D7 | STOP | REPOSO
   1   |   0   |           DATA            |  1   |   1
```

La recepción se realiza mediante el módulo `uart_rx`.

Debido a que `serial_data` proviene de un dominio temporal independiente, la entrada es sincronizada antes de ser procesada por la lógica interna de la FPGA.

---

## Subsistema FPGA

El subsistema FPGA fue implementado en **SystemVerilog** y utiliza exclusivamente el reloj de 100 MHz de la Basys 3.

Los tiempos internos se obtienen mediante señales de **clock enable**, evitando generar dominios de reloj derivados dentro del FPGA.

### Módulos RTL

| Módulo | Función |
|---|---|
| `top_whack_a_mole.sv` | Integración general del sistema FPGA |
| `game_fsm.sv` | Máquina de estados principal |
| `uart_rx.sv` | Receptor UART |
| `tick_gen.sv` | Base temporal del sistema |
| `button_conditioner.sv` | Sincronización, debounce y detección de pulsación |
| `buttons_frontend.sv` | Acondicionamiento de los ocho botones |
| `hit_evaluator.sv` | Evaluación de golpes |
| `turn_timer.sv` | Temporización de la ventana activa |
| `difficulty_ctrl.sv` | Control de dificultad |
| `score_counters.sv` | Contadores de aciertos y fallos |
| `game_over_timer.sv` | Temporización del Game Over |
| `sevenseg_driver.sv` | Control de los displays |

La explicación detallada de la arquitectura, FSM, temporización, UART, botones y decisiones de diseño se encuentra en:

[**Documentación de diseño**](./docs/diseno/README.md)

---

## Reglas principales del juego

La ventana inicial de respuesta es:

```text
1500 ms
```

Cada acierto reduce la duración en:

```text
100 ms
```

hasta alcanzar:

```text
500 ms
```

Un fallo no aumenta nuevamente la ventana.

La FPGA mantiene tres conteos:

- aciertos acumulados;
- fallos acumulados;
- fallos consecutivos.

Un acierto reinicia únicamente el contador de fallos consecutivos.

Al alcanzar:

```text
3 fallos consecutivos
```

el sistema entra en Game Over durante al menos:

```text
2 segundos
```

Posteriormente se inicia automáticamente una nueva partida.

---

## Visualización

Los cuatro displays de siete segmentos muestran:

```text
┌─────────────┬─────────────┐
│   Aciertos  │    Fallos   │
├──────┬──────┼──────┬──────┤
│  D   │  U   │  D   │  U   │
└──────┴──────┴──────┴──────┘
```

La multiplexación es realizada por:

```text
sevenseg_driver.sv
```

---

## Estructura del proyecto

```text
Proyecto1_Whack-a-mole/
│
├── README.md
│
├── docs/
│   │
│   ├── diseno/
│   │   ├── README.md
│   │   ├── img/
│   │   │   ├── diagrama_nivel_1.pdf
│   │   │   ├── diagrama_nivel_2.pdf
│   │   │   ├── diagrama_nivel_3_fpga.pdf
│   │   │   ├── diagrama_nivel_3_discreto.pdf
│   │   │   ├── diagrama_nivel_4_fpga.pdf
│   │   │   └── diagrama_nivel_4_discreto.pdf
│   │   │
│   │   └── subsistema_discreto/
│   │       ├── README.md
│   │       └── img/
│   │
│   └── informe/
│       ├── README.md
│       ├── img/
│       └── resultados/
│           ├── README.md
│           └── evidencias de testbenches
│
└── src/
    │
    ├── design/
    │   ├── button_conditioner.sv
    │   ├── buttons_frontend.sv
    │   ├── difficulty_ctrl.sv
    │   ├── game_fsm.sv
    │   ├── game_over_timer.sv
    │   ├── hit_evaluator.sv
    │   ├── score_counters.sv
    │   ├── sevenseg_driver.sv
    │   ├── tick_gen.sv
    │   ├── top_whack_a_mole.sv
    │   ├── turn_timer.sv
    │   └── uart_rx.sv
    │
    ├── testbench/
    │   ├── button_conditioner_tb.sv
    │   ├── buttons_frontend_tb.sv
    │   ├── difficulty_ctrl_tb.sv
    │   ├── game_fsm_tb.sv
    │   ├── game_over_timer_tb.sv
    │   ├── hit_evaluator_tb.sv
    │   ├── score_counters_tb.sv
    │   ├── sevenseg_driver_tb.sv
    │   ├── tick_gen_tb.sv
    │   ├── top_whack_a_mole_tb.sv
    │   ├── turn_timer_tb.sv
    │   └── uart_rx_tb.sv
    │
    └── constraints/
        └── Basys-3-Master.xdc
```

---

## Verificación

Los módulos fueron verificados mediante testbenches desarrollados en SystemVerilog.

Las pruebas incluyen:

- generación de base temporal;
- recepción UART;
- acondicionamiento de botones;
- evaluación de golpes;
- dificultad;
- temporizadores;
- contadores;
- displays;
- FSM principal;
- integración del sistema.

Los testbenches utilizan mensajes como:

```systemverilog
$display(...)
```

y:

```systemverilog
$error(...)
```

para facilitar la identificación automática de condiciones correctas o incorrectas.

Las evidencias disponibles de simulación se encuentran en:

[**Resultados de testbenches**](./docs/informe/resultados/README.md)

---

## Constraints

El archivo de restricciones utilizado es:

```text
src/constraints/Basys-3-Master.xdc
```

Incluye la asignación correspondiente a:

- reloj de 100 MHz;
- reset;
- ocho botones externos;
- `serial_data`;
- `mole_request`;
- LED de estado;
- displays de siete segmentos;
- estándar `LVCMOS33`.

---

## Dependencias

### Hardware

- Digilent Basys 3.
- Circuito discreto del Proyecto 1.
- Ocho pulsadores externos.
- LEDs y componentes asociados.
- Cable USB para programación.

### Software

- AMD/Xilinx Vivado.
- Soporte para dispositivos Xilinx Artix-7.
- Git.

---

## Creación del proyecto en Vivado

El repositorio conserva únicamente los archivos fuente necesarios y no depende de los archivos locales generados automáticamente por Vivado.

Para recrear el proyecto:

1. Abrir Vivado.
2. Seleccionar **Create Project**.
3. Crear un proyecto RTL.
4. Seleccionar el dispositivo correspondiente a la Basys 3 / Artix-7 XC7A35T.
5. Agregar como **Design Sources**:

```text
src/design/
```

6. Agregar como **Simulation Sources**:

```text
src/testbench/
```

7. Agregar como **Constraints**:

```text
src/constraints/Basys-3-Master.xdc
```

8. Establecer como top de diseño:

```text
top_whack_a_mole
```

---

## Simulación

Para ejecutar una simulación:

```text
Run Simulation
    ↓
Run Behavioral Simulation
```

Se selecciona previamente el testbench correspondiente como módulo superior de simulación.

---

## Síntesis e implementación

El flujo utilizado es:

```text
Run Synthesis
     │
     ▼
Run Implementation
     │
     ▼
Generate Bitstream
     │
     ▼
Hardware Manager
     │
     ▼
Program Device
```

---

## Uso

Con la FPGA programada y el circuito discreto conectado:

1. Reiniciar el sistema mediante el botón central.
2. La FPGA solicita una nueva posición.
3. El circuito discreto actualiza el LFSR y muestra la posición.
4. La posición es transmitida mediante UART.
5. La FPGA habilita el turno.
6. El jugador presiona uno de los ocho botones.
7. Se actualiza el resultado y comienza un nuevo turno.
8. Tres fallos consecutivos producen Game Over.
9. Después del período de Game Over comienza una nueva partida.

---

## Documentación

### Diseño

La descripción completa de la arquitectura, diagramas, FSM y decisiones de diseño se encuentra en:

[**Documentación de diseño**](./docs/diseno/README.md)

### Subsistema discreto

La documentación específica del circuito implementado con lógica discreta se encuentra en:

[**Diseño detallado del subsistema discreto**](./docs/diseno/subsistema_discreto/README.md)

### Informe técnico

Los resultados, simulaciones, mediciones, problemas encontrados y conclusiones se encuentran en:

[**Informe técnico**](./docs/informe/README.md)

### Evidencias de simulación

[**Resultados de testbenches**](./docs/informe/resultados/README.md)

---

## Integrantes

| Nombre | Carné |
|---|---:|
| Kevin Aarón Aguilar Mora | 2023395928 |
| Kenneth Aarón Campos Rodríguez | 2021023141 |
| Kevin Cortéz González | 2023099872 |
| Daniel Puentes | 2022111281 |

---

## Docentes

- **Dr.-Ing. Jeferson González-Gómez**
- **Ing. Rolen Coto Calderón**

---

## Curso

**EL3313 — Taller de Diseño Digital**  
Escuela de Ingeniería Electrónica  
Instituto Tecnológico de Costa Rica  
**II Semestre 2026**