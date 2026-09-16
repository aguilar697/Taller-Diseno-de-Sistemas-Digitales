# Proyecto 2 — Ahorcado

**EL3313 Taller de Diseño Digital · II Semestre 2026 · Grupo 3**

Juego implementado en una FPGA Basys 3, con terminal Python por UART a 115200 baud y presentación local mediante LCD 16×2, siete segmentos, LED y buzzer. La FPGA selecciona la palabra, evalúa letras, administra tiempo e intentos y determina el resultado; la PC presenta la información y transmite las entradas del jugador.

El sistema está integrado. El equipo reporta funcionamiento físico de la LCD, buzzer y terminal; las evidencias incorporadas y el alcance de las pruebas se distinguen en el [informe técnico](docs/informe/README.md). La simulación temporizada post-implementación y las capturas físicas completas no están acreditadas en esta versión documental.

## Documentación

- [Diseño e interfaces generales](docs/diseno/README.md).
- [Nivel 1: sistema](docs/diseno/nivel_1.md) y [nivel 2: subsistemas](docs/diseno/nivel_2.md).
- [S1: control y FSM principal](docs/diseno/nivel_3_control_del_juego.md).
- [S2: motor, nivel 3](docs/diseno/nivel_3_motor_del_juego.md) y [nivel 4](docs/diseno/nivel_4_motor_del_juego.md).
- [S3: UART, nivel 3](docs/diseno/nivel_3_uart_protocolo.md) y [nivel 4](docs/diseno/nivel_4_uart_protocolo.md).
- [S4: LCD e interfaz local](docs/diseno/nivel_3_interfaz_local.md).
- [Informe técnico, resultados y limitaciones](docs/informe/README.md).

## Responsabilidades

| Subsistema | Responsable |
|---|---|
| S1: control del juego y temporización | Kenneth Campos |
| S2: motor del juego | Kevin Aguilar |
| S3: UART, protocolo y aplicación Python | Daniel Puentes |
| S4: LCD, displays, LED y buzzer | Kevin Cortés |

La interfaz gráfica se originó durante el desarrollo de S4 y se incorporó a la integración con S3. El diseño completo se conecta en `src/design/top/top.sv`.

## Reglas y operación

| Parámetro | Valor |
|---|---|
| Reloj | 100 MHz |
| UART | 115200 baud, 8 datos, sin paridad, 1 stop; sin control de flujo por hardware |
| Banco | 50 palabras distintas, ASCII A–Z, de 4 a 12 caracteres |
| Fácil | 60 s; cualquiera de las 50 palabras |
| Difícil | 45 s; 35 palabras elegibles de longitud ≥6 |
| Intentos | 6 errores; repetir una letra no consume otro intento |
| Victorias | Contador desde reset, saturado en 99 |
| Resultado | Estado final mantenido por un temporizador de 3 s |

1. Conectar el LCD y buzzer según el XDC del sistema completo y programar `top`.
2. Abrir la terminal, seleccionar el puerto USB-UART de la Basys 3 y conectar a 115200 baud antes de iniciar la partida.
3. Presionar BTN_RST (central), alternar FACIL/DIFICIL con BTN_SEL (arriba) y confirmar con BTN_OK (abajo).
4. Enviar una letra y esperar su respuesta antes de continuar. La GUI impone esta espera; la consola requiere respetarla durante la operación.
5. La FPGA revela todas las coincidencias, conserva el patrón ante letras repetidas y comunica victoria o derrota. Tras el resultado vuelve a selección.

BTN_RST reinicia el juego y las victorias. Las letras recibidas en selección de modo o durante el resultado se descartan. Después de un reset durante partida, la terminal se resincroniza al recibir el siguiente START. Las limitaciones de recuperación y de eventos consecutivos se documentan en el informe.

En los displays, los dos dígitos derechos muestran el tiempo y los izquierdos las victorias. Los LED codifican selección `00`, partida `01` y resultado `10`.

## Estructura

```text
docs/
  diseno/                     Arquitectura, interfaces y FSM
    img/                      Diagramas y antecedentes por subsistema
  informe/                    Informe general y verificación de S1/S2/S3/S4
    resultados/
      control/                Capturas de control
      motor/                  Logs, capturas Vivado y reportes del motor aislado
      uart/                   Capturas de UART y simulación integrada
      integracion/            Regresión y reportes del top completo
src/
  design/
    control/                  RTL S1
    word_engine/              RTL S2 y banco ASCII de referencia
    uart/cod/                 RTL S3 y UART VHDL activa
    uart/Codigo administrado UART/  Núcleo original de referencia
    local_interface/          RTL S4; GUI en gui/
    top/                      Integración FPGA
    constraints/              XDC del sistema completo
  constraints/                XDC del ensayo UART aislado
  software/                   Terminal de consola
  testbench/                  Bancos RTL de control, motor, UART y top
```

## Reproducción en Vivado

Herramienta de referencia: **Vivado 2026.1**, simulador XSim y FPGA **xc7a35tcpg236-1**. La simulación utiliza lenguaje mixto SystemVerilog/VHDL.

1. Crear un proyecto RTL para el dispositivo indicado.
2. Agregar los `.sv` de `control`, `word_engine`, `local_interface`, `top` y `uart/cod` como fuentes de diseño. Agregar únicamente los tres `.vhd` de `uart/cod` como núcleo UART activo. La copia `Codigo administrado UART` se conserva como referencia y no debe compilarse junto con la activa.
3. Seleccionar **`top`** como top de diseño y agregar **`src/design/constraints/Basys-3-Master.xdc`**. No combinarlo con el XDC del ensayo UART.
4. Agregar los testbenches como fuentes de simulación. Para integración, seleccionar **`tb_top`** y ejecutar **Run All**. El resultado esperado es `TESTBENCH PASO: 0 errores`; se debe revisar también la ausencia de mensajes de fallo.
5. Para S2 seleccionar `word_engine_tb` y poner `word_bank.txt` en el directorio de trabajo de XSim. Los [pasos y resultados del motor](docs/informe/motor_verificacion.md) describen la prueba.
6. Ejecutar síntesis, implementación y generación del bitstream del `top` completo. Programar la Basys 3 desde Hardware Manager.

La prueba UART aislada usa `uart_protocol_hw_test_top` y `src/constraints/basys3_uart_test.xdc`. Emite un START fijo por cada letra válida y no implementa una partida completa.

### Conexiones de referencia

| Interfaz | Asignación del XDC completo |
|---|---|
| Reloj | W5, 100 MHz |
| BTN_RST / BTN_SEL / BTN_OK | U18 / T18 / U17 |
| UART RX / TX | B18 / A18, puente USB-UART integrado |
| LCD datos DB0…DB7 | Pmod JB; conector J1 del módulo |
| LCD RS / R-W / E | Pmod JC; conector J2 del módulo |
| Buzzer | J1 de la FPGA, señal JA[0] en Pmod JA |

El pin FPGA `J1` del buzzer y el conector `J1` del LCD son designaciones distintas. La alimentación del LCD depende de la revisión del módulo; el [manual PmodCLP](https://digilent.com/reference/_media/pmod:pmod:pmodCLP_rm.pdf) identifica 5 V para revisión A y 3.3 V para revisión B.

## Terminales Python

Desde `Proyecto2_Ahorcado`, con Python 3 y las dependencias de `requirements.txt`:

```powershell
python -m venv .venv
.venv\Scripts\python.exe -m pip install -r requirements.txt
.venv\Scripts\python.exe -m serial.tools.list_ports -v
.venv\Scripts\python.exe src/design/local_interface/gui/gui_terminal.py
```

La GUI utiliza PySimpleGUI, Pillow y pyserial. Como alternativa de consola:

```powershell
.venv\Scripts\python.exe src/software/serial_terminal.py COM6
```

`COM6` es un ejemplo: se selecciona el puerto detectado en cada equipo. Solo una aplicación debe abrirlo a la vez. En consola, `Q!` finaliza la ejecución. Las versiones exactas de dependencias de la instalación física no están registradas; `requirements.txt` declara los paquetes sin fijar versiones.

La PC transmite un byte A–Z sin CR/LF. La FPGA devuelve líneas ASCII terminadas en LF; los modos se codifican como `EASY`/`HARD`. El [protocolo completo](docs/diseno/nivel_3_uart_protocolo.md) define los mensajes.

## Trazabilidad

El desarrollo utiliza ramas personales, commits de avance, issues y pull requests. Los registros de verificación identifican las fuentes y separan resultados aislados de integración. Los archivos generados de Vivado no forman parte de las fuentes del entregable.
