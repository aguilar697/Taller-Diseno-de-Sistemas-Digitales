# Proyecto 1 — Whack-a-Mole

Proyecto desarrollado para el curso **EL3313 Taller de Diseño Digital** durante el **II Semestre de 2026**.

El proyecto consiste en la implementación de una versión electrónica del juego **Whack-a-Mole**, utilizando una arquitectura híbrida formada por:

- un **subsistema de lógica discreta**, encargado de generar y transmitir la posición pseudoaleatoria del topo;
- un **subsistema implementado en FPGA**, encargado del control completo del juego.

Ambos subsistemas operan con referencias de tiempo independientes y se comunican mediante un enlace serial **UART 8N1**.

---

## Estado del proyecto

**Proyecto finalizado y validado en hardware.**

La implementación fue probada utilizando una tarjeta **Digilent Basys 3** y el circuito discreto montado externamente.

Durante las pruebas funcionales se verificó:

- generación de nuevas posiciones;
- comunicación serial entre el circuito discreto y la FPGA;
- reconocimiento de los ocho botones externos;
- conteo de aciertos;
- conteo de fallos;
- detección de timeout;
- dificultad progresiva;
- manejo de fallos consecutivos;
- estado de Game Over;
- reinicio automático;
- visualización mediante los cuatro displays de siete segmentos.

---

## Objetivo

Diseñar e implementar un sistema digital híbrido que integre:

- lógica combinacional;
- lógica secuencial;
- máquinas de estados finitos;
- datapath y control path;
- comunicación serial asíncrona;
- sincronización de señales externas;
- filtrado de rebotes;
- generación pseudoaleatoria;
- temporización mediante clock enables;
- visualización de resultados.

El sistema debe permitir que un jugador responda a una posición generada externamente mediante ocho pulsadores, contabilizando aciertos y fallos y aumentando progresivamente la dificultad del juego.

---

## Arquitectura general

El sistema se divide en dos subsistemas principales:

```text
                  SUBSISTEMA DISCRETO
                ┌──────────────────────┐
                │                      │
mole_request ──►│ Generación de topo   │
                │ pseudoaleatorio      │
                │                      │
                │ Decodificación 3→8   │──► 8 LEDs
                │                      │
                │ Transmisor UART      │
                └──────────┬───────────┘
                           │
                           │ serial_data
                           ▼
                ┌──────────────────────┐
                │                      │
                │    SUBSISTEMA FPGA   │
                │                      │
                │  UART RX             │
                │  FSM del juego       │
                │  Botones externos    │
                │  Temporizadores      │
                │  Puntaje             │
                │  Dificultad          │
                │  Visualización       │
                │                      │
                └──────────┬───────────┘
                           │
               ┌───────────┼────────────┐
               ▼           ▼            ▼
          7 segmentos   LED estado   mole_request
```

El **subsistema discreto** genera la posición del topo y la transmite hacia la FPGA.

La **FPGA** concentra toda la lógica de control del juego.

---

## Funcionamiento general

Cada turno sigue la siguiente secuencia:

1. La FPGA activa la señal `mole_request`.
2. El circuito discreto genera una nueva posición pseudoaleatoria.
3. La posición se representa visualmente mediante uno de ocho LEDs.
4. El circuito discreto transmite la posición hacia la FPGA mediante UART.
5. La FPGA recibe el byte y utiliza sus tres bits menos significativos como posición activa.
6. Se habilita la ventana de tiempo del turno.
7. El jugador debe presionar el botón correspondiente.
8. La FPGA determina si ocurrió:
   - un acierto;
   - un botón incorrecto;
   - un timeout.
9. Se actualizan los contadores y la dificultad.
10. Si el jugador no ha alcanzado tres fallos consecutivos, se solicita una nueva posición.
11. Al alcanzar tres fallos consecutivos se activa el estado de Game Over.

---

## Subsistema discreto

El subsistema discreto se implementa utilizando circuitos integrados de lógica digital de la familia **74xx** y componentes externos.

Sus principales funciones son:

- generar una secuencia pseudoaleatoria;
- representar una de ocho posiciones;
- mostrar la posición activa mediante LEDs;
- responder a la señal `mole_request`;
- generar la trama serial;
- transmitir la posición mediante UART.

La posición del topo se representa mediante una palabra de **3 bits**, permitiendo codificar:

| Valor binario | Posición |
|---|---:|
| `000` | 0 |
| `001` | 1 |
| `010` | 2 |
| `011` | 3 |
| `100` | 4 |
| `101` | 5 |
| `110` | 6 |
| `111` | 7 |

La documentación detallada del circuito discreto, incluyendo esquemáticos, generación pseudoaleatoria y lógica de transmisión, se encuentra en:

[Documentación de diseño](./docs/diseno/README.md)

---

## Comunicación UART

La comunicación desde el circuito discreto hacia la FPGA utiliza un protocolo UART con configuración:

| Parámetro | Valor |
|---|---|
| Baud rate | **9600 baud** |
| Bits de inicio | 1 |
| Bits de datos | 8 |
| Paridad | Ninguna |
| Bits de parada | 1 |
| Formato | **8N1** |

La trama utilizada tiene la forma:

```text
       START               DATOS                     STOP
         │                                             │
         ▼                                             ▼
   ┌──────────┬───────────────────────────────────┬──────────┐
   │    0     │ D0 D1 D2 D3 D4 D5 D6 D7          │    1     │
   └──────────┴───────────────────────────────────┴──────────┘

              transmisión LSB primero
```

Los tres bits menos significativos:

```text
data[2:0]
```

representan la posición del topo.

---

## Sincronización de la entrada UART

La señal `serial_data` proviene de un circuito que no comparte el reloj de la FPGA.

Por esta razón, antes de ser procesada por el receptor UART se utiliza un **sincronizador de dos etapas**.

Conceptualmente:

```text
serial_data
     │
     ▼
    FF1
     │
     ▼
    FF2
     │
     ▼
 UART RX
```

Este mecanismo reduce la probabilidad de propagación de estados metaestables hacia la lógica interna de la FPGA.

---

## Subsistema FPGA

La FPGA utilizada es una:

**Digilent Basys 3 — Xilinx Artix-7 XC7A35T**

Todo el diseño funciona utilizando un único reloj principal de:

**100 MHz**

No se generan relojes secundarios para controlar los diferentes tiempos del sistema.

En su lugar se utilizan señales de **clock enable**, permitiendo mantener un único dominio de reloj.

---

## Módulos RTL

Los archivos sintetizables del proyecto se encuentran en:

```text
src/design/
```

La implementación está dividida en los siguientes módulos:

| Módulo | Función |
|---|---|
| `top_whack_a_mole.sv` | Integra todos los módulos del subsistema FPGA. |
| `game_fsm.sv` | Máquina de estados principal y control general del juego. |
| `uart_rx.sv` | Receptor UART y sincronización de la entrada serial. |
| `tick_gen.sv` | Genera la base temporal utilizada como clock enable. |
| `button_conditioner.sv` | Sincroniza, filtra rebotes y detecta una pulsación válida. |
| `buttons_frontend.sv` | Instancia el acondicionamiento para los ocho botones externos. |
| `hit_evaluator.sv` | Compara el botón presionado con la posición activa. |
| `turn_timer.sv` | Controla la duración de la ventana de tiempo del turno. |
| `difficulty_ctrl.sv` | Reduce progresivamente la duración de la ventana. |
| `score_counters.sv` | Lleva el conteo de aciertos, fallos y fallos consecutivos. |
| `game_over_timer.sv` | Controla la duración mínima del estado Game Over. |
| `sevenseg_driver.sv` | Controla y multiplexa los cuatro displays de siete segmentos. |

---

## Máquina de estados principal

El control del juego se implementa mediante una máquina de estados finitos.

Los estados principales son:

```text
S_RESET
   │
   ▼
S_REQUEST
   │
   ▼
S_WAIT_UART
   │
   ▼
S_ACTIVE
   │
   ▼
S_EVALUATE
   │
   ▼
S_CHECK
   │
   ├──────────────► S_REQUEST
   │
   └──────────────► S_GAMEOVER
                         │
                         ▼
                      S_RESET
```

### Función de los estados

| Estado | Función |
|---|---|
| `S_RESET` | Inicializa una nueva partida. |
| `S_REQUEST` | Solicita una nueva posición al circuito discreto. |
| `S_WAIT_UART` | Espera una respuesta UART cuando todavía no se ha recibido una posición. |
| `S_ACTIVE` | Mantiene activo el turno y espera la respuesta del jugador. |
| `S_EVALUATE` | Genera el pulso correspondiente a acierto o fallo. |
| `S_CHECK` | Verifica la cantidad de fallos consecutivos. |
| `S_GAMEOVER` | Mantiene el sistema en estado de fin de partida. |

---

## Manejo de respuesta UART durante `S_REQUEST`

Durante la integración física se identificó una condición temporal importante.

La señal:

```text
mole_request
```

permanece activa durante aproximadamente:

```text
5 ms
```

mientras que una trama UART a 9600 baud tarda aproximadamente:

```text
1.04 ms
```

Por esta razón, una respuesta UART podía completarse mientras la FSM todavía permanecía en `S_REQUEST`.

La implementación final utiliza:

```systemverilog
uart_pending
pending_position
```

para almacenar temporalmente una respuesta UART recibida durante este estado.

Conceptualmente:

```text
S_REQUEST
    │
    ├── data_valid = 1
    │       │
    │       ├── guardar posición
    │       └── uart_pending = 1
    │
    ▼
termina mole_request
    │
    ▼
¿uart_pending?
    │
    ├── Sí ──► cargar posición ──► S_ACTIVE
    │
    └── No ──► S_WAIT_UART
```

Esta modificación permitió integrar correctamente la comunicación entre ambos subsistemas.

---

## Entradas de golpe

El sistema utiliza **ocho botones externos**, uno para cada posición posible.

Las entradas se conectan a la FPGA mediante GPIO.

El acondicionamiento de cada botón incluye:

```text
Botón externo
      │
      ▼
Sincronizador
      │
      ▼
Debounce
      │
      ▼
Detección de flanco
      │
      ▼
press_pulse
```

La lógica utiliza:

```text
0 = botón no presionado
1 = botón presionado
```

Una pulsación física genera únicamente un evento válido, evitando múltiples conteos debido al rebote mecánico.

---

## Evaluación de golpes

La posición activa se compara con los ocho eventos de pulsación.

Por ejemplo:

```text
mole_position = 3
```

corresponde al botón:

```text
hit_buttons[3]
```

Si se presiona el botón correcto:

```text
HIT
```

Si se presiona una posición incorrecta:

```text
WRONG_HIT
```

Si ningún botón válido es presionado antes de finalizar la ventana:

```text
TIMEOUT
```

Tanto `WRONG_HIT` como `TIMEOUT` son contabilizados como fallos.

---

## Puntaje y vidas

El sistema mantiene tres valores principales:

### Aciertos acumulados

```text
hits
```

Rango visualizado:

```text
00 – 99
```

### Fallos acumulados

```text
misses
```

Rango visualizado:

```text
00 – 99
```

### Fallos consecutivos

```text
consecutive_misses
```

Este contador determina el estado de Game Over.

Un acierto reinicia:

```text
consecutive_misses = 0
```

pero no elimina los fallos acumulados.

Al alcanzar:

```text
consecutive_misses = 3
```

la partida termina.

---

## Dificultad progresiva

La ventana inicial del turno es:

```text
1500 ms
```

Cada acierto reduce su duración en:

```text
100 ms
```

hasta alcanzar un mínimo de:

```text
500 ms
```

La progresión utilizada es:

| Aciertos que reducen dificultad | Ventana |
|---:|---:|
| 0 | 1500 ms |
| 1 | 1400 ms |
| 2 | 1300 ms |
| 3 | 1200 ms |
| 4 | 1100 ms |
| 5 | 1000 ms |
| 6 | 900 ms |
| 7 | 800 ms |
| 8 | 700 ms |
| 9 | 600 ms |
| 10 o más | 500 ms |

Un fallo no devuelve la ventana a su valor inicial.

---

## Game Over

Al alcanzar tres fallos consecutivos:

```text
S_CHECK
    │
    ▼
S_GAMEOVER
```

Durante este estado:

- se activa el LED de estado;
- se bloquea el desarrollo normal de nuevos turnos;
- el sistema permanece al menos **2 segundos** en Game Over.

Después se genera automáticamente una nueva partida:

```text
hits                = 0
misses              = 0
consecutive_misses  = 0
window_ms           = 1500 ms
```

y se solicita una nueva posición.

---

## Visualización

Se utilizan los cuatro displays de siete segmentos de la Basys 3.

La distribución utilizada es:

```text
┌───────────┬───────────┐
│  Aciertos │   Fallos  │
├─────┬─────┼─────┬─────┤
│  D  │  U  │  D  │  U  │
└─────┴─────┴─────┴─────┘
```

Ejemplo:

```text
12 aciertos
03 fallos

Display:

1 2 0 3
```

Los cuatro dígitos se controlan mediante multiplexación.

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
│   │   └── img/
│   │
│   └── informe/
│       ├── README.md
│       ├── img/
│       └── resultados/
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

## Testbenches

Los testbenches se encuentran en:

```text
src/testbench/
```

Se desarrollaron pruebas para los módulos principales del sistema, incluyendo:

- generación de la base de tiempo;
- receptor UART;
- acondicionamiento de botones;
- frontend de botones;
- evaluación de golpes;
- control de dificultad;
- temporizador del turno;
- temporizador de Game Over;
- contadores;
- displays;
- FSM principal;
- integración completa del sistema.

Los testbenches utilizan mecanismos de verificación automática mediante mensajes de:

```systemverilog
$display(...)
```

y:

```systemverilog
$error(...)
```

permitiendo identificar automáticamente pruebas correctas y condiciones de fallo.

---

## Constraints

El archivo de restricciones utilizado es:

```text
src/constraints/Basys-3-Master.xdc
```

Este archivo define:

- reloj de 100 MHz;
- botón central de reset;
- ocho entradas externas de golpe;
- entrada `serial_data`;
- salida `mole_request`;
- LED de estado;
- segmentos de los displays;
- ánodos de los cuatro displays;
- estándar de entrada/salida `LVCMOS33`.

---

## Dependencias

Para trabajar con la implementación FPGA se requiere:

### Hardware

- Digilent Basys 3.
- Circuito discreto del Proyecto 1.
- Ocho botones externos.
- LEDs y componentes asociados al subsistema discreto.
- Cable USB para programación de la Basys 3.

### Software

- **AMD/Xilinx Vivado**
- Soporte para dispositivos **Xilinx Artix-7**
- Git, para clonar y gestionar el repositorio.

---

## Creación del proyecto en Vivado

El repositorio conserva los archivos fuente del diseño y no depende de rutas locales generadas automáticamente por Vivado.

Para recrear el proyecto:

1. Abrir Vivado.
2. Seleccionar **Create Project**.
3. Crear un proyecto RTL nuevo.
4. Seleccionar el dispositivo correspondiente a la Basys 3:
   - familia Artix-7;
   - dispositivo XC7A35T.
5. Agregar como **Design Sources** los archivos contenidos en:

```text
src/design/
```

6. Agregar como **Simulation Sources** los archivos contenidos en:

```text
src/testbench/
```

7. Agregar como **Constraints**:

```text
src/constraints/Basys-3-Master.xdc
```

8. Establecer como módulo principal de diseño:

```text
top_whack_a_mole
```

---

## Simulación

Para ejecutar una simulación desde Vivado:

1. Abrir **Simulation Sources**.
2. Seleccionar el testbench deseado como módulo superior de simulación.
3. Seleccionar:

```text
Run Simulation
→ Run Behavioral Simulation
```

4. Revisar los mensajes generados por el testbench y, cuando sea necesario, las formas de onda.

Para una prueba de integración general puede utilizarse:

```text
top_whack_a_mole_tb.sv
```

---

## Síntesis e implementación

Una vez cargados los archivos del proyecto:

```text
Run Synthesis
     │
     ▼
Run Implementation
     │
     ▼
Generate Bitstream
```

Después de generar el bitstream:

1. conectar la Basys 3;
2. abrir **Hardware Manager**;
3. seleccionar **Open Target**;
4. conectar la FPGA;
5. seleccionar **Program Device**.

---

## Uso del sistema

Con la FPGA programada y el subsistema discreto conectado:

1. Reiniciar el sistema mediante el botón central de la Basys 3.
2. La FPGA genera `mole_request`.
3. El circuito discreto selecciona una nueva posición.
4. El LED correspondiente indica el topo activo.
5. La posición se transmite mediante UART.
6. La FPGA abre la ventana de juego.
7. El jugador presiona uno de los ocho botones externos.
8. Los displays actualizan los aciertos o fallos.
9. Se solicita automáticamente una nueva posición.
10. Al alcanzar tres fallos consecutivos se activa Game Over.
11. El sistema se reinicia automáticamente después del tiempo establecido.

---

## Documentación

La documentación detallada del proyecto está disponible en:

### Diseño

[Documentación de diseño](./docs/diseno/README.md)

Incluye la arquitectura modular, diagramas, esquemáticos y decisiones de diseño.

### Informe técnico

[Informe técnico](./docs/informe/README.md)

Incluye fundamentación teórica, resultados, análisis, pruebas realizadas y conclusiones.

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