# Documentación de diseño — Proyecto 1: Whack-a-Mole

## EL3313 — Taller de Diseño Digital

Este documento presenta el planteamiento de diseño del **Proyecto 1 — Whack-a-Mole**, desarrollado mediante una arquitectura híbrida compuesta por un **subsistema de lógica discreta** y un **subsistema implementado en FPGA**.

El objetivo de esta documentación es describir la arquitectura propuesta, la división modular del sistema, las interfaces entre bloques, las principales decisiones de diseño y la estrategia utilizada para verificar la implementación.

La documentación se organiza siguiendo una metodología de **diseño modular jerárquico**, avanzando desde la representación general del sistema hasta los módulos funcionales que conforman cada subsistema.

---

# 1. Objetivos de diseño

## 1.1 Objetivo general

Diseñar e implementar una versión electrónica del juego **Whack-a-Mole** integrando lógica discreta y una FPGA, donde el circuito discreto genere la posición pseudoaleatoria del topo y la FPGA controle la dinámica completa del juego.

## 1.2 Objetivos específicos

- Diseñar un generador pseudoaleatorio de posiciones mediante un LFSR implementado con lógica discreta.
- Decodificar la posición generada y representarla mediante ocho LEDs.
- Establecer una comunicación serial UART entre el circuito discreto y la FPGA.
- Implementar en SystemVerilog la lógica de control del juego.
- Sincronizar y acondicionar las entradas asíncronas provenientes de UART y de los botones externos.
- Implementar temporización utilizando un único reloj de 100 MHz y señales de clock enable.
- Contabilizar aciertos, fallos acumulados y fallos consecutivos.
- Implementar dificultad progresiva mediante la reducción de la ventana de respuesta.
- Mostrar los resultados utilizando los cuatro displays de siete segmentos de la Basys 3.
- Verificar los módulos mediante testbenches antes de realizar la integración física.

---

# 2. Diseño modular del sistema

La arquitectura fue desarrollada mediante una descomposición jerárquica.

Se utilizaron diferentes niveles de abstracción para representar progresivamente el sistema:

```text
Nivel 1
Sistema completo como una única unidad
        │
        ▼
Nivel 2
Separación FPGA / lógica discreta
        │
        ▼
Nivel 3
Subsistemas y bloques funcionales
        │
        ▼
Nivel 4
Implementación detallada de cada subsistema
```

---

# 3. Diagrama de primer nivel

El primer nivel representa el sistema completo como una única unidad funcional.

En este nivel se identifican únicamente las entradas y salidas externas principales, sin describir todavía la estructura interna.

Las entradas principales son:

- reloj de 100 MHz;
- reset manual;
- ocho botones externos de golpe.

Las salidas principales corresponden a:

- ocho LEDs de posición;
- cuatro displays de siete segmentos;
- LED indicador del estado del juego.

[**Ver diagrama de primer nivel**](./img/diagrama_nivel_1.pdf)

---

# 4. Diagrama de segundo nivel

En el segundo nivel el sistema se divide en sus dos grandes subsistemas:

```text
              SUBSISTEMA DISCRETO
             ┌────────────────────┐
             │                    │
             │ Generación de      │
             │ posición           │
             │                    │
             └───────┬─────▲──────┘
                     │     │
          serial_data│     │mole_request
                     │     │
                     ▼     │
             ┌────────────────────┐
             │                    │
             │  SUBSISTEMA FPGA   │
             │                    │
             │ Control del juego  │
             │                    │
             └────────────────────┘
```

El **subsistema discreto** es responsable de generar una nueva posición y transmitirla.

El **subsistema FPGA** controla los turnos, tiempos, botones, puntaje, dificultad y visualización.

Los dos subsistemas utilizan referencias temporales independientes.

[**Ver diagrama de segundo nivel**](./img/diagrama_nivel_2.pdf)

---

# 5. Subsistema FPGA

El subsistema FPGA fue desarrollado en **SystemVerilog** y sintetizado para una tarjeta:

**Digilent Basys 3 — Xilinx Artix-7 XC7A35T**

Todo el diseño utiliza un único reloj principal de:

```text
100 MHz
```

Los diferentes tiempos de ejecución se obtienen mediante señales de **clock enable**, evitando la generación de nuevos dominios de reloj.

---

## 5.1 Arquitectura del subsistema FPGA

Los principales módulos implementados son:

| Módulo | Función |
|---|---|
| `top_whack_a_mole` | Integración general del subsistema FPGA |
| `game_fsm` | Control principal del juego |
| `uart_rx` | Recepción y sincronización de la comunicación serial |
| `tick_gen` | Generación de la base temporal |
| `button_conditioner` | Sincronización, debounce y detección de pulsación |
| `buttons_frontend` | Acondicionamiento de los ocho botones |
| `hit_evaluator` | Evaluación del botón presionado |
| `turn_timer` | Temporización de la ventana activa |
| `difficulty_ctrl` | Control de dificultad progresiva |
| `score_counters` | Conteo de aciertos y fallos |
| `game_over_timer` | Temporización del estado de fin de partida |
| `sevenseg_driver` | Multiplexación y control de displays |

[**Ver diagrama de tercer nivel del subsistema FPGA**](./img/diagrama_nivel_3_fpga.pdf)

[**Ver diagrama de cuarto nivel del subsistema FPGA**](./img/diagrama_nivel_4_fpga.pdf)

---

# 6. Control del juego

El bloque central del sistema FPGA es la máquina de estados `game_fsm`.

Su función es coordinar los demás módulos y establecer la secuencia de funcionamiento de cada turno.

Los estados utilizados son:

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

| Estado | Función |
|---|---|
| `S_RESET` | Preparar una nueva partida |
| `S_REQUEST` | Solicitar una nueva posición al circuito discreto |
| `S_WAIT_UART` | Esperar la recepción de una posición válida |
| `S_ACTIVE` | Mantener activa la ventana de golpe |
| `S_EVALUATE` | Generar el evento de acierto o fallo |
| `S_CHECK` | Revisar la cantidad de fallos consecutivos |
| `S_GAMEOVER` | Mantener el estado de fin de partida |

Las principales salidas de control se implementan siguiendo una estructura predominantemente **Moore**, donde señales como `mole_request`, `turn_enable` y `game_over_enable` dependen directamente del estado actual.

---

# 7. Comunicación UART

La comunicación desde el subsistema discreto hacia la FPGA utiliza un enlace serial asíncrono.

La configuración seleccionada es:

| Parámetro | Valor |
|---|---|
| Baud rate | 9600 baud |
| Start bit | 1 |
| Datos | 8 bits |
| Paridad | Ninguna |
| Stop bit | 1 |
| Formato | 8N1 |

La trama tiene la forma:

```text
START      DATOS D0 ... D7       STOP
  0      D0 D1 D2 D3 D4 D5 D6 D7   1
```

Los tres bits menos significativos representan la posición:

```text
data[2:0]
```

permitiendo codificar valores entre 0 y 7.

---

## 7.1 Sincronización UART

La señal `serial_data` proviene de un dominio temporal independiente.

Por esta razón, antes de ser utilizada por la lógica UART se implementa un sincronizador de dos etapas:

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

Esta estructura reduce la probabilidad de propagación de metastabilidad hacia la lógica interna.

---

## 7.2 Manejo de recepción durante `S_REQUEST`

Durante la integración se determinó que la respuesta UART podía completarse mientras la FSM todavía permanecía en `S_REQUEST`.

La solicitud tiene una duración aproximada de:

```text
5 ms
```

mientras una trama UART a 9600 baud requiere aproximadamente:

```text
1.04 ms
```

Por este motivo, la implementación final incorpora:

```text
pending_position
uart_pending
```

para almacenar una posición válida recibida antes de finalizar la solicitud.

Conceptualmente:

```text
S_REQUEST
    │
    ├── llega data_valid
    │       │
    │       ├── pending_position ← data[2:0]
    │       └── uart_pending ← 1
    │
    ▼
finaliza solicitud
    │
    ▼
¿uart_pending?
    │
    ├── Sí ──► S_ACTIVE
    │
    └── No ──► S_WAIT_UART
```

Esta decisión evita perder respuestas válidas debido a la diferencia temporal entre ambos subsistemas.

---

# 8. Acondicionamiento de botones

Los ocho botones de golpe son señales externas y asíncronas respecto al reloj de la FPGA.

Cada entrada se procesa mediante:

```text
Botón
  │
  ▼
Sincronización
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

La sincronización reduce los problemas asociados a metastabilidad.

El debounce evita que los rebotes mecánicos produzcan múltiples eventos.

Finalmente, la detección de flanco convierte una pulsación física en un único pulso válido para la lógica del juego.

---

# 9. Evaluación de aciertos y fallos

El módulo `hit_evaluator` compara la posición activa con los eventos de pulsación.

Durante `S_ACTIVE` pueden ocurrir tres condiciones:

```text
Botón correcto
      │
      ▼
     HIT

Botón incorrecto
      │
      ▼
 WRONG_HIT

Sin pulsación antes del tiempo límite
      │
      ▼
   TIMEOUT
```

Tanto `WRONG_HIT` como `TIMEOUT` son considerados fallos.

---

# 10. Temporización y clock enables

El diseño utiliza exclusivamente el reloj principal de 100 MHz.

El módulo `tick_gen` genera una señal de habilitación periódica utilizada como base temporal:

```text
100 MHz
   │
   ▼
tick_gen
   │
   ▼
tick_1ms
```

Los registros siguen siendo actualizados mediante:

```text
posedge clk
```

y `tick_1ms` únicamente determina cuándo deben cambiar los contadores asociados a tiempos del juego.

Esto evita la generación de relojes derivados adicionales.

---

# 11. Dificultad progresiva

La ventana inicial del turno es:

```text
1500 ms
```

Cada acierto reduce el tiempo disponible en:

```text
100 ms
```

hasta alcanzar un mínimo de:

```text
500 ms
```

| Nivel de reducción | Ventana |
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

Un fallo no aumenta nuevamente la duración de la ventana.

---

# 12. Puntaje y Game Over

Se utilizan tres conteos distintos:

| Contador | Función |
|---|---|
| `hits` | Aciertos acumulados |
| `misses` | Fallos acumulados |
| `consecutive_misses` | Fallos consecutivos |

Los valores `hits` y `misses` se muestran en los displays.

Un acierto reinicia únicamente:

```text
consecutive_misses
```

sin modificar el acumulado de fallos.

Al alcanzar tres fallos consecutivos:

```text
consecutive_misses = 3
```

la FSM entra a `S_GAMEOVER`.

El sistema permanece en este estado durante al menos 2 segundos y posteriormente inicia automáticamente una nueva partida.

---

# 13. Visualización

Los cuatro displays de siete segmentos de la Basys 3 muestran:

```text
┌─────────────┬─────────────┐
│   Aciertos  │    Fallos   │
├──────┬──────┼──────┬──────┤
│  D   │  U   │  D   │  U   │
└──────┴──────┴──────┴──────┘
```

El módulo `sevenseg_driver` utiliza multiplexación para controlar los cuatro dígitos mediante las líneas compartidas de segmentos.

---

# 14. Subsistema discreto

El subsistema discreto es responsable de:

- generar una referencia temporal independiente;
- detectar las solicitudes provenientes de la FPGA;
- generar una posición pseudoaleatoria;
- decodificar la posición;
- activar el LED correspondiente;
- formar la trama UART;
- transmitir la posición hacia la FPGA.

Su implementación utiliza circuitos integrados de la familia 74xx y un oscilador basado en temporizador 555.

[**Ver diagrama de tercer nivel del subsistema discreto**](./img/diagrama_nivel_3_discreto.pdf)

[**Ver diagrama de cuarto nivel del subsistema discreto**](./img/diagrama_nivel_4_discreto.pdf)

La explicación detallada del circuito, incluyendo LFSR, polinomio, tablas de transición, decodificador, generación de temporización y transmisor UART, se encuentra en:

[**Diseño detallado del subsistema discreto**](./subsistema_discreto/README.md)

---

# 15. Decisiones principales de diseño

| Decisión | Justificación |
|---|---|
| Diseño modular | Facilita desarrollo, simulación e integración por bloques |
| FSM central | Separa claramente las diferentes etapas del juego |
| UART 8N1 | Permite comunicación entre dominios sin reloj compartido |
| Sincronizador de dos FF | Reduce riesgo de metastabilidad |
| Clock enables | Mantienen un único dominio de reloj de 100 MHz |
| Debounce digital | Evita múltiples pulsaciones producidas por rebote |
| Detección de flanco | Convierte cada pulsación en un único evento |
| LFSR discreto | Produce una secuencia pseudoaleatoria sin dispositivos programables |
| Decodificador 3→8 | Permite seleccionar directamente una posición visual |
| Registros PISO | Permiten formar la transmisión serial mediante lógica discreta |

---

# 16. Estrategia de implementación

El desarrollo se realizó siguiendo una estrategia incremental:

```text
Diseño arquitectónico
        │
        ▼
Diseño de módulos
        │
        ▼
Implementación individual
        │
        ▼
Testbench por módulo
        │
        ▼
Integración progresiva
        │
        ▼
Simulación del sistema
        │
        ▼
Síntesis e implementación
        │
        ▼
Integración FPGA + protoboard
        │
        ▼
Validación física
```

Esta estrategia permitió aislar errores y verificar el funcionamiento de los bloques antes de integrarlos.

---

# 17. Plan de pruebas

La validación del sistema fue organizada por bloques funcionales.

| Bloque | Pruebas principales |
|---|---|
| `tick_gen` | Verificación del período de `tick_1ms` |
| `uart_rx` | Recepción correcta de bytes y generación de `data_valid` |
| `button_conditioner` | Sincronización, rebotes y pulsación única |
| `buttons_frontend` | Funcionamiento independiente de los ocho botones |
| `hit_evaluator` | Detección de hit y wrong hit |
| `difficulty_ctrl` | Reducción progresiva y límite de 500 ms |
| `turn_timer` | Generación correcta de timeout |
| `score_counters` | Aciertos, fallos y fallos consecutivos |
| `game_over_timer` | Duración del estado Game Over |
| `sevenseg_driver` | Multiplexación y representación decimal |
| `game_fsm` | Transiciones y señales de control |
| Sistema integrado | Secuencia completa de múltiples turnos |

La presentación y análisis detallado de los resultados obtenidos se encuentra en el informe técnico.

---

# 18. Archivos del diseño

Los módulos sintetizables se encuentran en:

```text
../../src/design/
```

Los testbenches se encuentran en:

```text
../../src/testbench/
```

El archivo de restricciones se encuentra en:

```text
../../src/constraints/
```

---

# 19. Documentación relacionada

- [**README general del Proyecto 1**](../../README.md)
- [**Diseño detallado del subsistema discreto**](./subsistema_discreto/README.md)
- [**Informe técnico final**](../informe/README.md)

---

## Curso

**EL3313 — Taller de Diseño Digital**  
Escuela de Ingeniería Electrónica  
Instituto Tecnológico de Costa Rica  
**II Semestre 2026**