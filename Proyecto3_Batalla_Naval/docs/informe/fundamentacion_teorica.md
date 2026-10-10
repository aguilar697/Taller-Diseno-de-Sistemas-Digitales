# Fundamentación teórica

La plataforma de Batalla Naval combina un procesador de propósito general con periféricos especializados. Esta sección explica los conceptos que sustentan esa organización y su aplicación al diseño.

## 1. Arquitectura RISC-V, instrucciones y registros

RISC-V distingue la arquitectura del conjunto de instrucciones de la organización del circuito que las ejecuta. RV32I utiliza registros enteros de 32 bits: x0 siempre devuelve cero y x1–x31 conservan valores modificables. El PC identifica la instrucción en ejecución. Las instrucciones base ocupan 32 bits; los formatos R, I, S y U, y las variantes B y J, distribuyen los campos de registros, operación e inmediato. `opcode`, `funct3` y, cuando corresponde, `funct7` permiten identificar la operación. Los inmediatos se reconstruyen y extienden con signo; B/J incorporan un bit inferior cero en su desplazamiento. Fuente: [especificación RV32I, versión 2.1](https://docs.riscv.org/reference/isa/v20240411/unpriv/rv32.html).

| Formato | Campos de la instrucción, de bit 31 a bit 0 | Uso |
|---|---|---|
| R | `funct7 · rs2 · rs1 · funct3 · rd · opcode` | Operaciones entre registros |
| I | `imm[11:0] · rs1 · funct3 · rd · opcode` | Inmediatos, cargas y JALR |
| S | `imm[11:5] · rs2 · rs1 · funct3 · imm[4:0] · opcode` | Escrituras en memoria |
| B | `imm[12] · imm[10:5] · rs2 · rs1 · funct3 · imm[4:1] · imm[11] · opcode` | Bifurcaciones condicionales |
| U | `imm[31:12] · rd · opcode` | Construcción de constantes y direcciones |
| J | `imm[20] · imm[10:1] · imm[11] · imm[19:12] · rd · opcode` | Salto con enlace JAL |

`opcode` ocupa siete bits; cada índice de registro ocupa cinco y `funct3` ocupa tres. Por ejemplo, `addi x1, x0, 5` se codifica como `0x00500093`: selecciona una suma inmediata, lee el cero de x0 y escribe cinco en x1. La disposición de los inmediatos B/J exige reconstruir sus bits antes de sumarlos al PC.

El núcleo de este proyecto implementa **un subconjunto de 29 operaciones de RV32I**, definido en [instruction_decoder.sv](../../src/design/cpu/instruction_decoder.sv). Las cargas y escrituras admitidas son `lw` y `sw`, con alineación de cuatro bytes. El [banco de registros](../../src/design/cpu/register_file.sv) descarta escrituras a x0 y permite dos lecturas combinacionales y una escritura síncrona. Las instrucciones no admitidas llevan a `FAULT`, del que se sale mediante reset. El alcance excluye multiplicación, instrucciones comprimidas, CSR y excepciones privilegiadas.

## 2. Datapath y unidad de control

Un datapath conecta PC, banco de registros, ALU, memorias y multiplexores. La unidad de control determina qué datos se seleccionan y qué registros se actualizan. En una organización de ciclo único, las etapas necesarias para una instrucción deben completarse dentro de un solo período; la ruta de la instrucción más lenta condiciona ese período. Véase [MIT, *Single-Cycle Processors*](https://ocw.mit.edu/courses/6-823-computer-system-architecture-fall-2005/964e8d2c1085754ba5ed2eba48269a0b_l05_singlecycle.pdf).

El proyecto usa una organización **multiciclo sin pipeline**. La ROM y RAM tienen lectura síncrona; por ello se separan solicitud y captura. Los registros intermedios conservan instrucción, operandos, resultado y dato leído entre etapas. Una FSM activa las habilitaciones de cada etapa y completa una instrucción antes de comenzar otra. Esto facilita comprobar efectos de escritura y evita incorporar adelantamiento de datos, detección de dependencias o vaciado de un pipeline. El costo es un CPI mayor que uno. La elección y sus alternativas se explican en el [diseño del CPU](../diseno/nivel_3_cpu.md).

## 3. Periféricos mapeados en memoria

En MMIO, una dirección de datos identifica un registro de periférico. El procesador utiliza las mismas instrucciones de carga y escritura que para RAM; un decoder decide el destino. Separar control, estado y datos evita que una consulta produzca efectos imprevistos. En registros de 32 bits se deben precisar direcciones, bits válidos, permisos, valor de reset y efectos de lectura/escritura.

En el [bus del proyecto](../../src/design/bus/data_bus.sv), una escritura habilita únicamente el destino seleccionado. Las lecturas no reconocen eventos automáticamente. Por ejemplo, leer UART RX conserva el byte; escribir uno en el bit 1 de UART CONTROL reconoce su recepción mediante W1C. Las direcciones no mapeadas devuelven cero y sus escrituras se ignoran. El [segundo nivel](../diseno/nivel_2.md) y el [cuarto nivel de plataforma](../diseno/nivel_4_uart.md) documentan el mapa y el contrato temporal.

## 4. Temporización VGA

La generación VGA combina píxeles visibles con intervalos de frente, sincronismo y retorno. Los contadores horizontal y vertical deben recorrer también esos intervalos; dibujar solo los píxeles visibles no produce una señal VGA completa. La Basys 3 dispone de salidas RGB de cuatro bits por componente y dos señales de sincronismo. Fuente: [manual de referencia de Basys 3, sección VGA](https://digilent.com/reference/_media/reference/programmable-logic/basys-3/basys3_rm.pdf).

En [vga_timing.sv](../../src/design/vga/vga_timing.sv), cada línea contiene 640 + 16 + 96 + 48 = **800 ciclos**, y cada cuadro contiene 480 + 10 + 2 + 33 = **525 líneas**. Con 25 MHz se obtiene `25 000 000 / (800*525) = 59,524 Hz`, correspondiente al modo de 60 Hz nominales del proyecto. La línea dura 32 µs y el cuadro 16,8 ms. HSYNC y VSYNC son activos bajos. Clocking Wizard genera 25 MHz a partir de 100 MHz mediante MMCM; el reset de píxel se libera después de recuperar `locked` y sincronizarlo en ese dominio.

## 5. Gráficos por tiles

Un framebuffer almacena el color de cada píxel. Un sistema por tiles almacena descriptores de bloques y reconstruye su apariencia a partir de coordenadas y una ROM de glifos. Es apropiado cuando la imagen contiene casillas y texto con pocas variantes, como los tableros de este juego.

La pantalla se divide en 20 × 15 tiles de 32 × 32 píxeles. Los **300 descriptores de 32 bits ocupan 1200 bytes**. El intervalo MMIO reserva 512 palabras; solo los índices 0–299 son visibles. Un framebuffer de 640 × 480 con 12 bits por píxel necesitaría 460 800 bytes, frente a esos descriptores más la ROM de glifos. Esta comparación es de almacenamiento lógico, no de recursos finales de síntesis. El [renderer](../../src/design/vga/tile_renderer.sv) usa color en bits 2:0, habilitación de carácter en bit 3 y código de carácter en bits 11:4. La memoria posee un puerto CPU y otro de píxel; la lectura registrada se alinea con coordenadas y sincronismos.

## 6. Sincronización y debouncing

Un pulsador puede producir varias transiciones mecánicas al cambiar de posición. Además, su señal no está alineada con el reloj del FPGA. Son problemas diferentes: dos flip-flops sincronizan la entrada y reducen la propagación de metastabilidad; un filtro exige que el nuevo valor permanezca estable durante un intervalo antes de aceptarlo.

Los módulos [input_sync.sv](../../src/design/inputs/input_sync.sv) y [debounce.sv](../../src/design/inputs/debounce.sv) implementan ambas funciones. Con un millón de ciclos a 100 MHz, el filtro requiere **10 ms**. El programa interpreta las transiciones del estado filtrado para aceptar acciones; no cuenta cada ciclo de una pulsación mantenida como una nueva orden. SW15 controla el reset general mediante dos etapas de sincronización. BTNC corresponde a GAME_RST y pasa por el acondicionamiento de entradas del jugador.

## 7. Reglas de Batalla Naval

En Batalla Naval, cada jugador coloca su flota sin mostrarla al adversario. Los disparos se expresan mediante coordenadas; el resultado distingue agua, impacto y barco hundido. Gana quien hunde toda la flota contraria. Referencia general: [reglas oficiales de Hasbro](https://instructions.hasbro.com/es-mx/instruction/battleship).

El instructivo del curso define la variante implementada: tablero de **8 × 8**, tres barcos de longitudes **4, 3 y 2**, colocación horizontal/vertical sin traslape y alternancia después de un disparo válido. Una colocación fuera del tablero y un disparo repetido se rechazan. La colocación de ambos jugadores se atiende sin exigir que uno termine primero. El programa conserva el tablero oculto del rival y comunica solo información descubierta. GAME_RST reinicia la partida y conserva victorias; el reset general también borra el marcador. Las pruebas integradas cubren ambos ganadores.

## 8. Comunicación UART

UART transmite sin compartir una señal de reloj entre los extremos. En 8N1, cada byte incluye un inicio bajo, ocho bits de datos enviados desde el menos significativo y una parada alta. Ambos extremos deben acordar la velocidad. La interfaz USB-UART de Basys 3 proporciona la conexión serial con PC; sus señales hacia el FPGA se describen en el [manual de la tarjeta](https://digilent.com/reference/_media/reference/programmable-logic/basys-3/basys3_rm.pdf).

Con 100 MHz y un divisor de 868 ciclos, el bit dura 8,68 µs: aproximadamente 115207 baud, un error de 0,0064 % respecto a 115200. La UART actual se implementa en SystemVerilog como periférico de bytes; no instancia el núcleo VHDL ni el protocolo de Ahorcado del Proyecto 2. Encima de ella, el [protocolo del juego](../diseno/protocolo_uart_batalla_naval.md) agrega inicio `0xA5`, tipo, longitud y payload. UART no valida coordenadas ni turnos; esas reglas pertenecen al programa RISC-V. El registro RX mantiene un byte, sin FIFO: el servicio de software debe consumirlo antes de la siguiente recepción.

## 9. Aplicación PC y pySerial

pySerial permite configurar el puerto y sus parámetros, transmitir bytes y recibirlos con un timeout. Una lectura puede devolver menos bytes de los solicitados; por eso una trama no debe equipararse a una llamada a `read`. Referencia: [API de pySerial](https://pyserial.readthedocs.io/en/stable/pyserial_api.html).

La [terminal del proyecto](../../src/software_pc/naval_terminal.py) mantiene un buffer y reconstruye tramas de longitud conocida. Valida los datos introducidos, muestra su tablero y la información recibida, y se recupera ante `PLACEMENT_START` al comenzar una nueva partida. La aceptación de barcos, los turnos y el ganador se deciden en la FPGA. Las 31 pruebas de la aplicación comprueban parser, protocolo y estado sin depender de un puerto físico; la comunicación eléctrica requiere además una ejecución con la tarjeta conectada.

[Informe general](informe_general.md) · [Índice del informe](README.md)
