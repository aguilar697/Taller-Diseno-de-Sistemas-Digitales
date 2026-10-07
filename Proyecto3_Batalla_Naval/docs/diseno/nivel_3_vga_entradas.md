# Tercer nivel — VGA y entradas del Jugador 1

**Subsistema:** S2.  
**Responsable:** Kenneth Campos.

## 1. Objetivo

El Subsistema 2 implementa la interfaz local del Jugador 1. Su función es generar la salida VGA del sistema, almacenar y leer la memoria de video basada en tiles, producir los sincronismos de video a partir de un reloj de píxel derivado del reloj principal y acondicionar las entradas físicas del Jugador 1 mediante sincronización y debouncing.

Este subsistema no implementa reglas de Batalla Naval. La colocación de barcos, validación de disparos, detección de impactos, hundimientos, turnos y victoria se resuelven en el programa ensamblador ejecutado por el procesador RISC-V.

## 2. Diagrama del subsistema

![Diagrama de tercer nivel del Subsistema 2](img/vga_entradas/nivel_3_vga_entradas.svg)

**Figura 1. Arquitectura interna del Subsistema 2: VGA, memoria de video, reloj de píxel y entradas del Jugador 1.**

Las flechas continuas representan conexiones funcionales de datos y control. Las líneas discontinuas representan distribución de reloj y reset entre dominios. El puerto CPU de la memoria VGA opera con el reloj principal de 100 MHz, mientras que el puerto de video opera con el reloj de píxel derivado por PLL.

La reasignación física realizada durante la validación final únicamente modifica la conexión entre los controles de la Basys 3 y las señales lógicas del Subsistema 2. Los módulos internos, el formato del registro de entradas y el mapa MMIO permanecen sin cambios.

## 3. Función de los bloques

| Bloque | Función e intercambio principal |
|---|---|
| Clock / PLL + Pixel Reset | Generar el reloj de píxel de 25 MHz a partir de 100 MHz y acondicionar la liberación de reset en el dominio VGA |
| VGA Timing Controller | Generar contadores horizontal y vertical, `HSYNC`, `VSYNC`, `active_video`, `pixel_x` y `pixel_y` |
| Video Memory Dual-Port | Permitir acceso de lectura/escritura desde CPU a 100 MHz y lectura simultánea desde el generador VGA a 25 MHz |
| Tile / Glyph Renderer | Convertir coordenadas de píxel en índices de tile, interpretar el contenido de la memoria y producir la salida RGB |
| Player 1 Input Peripheral | Sincronizar y filtrar las siete entradas del Jugador 1 y exponer su estado al CPU mediante MMIO |

## 4. Interfaz externa del Subsistema 2

### 4.1 Señales generales

| Señal | Ancho | Dirección | Función |
|---|---:|---|---|
| `clk_100_i` | 1 | Entrada | Reloj principal del sistema, 100 MHz |
| `rst_i` | 1 | Entrada | Reset síncrono activo alto en el dominio de 100 MHz |

El reset interno del Subsistema 2 continúa siendo activo en alto. Esta condición no fue modificada al cambiar la distribución física de controles.

En el top independiente utilizado para la prueba física, `subsystem2_basys3_test_top.sv`, el switch `SW15` se utiliza como habilitación física del subsistema mediante:

```systemverilog
assign rst = ~sw[15];
```

Por tanto, en la prueba física:

```text
SW15 = 0 -> rst = 1 -> Subsistema 2 en reset
SW15 = 1 -> rst = 0 -> Subsistema 2 habilitado
```

Esta inversión pertenece exclusivamente al top físico de prueba y no cambia la polaridad interna de `rst_i`.

### 4.2 Interfaz VGA hacia el bus/MMIO

| Señal | Ancho | Dirección | Función |
|---|---:|---|---|
| `vga_write_enable_i` | 1 | Entrada | Habilita escritura del CPU en la memoria de video |
| `vga_addr_i` | 9 | Entrada | Índice local de palabra/tile dentro del espacio VGA |
| `vga_wdata_i` | 32 | Entrada | Palabra escrita por el CPU |
| `vga_rdata_o` | 32 | Salida | Palabra leída desde memoria de video |

La dirección absoluta reservada para VGA es `0x00011000–0x000117FF`. El bus convierte la dirección absoluta del CPU en un índice local de 9 bits antes de entregarlo al subsistema.

### 4.3 Interfaz del periférico de entradas

| Señal | Ancho | Dirección | Función |
|---|---:|---|---|
| `input_write_enable_i` | 1 | Entrada | Señal estándar de escritura MMIO; las escrituras son ignoradas |
| `input_addr_i` | 2 | Entrada | Índice local de registro |
| `input_wdata_i` | 32 | Entrada | Dato de escritura estándar; no modifica el estado de botones |
| `input_rdata_o` | 32 | Salida | Estado filtrado de las entradas J1 |

### 4.4 Entradas físicas del Jugador 1

La asignación física final de los controles del Jugador 1 es:

| Entrada física | Función |
|---|---|
| `BTNU` | `UP` — navegación hacia arriba |
| `BTND` | `DOWN` — navegación hacia abajo |
| `BTNL` | `LEFT` — navegación hacia la izquierda |
| `BTNR` | `RIGHT` — navegación hacia la derecha |
| `SW0` | `SEL` — selección / rotación |
| `SW1` | `OK` — confirmación |
| botón central (`BTNC`) | `GAME_RST` — reinicio de partida |

La distribución inicial utilizaba `BTNC` como `SEL` y `SW0` como `GAME_RST`. Durante la integración final se intercambiaron ambas funciones para utilizar el botón central como reinicio de partida.

Por tanto, la asignación final es:

```text
BTNU -> UP
BTND -> DOWN
BTNL -> LEFT
BTNR -> RIGHT
SW0  -> SEL
SW1  -> OK
BTNC -> GAME_RST
```

Esta modificación no cambia el mapa MMIO. Únicamente modifica qué elemento físico genera cada señal lógica.

Como `SEL` se encuentra ahora en `SW0`, para generar acciones sucesivas de selección debe producirse una nueva transición del switch. El software es responsable de detectar el flanco correspondiente y evitar repeticiones mientras la entrada permanece en el mismo nivel.

`SW15` no forma parte del registro de entradas del Jugador 1. En el top de prueba se utiliza únicamente como habilitación/reset general del hardware.

### 4.5 Salidas físicas VGA

| Señal | Dirección | Función |
|---|---|---|
| `VGA_HSYNC` | Salida | Sincronismo horizontal |
| `VGA_VSYNC` | Salida | Sincronismo vertical |
| `VGA_RGB` | Salida | Información de color hacia el monitor |

### 4.6 Indicadores utilizados en la prueba física

El top independiente `subsystem2_basys3_test_top.sv` utiliza los LEDs de la Basys 3 para observar directamente el estado de las entradas después de sincronización y debounce.

| LED | Función observada |
|---:|---|
| `LED0` | `UP` |
| `LED1` | `DOWN` |
| `LED2` | `LEFT` |
| `LED3` | `RIGHT` |
| `LED4` | `SEL` |
| `LED5` | `OK` |
| `LED6` | `GAME_RST` |
| `LED7–LED13` | Reservados / apagados |
| `LED14` | Inicialización completa de VRAM (`init_done_q`) |
| `LED15` | Subsistema habilitado / `RUN` |

La relación entre controles físicos y LEDs es:

```text
BTNU -> UP       -> LED0
BTND -> DOWN     -> LED1
BTNL -> LEFT     -> LED2
BTNR -> RIGHT    -> LED3
SW0  -> SEL      -> LED4
SW1  -> OK       -> LED5
BTNC -> GAME_RST -> LED6
```

Los LEDs `LED0–LED6` no representan directamente la entrada eléctrica sin acondicionar. Se conectan al registro `input_status[6:0]`, por lo que permiten comprobar el valor entregado por el periférico después de sincronización y debounce.

El comportamiento de `LED15` es:

```text
SW15 = 0 -> LED15 apagado -> reset aplicado
SW15 = 1 -> LED15 encendido -> Subsistema 2 habilitado
```

`LED14` se conecta a `init_done_q`. Su encendido indica que el top de prueba terminó de escribir los 300 tiles visibles de la VRAM y que el patrón gráfico de validación quedó completamente cargado.

## 5. Clock / PLL + Pixel Reset

El reloj principal del proyecto es de 100 MHz. El subsistema de video deriva un reloj nominal de 25 MHz mediante PLL para la lógica de píxeles.

El dominio de 100 MHz se utiliza para el puerto CPU de la memoria VGA y para el periférico de entradas. El dominio de 25 MHz se utiliza para los contadores VGA, la lectura de video y el renderer.

La liberación del reset del dominio de píxel se sincroniza con `clk_pixel_25` para evitar una salida de reset asíncrona respecto de la lógica VGA.

La adaptación física utilizada con `SW15` en el top de prueba no modifica este mecanismo. El reset entregado al Subsistema 2 continúa siendo una señal activa en alto y el dominio de píxel conserva su sincronización interna.

## 6. VGA Timing Controller

El controlador VGA trabaja con una resolución activa de 640 × 480 a 60 Hz.

Internamente contiene:

- contador horizontal;
- contador vertical;
- generación de `HSYNC`;
- generación de `VSYNC`;
- detección de región activa;
- generación de `pixel_x` y `pixel_y`.

La temporización utilizada es:

| Parámetro | Valor |
|---|---:|
| Resolución horizontal visible | 640 píxeles |
| Total horizontal | 800 píxeles |
| Inicio de `HSYNC` | 656 |
| Fin de `HSYNC` | 751 |
| Resolución vertical visible | 480 líneas |
| Total vertical | 525 líneas |
| Inicio de `VSYNC` | 490 |
| Fin de `VSYNC` | 491 |

Los sincronismos `HSYNC` y `VSYNC` son activos en bajo.

`active_video` indica si la coordenada actual pertenece al área visible de 640 × 480. Fuera de esta región, la salida RGB debe permanecer inactiva.

## 7. Video Memory Dual-Port

La memoria de video posee dos puertos independientes:

**Puerto A — CPU**

- dominio de 100 MHz;
- lectura y escritura;
- dato de 32 bits;
- índice local de 9 bits.

**Puerto B — VGA**

- dominio de `clk_pixel_25`;
- lectura síncrona;
- solo lectura;
- entrega `tile_word[31:0]` al renderer.

El rango local de 9 bits permite 512 índices. Los índices `0–299` representan tiles visibles. Los índices `300–511` están reservados; sus lecturas devuelven cero y sus escrituras se ignoran.

Cada tile se actualiza mediante una única escritura de 32 bits desde el CPU.

En el top independiente de prueba, la VRAM se inicializa automáticamente con un patrón conocido. El proceso recorre secuencialmente las direcciones `0–299`. Cuando se alcanza el último tile visible se activa:

```text
init_done_q = 1
```

y se detienen las escrituras de inicialización.

Durante la validación física este estado se observa mediante `LED14`.

## 8. Organización gráfica por tiles

La pantalla se divide en una matriz de:

- 20 columnas;
- 15 filas;
- tiles de 32 × 32 píxeles.

Por tanto:

```text
20 × 32 = 640
15 × 32 = 480
```

El índice de tile se calcula como:

```text
tile_index = fila * 20 + columna
```

y la dirección absoluta correspondiente vista por el CPU es:

```text
VGA_BASE + 4*(fila*20 + columna)
```

La distribución acordada de la pantalla es:

| Región | Ubicación |
|---|---|
| HUD / títulos | filas 0–3 |
| Tablero propio | columnas 1–8, filas 4–11 |
| Tablero rival | columnas 11–18, filas 4–11 |
| Mensajes | filas 12–14 |

## 9. Formato de palabra de video

Cada tile ocupa una palabra de 32 bits:

| Bits | Campo | Función |
|---:|---|---|
| `[2:0]` | `COLOR` | Selección del color del tile |
| `[3]` | `GLYPH_ENABLE` | Habilita dibujo de carácter/símbolo |
| `[11:4]` | `GLYPH/ASCII` | Código del carácter |
| `[31:12]` | Reservado | Debe permanecer en cero |

Codificación de color acordada:

| Código | Significado |
|---:|---|
| 0 | Fondo |
| 1 | Agua |
| 2 | Barco propio |
| 3 | Impacto |
| 4 | Fallo |
| 5 | Cursor |
| 6 | HUD / acento |
| 7 | Reservado |

El renderer soporta como mínimo espacio, `A–Z`, `0–9`, guion, dos puntos y punto. Los códigos no soportados se representan como espacio.

## 10. Tile / Glyph Renderer

El renderer recibe `pixel_x`, `pixel_y` y `active_video`.

La coordenada de píxel se transforma en:

```text
tile_col = pixel_x / 32
tile_row = pixel_y / 32
tile_index = tile_row*20 + tile_col
```

Como 32 es una potencia de dos, la selección de fila y columna puede implementarse usando los bits superiores de las coordenadas, sin requerir divisores generales.

El renderer solicita `tile_addr[8:0]` a la memoria de video y recibe `tile_word[31:0]`. A partir del campo `COLOR` y, cuando corresponde, de `GLYPH_ENABLE` y `GLYPH/ASCII`, genera la salida RGB correspondiente al píxel actual.

La lectura síncrona de la memoria introduce latencia; por lo tanto, las coordenadas y señales de video deben mantenerse alineadas con el dato de tile leído.

## 11. Periférico de entradas del Jugador 1

Las siete entradas físicas pasan por:

```text
entrada física
    ↓
sincronizador
    ↓
debouncer
    ↓
registro ESTADO
```

El registro `ESTADO`, ubicado en `0x00010120`, utiliza la siguiente codificación:

| Bit | Entrada |
|---:|---|
| 0 | UP |
| 1 | DOWN |
| 2 | LEFT |
| 3 | RIGHT |
| 4 | SEL |
| 5 | OK |
| 6 | GAME_RST |
| `[31:7]` | 0 |

Con la asignación física final, la correspondencia completa queda:

| Elemento físico | Señal lógica | Bit de `ESTADO` |
|---|---|---:|
| `BTNU` | `UP` | 0 |
| `BTND` | `DOWN` | 1 |
| `BTNL` | `LEFT` | 2 |
| `BTNR` | `RIGHT` | 3 |
| `SW0` | `SEL` | 4 |
| `SW1` | `OK` | 5 |
| `BTNC` | `GAME_RST` | 6 |

Las señales filtradas son niveles activos en alto. El hardware no implementa auto-repeat ni detección de flancos asociados a la lógica del juego; el software decide cuándo una transición representa una acción nueva.

La reasignación entre `BTNC` y `SW0` no modifica este registro porque el cambio se realiza antes de ingresar al periférico.

`GAME_RST` no corresponde al reset de hardware `rst_i`. Es una entrada del Jugador 1 que permite solicitar al programa el reinicio de la partida.

El reinicio mediante `GAME_RST` inicia una nueva partida y conserva el contador acumulado de victorias. El reset general del hardware es una señal independiente.

## 12. Dominios de reloj

El subsistema posee dos dominios:

| Dominio | Frecuencia | Bloques |
|---|---:|---|
| Sistema | 100 MHz | Puerto CPU de Video RAM, periférico de entradas |
| VGA | 25 MHz | Timing Controller, puerto VGA de Video RAM, Tile/Glyph Renderer |

La memoria dual-port constituye la frontera principal entre ambos dominios. Cada puerto opera con su propio reloj.

No se transmite lógica de control del juego entre dominios de reloj.

## 13. Estrategia de verificación

La verificación se divide en pruebas unitarias e integradas utilizando testbenches autoverificables.

| Testbench | Verificación principal |
|---|---|
| `tb_input_sync.sv` | Sincronización de entradas asíncronas |
| `tb_debounce.sv` | Rechazo de rebotes y aceptación de niveles estables |
| `tb_player1_inputs.sv` | Sincronización, debounce, niveles filtrados y empaquetado MMIO |
| `tb_pixel_clock.sv` | Generación del reloj de píxel |
| `tb_pixel_reset_sync.sv` | Liberación sincronizada del reset en el dominio VGA |
| `tb_vga_timing.sv` | Conteos H/V, región activa, periodicidad y polaridad de sincronismos |
| `tb_video_memory.sv` | Lecturas/escrituras CPU, lectura VGA, índices visibles/reservados y acceso simultáneo |
| `tb_tile_renderer.sv` | Conversión píxel→tile, colores, glyph enable y blanking |
| `tb_glyph_rom.sv` | Validación de los caracteres y símbolos implementados |
| `tb_subsystem2_vga_inputs.sv` | Integración interna de VGA y entradas del Subsistema 2 |
| `tb_subsystem2_peripheral.sv` | Validación de caja negra del Subsistema 2 desde sus interfaces externas |

Las pruebas del dominio VGA utilizan un reloj independiente de 25 MHz, mientras que el puerto CPU y las entradas utilizan 100 MHz. La simulación comprueba que ambos dominios operan simultáneamente sin depender de una relación de fase específica.

La prueba `tb_subsystem2_peripheral.sv` constituye la validación integrada principal del Subsistema 2, ya que comprueba su comportamiento desde las interfaces externas sin depender de señales internas.

## 14. Validación física del Subsistema 2

Para la validación física independiente se utiliza:

```text
src/design/top/subsystem2_basys3_test_top.sv
```

junto con:

```text
src/constraints/subsystem2_basys3_test.xdc
```

El top de prueba genera un patrón gráfico conocido y escribe secuencialmente los 300 tiles visibles de la VRAM.

La asignación física utilizada es:

```text
BTNU -> UP
BTND -> DOWN
BTNL -> LEFT
BTNR -> RIGHT
SW0  -> SEL
SW1  -> OK
BTNC -> GAME_RST
```

El control de habilitación y reset se realiza con `SW15`:

```text
SW15 = 0 -> reset aplicado
SW15 = 1 -> Subsistema 2 habilitado
```

La indicación mediante LEDs es:

```text
LED0  -> UP
LED1  -> DOWN
LED2  -> LEFT
LED3  -> RIGHT
LED4  -> SEL
LED5  -> OK
LED6  -> GAME_RST
LED14 -> init_done_q
LED15 -> RUN
```

El comportamiento esperado durante el encendido es:

```text
SW15 = 0
    LED15 = 0
    Subsistema 2 en reset

SW15 = 1
    LED15 = 1
    Subsistema 2 habilitado
    comienza la inicialización de VRAM

Inicialización completa
    init_done_q = 1
    LED14 = 1
```

Durante la validación física, `LED0–LED6` permiten comprobar que las siete entradas son observadas correctamente después de sincronización y debounce.

La salida VGA se valida conectando físicamente un monitor al conector VGA de la Basys 3 y observando el patrón de prueba generado por el top independiente.

## 15. Límites de responsabilidad

El Subsistema 2:

- no valida colocaciones de barcos;
- no decide turnos;
- no decide si un disparo es impacto o fallo;
- no detecta hundimientos;
- no determina victoria;
- no modifica contadores de partidas;
- no implementa reglas del juego;
- no oculta por sí mismo información del rival.

El programa RISC-V escribe en la memoria VGA únicamente la representación visual permitida y procesa las entradas del Jugador 1.

El uso de `GAME_RST` como entrada física tampoco implementa el reinicio de la partida dentro del Subsistema 2. El periférico únicamente entrega el estado de la señal al CPU y es el software RISC-V quien decide la acción correspondiente.

## 16. Ubicación en el repositorio

```text
Proyecto3_Batalla_Naval/
├── docs/
│   └── diseno/
│       ├── nivel_3_vga_entradas.md
│       └── img/
│           └── vga_entradas/
│               └── nivel_3_vga_entradas.svg
│
└── src/
    ├── constraints/
    │   └── subsystem2_basys3_test.xdc
    │
    ├── design/
    │   ├── inputs/
    │   ├── vga/
    │   └── top/
    │       └── subsystem2_basys3_test_top.sv
    │
    └── testbench/
        ├── inputs/
        ├── vga/
        └── integration/
            ├── tb_subsystem2_vga_inputs.sv
            └── tb_subsystem2_peripheral.sv
```

[Segundo nivel: arquitectura e interconexiones](nivel_2.md) · [Índice del diseño](README.md)