# Cuarto nivel — VGA y entradas del Jugador 1

## Objetivo

Descomponer el Subsistema 2 en bloques internos suficientemente definidos para implementar y verificar en SystemVerilog la generación VGA, la memoria de video, el renderizado basado en tiles y el periférico de entradas físicas del Jugador 1.

Este nivel mantiene la separación arquitectónica del proyecto: el hardware del Subsistema 2 únicamente presenta información y captura entradas. Las reglas de Batalla Naval, incluyendo colocación, validación de disparos, turnos, impactos, hundimientos, victoria y reinicio de partida, permanecen en el programa ensamblador ejecutado por el procesador RISC-V.

Además de describir los bloques internos, este documento define la frontera externa de `subsystem2_vga_inputs` como un periférico completo. La verificación principal se realiza sobre esa frontera mediante un testbench autoverificable de tipo black-box.

---

## Diagrama del subsistema

![Diagrama de cuarto nivel del Subsistema 2](img/vga_entradas/nivel_4_vga_entradas.svg)

**Figura 1. Cuarto nivel del Subsistema 2: VGA y entradas del Jugador 1.**

Las conexiones continuas representan rutas funcionales de datos y control. Las conexiones discontinuas representan distribución de reloj y reset entre los dominios de 100 MHz y 25 MHz.

Los bloques descritos en este nivel se encapsulan dentro de `subsystem2_vga_inputs`, cuya interfaz externa constituye la frontera utilizada por el bus del sistema, las entradas del Jugador 1 y la salida VGA.

---

## Descomposición de cuarto nivel

| Bloque de tercer nivel | Bloques internos de cuarto nivel |
|---|---|
| 2.1 Clock / PLL + Pixel Reset | PLL, Clocking Wizard y sincronización del reset de píxel |
| 2.2 VGA Timing Controller | contadores horizontal/vertical, decodificación de sincronismos internos, video activo y alineación de sincronismos físicos |
| 2.3 Video Memory Dual-Port | puerto CPU, memoria de video, puerto VGA y protección de región reservada |
| 2.4 Tile / Glyph Renderer | mapeo píxel→tile, decodificador de palabra, Glyph ROM, selección RGB y pipeline |
| 2.5 Player 1 Input Peripheral | sincronización de entradas, debouncing, empaquetado de estado y lectura MMIO |
| 2.6 Integración del periférico | encapsulado `subsystem2_vga_inputs`, interfaces externas y verificación black-box |

---

# 2.1 Clock / PLL + Pixel Reset

## 2.1.1 PLL / Clocking Wizard

Recibe el reloj principal de la Basys 3 y genera el reloj utilizado por el dominio VGA.

**Entradas**

| Señal | Ancho | Descripción |
|---|---:|---|
| `clk_100_i` | 1 | reloj principal de 100 MHz |
| `rst_i` | 1 | reset general del sistema |

**Salidas**

| Señal | Ancho | Descripción |
|---|---:|---|
| `clk_pixel` | 1 | reloj de píxel de 25 MHz |
| `pixel_clock_locked` | 1 | indica que el MMCM alcanzó una condición estable |

La única fuente externa de reloj del sistema es `clk_100_i`. El reloj de 25 MHz se deriva internamente mediante el Clocking Wizard/MMCM.

La configuración utilizada para implementación física recibe 100 MHz y genera 25 MHz. La fuente primaria del Clocking Wizard se configuró como `No buffer`, evitando redefinir internamente el reloj primario que ya se encuentra restringido en el XDC superior.

---

## 2.1.2 Pixel Reset Synchronizer

Genera el reset utilizado por los bloques que trabajan en el dominio `clk_pixel`.

**Entradas**

| Señal | Ancho | Descripción |
|---|---:|---|
| `clk_pixel_i` | 1 | reloj del dominio de píxel |
| `rst_i` | 1 | reset general |
| `locked_i` | 1 | estado del MMCM |

**Salida**

| Señal | Ancho | Descripción |
|---|---:|---|
| `rst_pixel_o` | 1 | reset sincronizado para el dominio VGA |

El dominio VGA permanece en reset mientras el MMCM no se encuentre bloqueado. La liberación de `rst_pixel_o` se sincroniza con el reloj de píxel para evitar una desactivación asíncrona del reset dentro de la lógica de video.

---

# 2.2 VGA Timing Controller

El controlador de temporización produce las coordenadas del píxel actual, la indicación de región visible y los sincronismos necesarios para una salida de **640 × 480 a 60 Hz nominales** utilizando el reloj de píxel de 25 MHz acordado para el proyecto.

La temporización utilizada es:

```text
Horizontal total = 800 píxeles
Visible           = 0 ... 639
HSYNC bajo        = 656 ... 751

Vertical total    = 525 líneas
Visible           = 0 ... 479
VSYNC bajo        = 490 ... 491
```

---

## 2.2.1 Contadores horizontal y vertical

Los contadores recorren la temporización completa del cuadro VGA.

**Entradas**

| Señal | Ancho | Descripción |
|---|---:|---|
| `clk_pixel_i` | 1 | reloj de píxel |
| `rst_pixel_i` | 1 | reset del dominio VGA |

**Salidas**

| Señal | Descripción |
|---|---|
| `pixel_x_o` | coordenada horizontal asociada al píxel actual |
| `pixel_y_o` | coordenada vertical asociada al píxel actual |
| `line_end_o` | indica fin del periodo horizontal |

El contador horizontal recorre `0–799`. Al finalizar una línea, el contador vertical avanza y recorre `0–524`. El último punto del cuadro es `(799,524)` y posteriormente se retorna a `(0,0)`.

---

## 2.2.2 Sync / Active Decoder

Decodifica los contadores para identificar la región visible y generar los sincronismos internos.

**Salidas**

| Señal | Ancho | Descripción |
|---|---:|---|
| `active_video_o` | 1 | indica que el píxel pertenece al área visible |
| `vga_hsync_o` interno | 1 | sincronismo horizontal sin la compensación final |
| `vga_vsync_o` interno | 1 | sincronismo vertical sin la compensación final |
| `pixel_x_o` | 10 | coordenada entregada al renderer |
| `pixel_y_o` | 10 | coordenada entregada al renderer |

En `subsystem2_vga_inputs`, los sincronismos generados por `vga_timing` se reciben como `hsync_raw` y `vsync_raw`.

Las coordenadas y `active_video` se entregan al renderer. Los sincronismos internos no se conectan directamente a la salida física, porque la lectura síncrona de la memoria de video y el pipeline de renderizado introducen una latencia de un ciclo de reloj de píxel.

---

## 2.2.3 Alineación de sincronismos de salida

En el nivel de integración, `hsync_raw` y `vsync_raw` se registran durante un ciclo de `clk_pixel` antes de entregarse como salidas del periférico.

**Entradas**

| Señal | Ancho | Descripción |
|---|---:|---|
| `clk_pixel` | 1 | reloj del dominio VGA |
| `rst_pixel` | 1 | reset del dominio VGA |
| `hsync_raw` | 1 | sincronismo horizontal generado por `vga_timing` |
| `vsync_raw` | 1 | sincronismo vertical generado por `vga_timing` |

**Salidas**

| Señal | Ancho | Descripción |
|---|---:|---|
| `vga_hsync_o` | 1 | sincronismo horizontal alineado |
| `vga_vsync_o` | 1 | sincronismo vertical alineado |

Este registro de un ciclo compensa la latencia del camino VRAM→renderer. De esta forma, `vga_hsync_o`, `vga_vsync_o` y `vga_rgb_o` corresponden temporalmente al mismo píxel.

La prueba black-box del periférico midió directamente sobre las salidas externas:

| Comprobación | Resultado |
|---|---:|
| ancho bajo de `HSYNC` | 3840 ns |
| período de línea de `HSYNC` | 32000 ns |
| ancho bajo de `VSYNC` | 64000 ns |

---

# 2.3 Video Memory Dual-Port

La memoria de video se implementa como una memoria de doble puerto lógico de **512 palabras × 32 bits**.

## Organización

- Índices `0–299`: tiles visibles.
- Índices `300–511`: región reservada.
- Puerto A: CPU, dominio de 100 MHz.
- Puerto B: VGA, dominio de 25 MHz.

---

## 2.3.1 Puerto A — CPU

Permite al procesador actualizar o consultar una posición de la memoria de video.

**Entradas**

| Señal | Ancho | Descripción |
|---|---:|---|
| `clk_100_i` | 1 | reloj del sistema |
| `rst_i` | 1 | reset del sistema |
| `vga_write_enable_i` | 1 | habilitación de escritura |
| `vga_addr_i` | 9 | índice local de memoria VGA |
| `vga_wdata_i` | 32 | palabra a escribir |

**Salida**

| Señal | Ancho | Descripción |
|---|---:|---|
| `vga_rdata_o` | 32 | palabra leída por el CPU |

La lectura y escritura del puerto CPU son síncronas.

Las escrituras dirigidas a índices `300–511` se ignoran y las lecturas de esa región retornan cero.

---

## 2.3.2 Memoria de video

La memoria contiene el mapa de tiles empleado por la interfaz gráfica.

El bus del sistema convierte la dirección absoluta del CPU en un índice local:

```text
tile_index = (DataAddress - VGA_BASE) >> 2
```

con:

```text
VGA_BASE = 0x00011000
```

La región VGA del mapa de memoria es:

```text
0x00011000 – 0x000117FF
```

Los índices `0–299` corresponden a las posiciones visibles de la pantalla. Los índices `300–511` permanecen reservados.

El formato de cada palabra es:

| Bits | Campo | Descripción |
|---:|---|---|
| `[2:0]` | `COLOR` | color base del tile |
| `[3]` | `GLYPH_ENABLE` | habilita representación de glyph |
| `[11:4]` | `ASCII/GLYPH` | carácter almacenado |
| `[31:12]` | reservado | se mantiene en cero |

---

## 2.3.3 Puerto B — VGA

Proporciona al renderer la palabra correspondiente al tile visible en el píxel actual.

**Entradas**

| Señal | Ancho | Descripción |
|---|---:|---|
| `clk_pixel_i` | 1 | reloj de píxel |
| `tile_addr_i` | 9 | índice solicitado por el renderer |

**Salida**

| Señal | Ancho | Descripción |
|---|---:|---|
| `tile_word_o` | 32 | palabra del tile leído |

La lectura es síncrona e introduce una latencia de un ciclo de reloj de píxel. Por esta razón, el renderer registra las señales necesarias para mantener la correspondencia entre coordenadas y dato leído.

---

## 2.3.4 Acceso simultáneo CPU / VGA

Los dos puertos permiten que el CPU y la lógica VGA operen simultáneamente con relojes diferentes.

Para direcciones distintas, ambos accesos son independientes:

```text
CPU: lectura/escritura a 100 MHz
VGA: lectura a 25 MHz
```

El diseño no establece como contrato funcional un valor determinista para una colisión exacta en la que el CPU escriba una dirección mientras el puerto VGA lee esa misma dirección en el mismo instante.

Por esta razón:

- el software puede actualizar VRAM mientras el renderer continúa operando;
- el software no debe depender del valor transitorio observado por VGA durante el ciclo exacto de una escritura sobre la misma posición;
- una actualización posterior será visible normalmente en los siguientes accesos del puerto VGA.

Esta decisión evita trasladar reglas del juego o mecanismos de sincronización de alto nivel al periférico de video.

---

# 2.4 Tile / Glyph Renderer

El renderer transforma la posición del píxel y la palabra almacenada en memoria en el color enviado al monitor.

---

## 2.4.1 Pixel → Tile Mapper

La pantalla se divide en:

```text
20 columnas × 15 filas
```

con tiles de:

```text
32 × 32 píxeles
```

por lo que:

```text
20 × 32 = 640
15 × 32 = 480
```

Para cada píxel visible:

```text
columna = pixel_x >> 5
fila    = pixel_y >> 5
tile_index = fila*20 + columna
```

**Entradas**

| Señal | Descripción |
|---|---|
| `pixel_x` | coordenada horizontal |
| `pixel_y` | coordenada vertical |
| `active_video` | habilitación de región visible |

**Salidas**

| Señal | Ancho | Descripción |
|---|---:|---|
| `tile_addr` | 9 | dirección del tile solicitado |
| posición interna | — | posición del píxel dentro del tile |

---

## 2.4.2 Tile Word Decoder

Interpreta la palabra de 32 bits almacenada en la memoria VGA.

| Bits | Campo |
|---|---|
| `[2:0]` | `COLOR` |
| `[3]` | `GLYPH_ENABLE` |
| `[11:4]` | `ASCII/GLYPH` |
| `[31:12]` | reservado, escrito como cero |

Codificación de color acordada:

| Código | Uso | RGB |
|---:|---|---|
| 0 | fondo | `12'h000` |
| 1 | agua | `12'h04F` |
| 2 | barco propio | `12'h888` |
| 3 | impacto | `12'hF00` |
| 4 | fallo | `12'hFFF` |
| 5 | cursor | `12'hFF0` |
| 6 | HUD / acento | `12'h0F8` |
| 7 | reservado | `12'h000` |

---

## 2.4.3 Glyph ROM

Genera el bit gráfico correspondiente al carácter seleccionado cuando `GLYPH_ENABLE = 1`.

El conjunto mínimo soportado es:

- espacio;
- `A–Z`;
- `0–9`;
- guion;
- dos puntos;
- punto.

Un código no soportado se representa como espacio.

La fuente lógica se representa sobre una matriz de 8 × 8 y se escala dentro del tile de 32 × 32 utilizando bloques de 4 × 4 píxeles físicos por cada píxel lógico del glyph.

---

## 2.4.4 RGB Mux / Pipeline

Selecciona entre el color base del tile y el píxel del glyph, respetando `active_video`.

La lógica de pipeline conserva la correspondencia entre:

```text
coordenadas de video
        +
palabra leída de VRAM
        +
información de glyph
        ↓
salida RGB
```

La lectura síncrona del puerto VGA obliga a registrar coordenadas y control durante un ciclo de `clk_pixel`.

La misma compensación temporal se aplica a `HSYNC` y `VSYNC`: ambos se retrasan un ciclo de reloj de píxel para mantenerse alineados con la salida RGB producida por el renderer.

**Salida**

| Señal | Ancho | Descripción |
|---|---:|---|
| `vga_rgb_o` | 12 | RGB de 4 bits por componente |

Durante la región no visible, la salida RGB se fuerza a negro.

---

# 2.5 Player 1 Input Peripheral

Este periférico captura los controles físicos del Jugador 1 y entrega al CPU únicamente señales sincronizadas y filtradas.

Las señales lógicas del periférico son:

```text
UP
DOWN
LEFT
RIGHT
SEL
OK
GAME_RST
```

La asignación física utilizada en Basys 3 es:

| Control físico | Función lógica |
|---|---|
| `BTNU` | `UP` |
| `BTND` | `DOWN` |
| `BTNL` | `LEFT` |
| `BTNR` | `RIGHT` |
| `BTNC` | `SEL` |
| `SW1` | `OK` |
| `SW0` | `GAME_RST` |
| `SW15` | reset general del hardware |

La asignación física no modifica el formato MMIO del registro de entradas.

---

## 2.5.1 Synchronizers ×7

Cada señal física atraviesa un sincronizador de dos flip-flops para ingresar al dominio de `clk_100_i`.

**Entradas**

- siete controles físicos;
- `clk_100_i`;
- `rst_i`.

**Salida**

```text
sync_levels[6:0]
```

La primera etapa puede quedar temporalmente expuesta a metastabilidad. La segunda etapa reduce fuertemente la probabilidad de que esa condición se propague al resto del diseño.

La sincronización resuelve el problema de cruce de dominio de las entradas asíncronas; no elimina el rebote mecánico.

---

## 2.5.2 Debouncers ×7

Cada entrada sincronizada se filtra de forma independiente para eliminar rebotes mecánicos.

**Salida**

```text
clean_levels[6:0]
```

En hardware se utiliza:

```text
DEBOUNCE_CYCLES = 1_000_000
```

Con un reloj de 100 MHz, este valor representa aproximadamente 10 ms de estabilidad antes de aceptar un nuevo nivel.

Las señales filtradas son niveles activos en alto. El hardware no implementa auto-repeat; la detección de cambios o flancos necesarios para la interacción del juego corresponde al software.

---

## 2.5.3 Status Packer

Empaqueta los siete controles en el registro de estado:

| Bit | Entrada |
|---:|---|
| 0 | `UP` |
| 1 | `DOWN` |
| 2 | `LEFT` |
| 3 | `RIGHT` |
| 4 | `SEL` |
| 5 | `OK` |
| 6 | `GAME_RST` |
| `[31:7]` | cero |

`GAME_RST` no corresponde al reset físico del FPGA. Es una entrada que el software interpreta como solicitud de reinicio de partida.

El reset general del hardware permanece separado y en la prueba física se encuentra asociado a `SW15`.

---

## 2.5.4 MMIO Read Interface

El registro de entradas está mapeado en:

```text
0x00010120
```

**Interfaz**

| Señal | Ancho | Dirección |
|---|---:|---|
| `input_write_enable_i` | 1 | Bus → periférico |
| `input_addr_i` | 2 | Bus → periférico |
| `input_wdata_i` | 32 | Bus → periférico |
| `input_rdata_o` | 32 | periférico → Bus/CPU |

La dirección local válida es:

```text
input_addr_i = 2'b00
```

Las direcciones locales `01`, `10` y `11` retornan cero.

Las escrituras se ignoran. `input_write_enable_i` e `input_wdata_i` se conservan para mantener una interfaz estándar con el bus, pero no modifican el estado de las entradas.

---

# 2.6 Integración como periférico completo

El módulo:

```text
subsystem2_vga_inputs
```

encapsula las funciones VGA y de entradas del Jugador 1 y constituye la frontera principal del Subsistema 2 para integración y verificación.

## 2.6.1 Entradas externas

| Señal | Ancho | Función |
|---|---:|---|
| `clk_100_i` | 1 | reloj principal de 100 MHz |
| `rst_i` | 1 | reset general |
| `up_i` | 1 | entrada UP |
| `down_i` | 1 | entrada DOWN |
| `left_i` | 1 | entrada LEFT |
| `right_i` | 1 | entrada RIGHT |
| `sel_i` | 1 | entrada SEL |
| `ok_i` | 1 | entrada OK |
| `game_rst_i` | 1 | solicitud de reinicio de partida |
| `input_write_enable_i` | 1 | escritura estándar del periférico de entradas |
| `input_addr_i` | 2 | dirección local del periférico de entradas |
| `input_wdata_i` | 32 | dato de escritura estándar |
| `vga_write_enable_i` | 1 | habilitación de escritura VGA |
| `vga_addr_i` | 9 | índice local de VRAM |
| `vga_wdata_i` | 32 | palabra VGA escrita por CPU |

## 2.6.2 Salidas externas

| Señal | Ancho | Función |
|---|---:|---|
| `input_rdata_o` | 32 | estado filtrado de controles |
| `vga_rdata_o` | 32 | dato leído desde VRAM |
| `vga_hsync_o` | 1 | sincronismo horizontal VGA |
| `vga_vsync_o` | 1 | sincronismo vertical VGA |
| `vga_rgb_o` | 12 | información RGB |

Desde el punto de vista del sistema, el Subsistema 2 puede tratarse como una caja negra con estas entradas y salidas. Los bloques internos se conservan para modularidad, implementación y depuración, pero no forman parte del contrato externo con el resto del proyecto.

---

# Dominios de reloj

| Dominio | Frecuencia | Bloques |
|---|---:|---|
| Sistema | 100 MHz | puerto CPU de VRAM, sincronizadores, debouncers, empaquetado y MMIO de entradas |
| VGA | 25 MHz | VGA Timing Controller, puerto VGA de VRAM, Tile/Glyph Renderer y registros de alineación de `HSYNC`/`VSYNC` |

No se utiliza el reloj de píxel como reloj de entrada externo. Se deriva internamente del reloj principal de 100 MHz.

La memoria dual-port constituye la frontera principal de datos entre ambos dominios.

---

# Límites de responsabilidad

El Subsistema 2:

## Sí realiza

- generación del reloj de píxel;
- reset sincronizado del dominio VGA;
- temporización VGA;
- alineación temporal de `HSYNC` y `VSYNC` con RGB;
- almacenamiento y lectura del mapa de tiles;
- protección de la región VGA reservada;
- conversión de tiles/glyphs a RGB;
- sincronización de las entradas físicas;
- debounce de entradas;
- empaquetado del estado de controles;
- exposición MMIO de controles;
- interfaz MMIO de memoria VGA.

## No realiza

- colocación o validación de barcos;
- control de turnos;
- validación de disparos;
- detección de impacto, hundimiento o victoria;
- reglas de reinicio de partida;
- auto-repeat de botones;
- lógica del Jugador 2;
- reglas del juego en hardware.

Todas esas decisiones corresponden al programa RISC-V o a los demás subsistemas definidos por la arquitectura del proyecto.

---

# Verificación implementada

La estrategia de verificación se divide en dos niveles:

1. pruebas unitarias e integradas de los bloques internos, utilizadas durante el desarrollo;
2. prueba final de aceptación del periférico completo mediante una metodología black-box.

Las pruebas unitarias se conservan como evidencia de desarrollo, pero la evidencia principal para revisión del Subsistema 2 es `tb_subsystem2_peripheral.sv`.

---

## Pruebas unitarias de respaldo

Los siguientes bloques poseen testbenches autoverificables:

| Bloque | Testbench |
|---|---|
| sincronizador de entradas | `tb_input_sync.sv` |
| debounce | `tb_debounce.sv` |
| periférico de entradas | `tb_player1_inputs.sv` |
| reloj de píxel | `tb_pixel_clock.sv` |
| reset de píxel | `tb_pixel_reset_sync.sv` |
| temporización VGA | `tb_vga_timing.sv` |
| memoria de video | `tb_video_memory.sv` |
| Glyph ROM | `tb_glyph_rom.sv` |
| renderer | `tb_tile_renderer.sv` |
| integración inicial | `tb_subsystem2_vga_inputs.sv` |

Estas pruebas permiten aislar fallos durante el desarrollo, pero no constituyen la única evidencia de funcionamiento del periférico.

---

## Prueba black-box del periférico completo

El testbench:

```text
src/testbench/integration/tb_subsystem2_peripheral.sv
```

instancia únicamente la interfaz externa de `subsystem2_vga_inputs`.

El testbench:

- aplica estímulos a las entradas externas;
- realiza transacciones sobre las interfaces MMIO;
- observa únicamente las salidas externas del periférico;
- no depende de señales internas ni jerarquías del DUT para decidir PASS/FAIL;
- mantiene un contador de comprobaciones y errores;
- produce un resultado global automático.

### Cobertura funcional

La prueba verifica:

- reset general;
- `UP` → bit 0;
- `DOWN` → bit 1;
- `LEFT` → bit 2;
- `RIGHT` → bit 3;
- `SEL` → bit 4;
- `OK` → bit 5;
- `GAME_RST` → bit 6;
- las siete entradas simultáneas → `0x0000007F`;
- escrituras MMIO al periférico de entradas ignoradas;
- direcciones locales `01`, `10` y `11` retornando cero;
- liberación de controles y retorno a cero;
- escritura/lectura del tile 0;
- escritura/lectura del tile 299;
- escritura ignorada y lectura cero del tile reservado 300;
- propagación de color de agua desde MMIO/VRAM hasta `vga_rgb_o`;
- blanking horizontal forzando RGB negro;
- temporización externa de `HSYNC`;
- propagación de color de cursor hasta `vga_rgb_o`;
- representación de un glyph ASCII `A`;
- temporización externa de `VSYNC`;
- reset final de las salidas MMIO.

### Resultado obtenido

```text
SUBSYSTEM 2 PERIPHERAL TEST SUMMARY
Checks : 27
Errors : 0
RESULT : TEST PASSED
```

La temporización medida directamente en las salidas externas fue:

| Comprobación | Resultado |
|---|---:|
| ancho bajo de `HSYNC` | 3840 ns |
| período de línea de `HSYNC` | 32000 ns |
| ancho bajo de `VSYNC` | 64000 ns |

El resultado de 27 comprobaciones con cero errores constituye la evidencia principal de aceptación funcional del Subsistema 2 como periférico.

---

# Validación física

Para prueba independiente en Basys 3 se utiliza:

```text
src/design/top/subsystem2_basys3_test_top.sv
```

junto con:

```text
src/constraints/subsystem2_basys3_test.xdc
```

La prueba física permite observar:

- entradas filtradas en `LED0–LED6`;
- finalización de la inicialización de VRAM mediante `LED15`;
- reset general mediante `SW15`.

La asignación vigente es:

| Control | Indicador |
|---|---|
| `BTNU / UP` | `LED0` |
| `BTND / DOWN` | `LED1` |
| `BTNL / LEFT` | `LED2` |
| `BTNR / RIGHT` | `LED3` |
| `BTNC / SEL` | `LED4` |
| `SW1 / OK` | `LED5` |
| `SW0 / GAME_RST` | `LED6` |
| VRAM inicializada | `LED15` |

Las entradas, el reset general y la inicialización de VRAM fueron comprobados físicamente en Basys 3.

La visualización mediante un monitor VGA permanece como prueba física separada. Mientras no se realice esa prueba, no se declara validación visual física del monitor únicamente a partir de la simulación.

---

# Archivos RTL implementados

```text
src/design/vga/
├── pixel_clock.sv
├── pixel_reset_sync.sv
├── vga_timing.sv
├── video_memory.sv
├── tile_renderer.sv
├── glyph_rom.sv
└── subsystem2_vga_inputs.sv

src/design/vga/ip/
└── pixel_clock_wiz.xci

src/design/inputs/
├── input_sync.sv
├── debounce.sv
└── player1_inputs.sv

src/design/top/
└── subsystem2_basys3_test_top.sv
```

---

# Testbenches implementados

```text
src/testbench/inputs/
├── tb_input_sync.sv
├── tb_debounce.sv
└── tb_player1_inputs.sv

src/testbench/vga/
├── tb_pixel_clock.sv
├── tb_pixel_reset_sync.sv
├── tb_vga_timing.sv
├── tb_video_memory.sv
├── tb_glyph_rom.sv
└── tb_tile_renderer.sv

src/testbench/integration/
├── tb_subsystem2_vga_inputs.sv
└── tb_subsystem2_peripheral.sv
```

---

# Restricciones e integración física

El top físico utiliza el FPGA:

```text
xc7a35tcpg236-1
```

La restricción de reloj principal corresponde a 100 MHz.

Las señales utilizadas por la prueba física se restringen a `LVCMOS33`.

El reloj de píxel se genera internamente mediante el Clocking Wizard; no se utiliza una segunda entrada de reloj externa para VGA.

---

# Estado de verificación del Subsistema 2

| Elemento | Estado |
|---|:---:|
| sincronización de entradas | ✅ |
| debounce | ✅ |
| empaquetado MMIO | ✅ |
| interfaz completa de entradas | ✅ |
| memoria VGA visible 0–299 | ✅ |
| protección 300–511 | ✅ |
| renderer de colores | ✅ |
| Glyph ROM | ✅ |
| blanking | ✅ |
| Clocking Wizard 100→25 MHz | ✅ |
| reset de dominio de píxel | ✅ |
| HSYNC | ✅ |
| VSYNC | ✅ |
| alineación RGB/sincronismos | ✅ |
| prueba black-box del periférico | ✅ 27/27 |
| síntesis e implementación | ✅ |
| entradas físicas en Basys 3 | ✅ |
| visualización física mediante monitor VGA | pendiente |

---

# Referencias internas

- [Diseño de tercer nivel — VGA y entradas](nivel_3_vga_entradas.md)
- [Segundo nivel: arquitectura e interconexiones](nivel_2.md)
- [Índice del diseño](README.md)
- [Informe de verificación del Subsistema 2](../informe/vga_entradas_verificacion.md)
- `src/design/vga/subsystem2_vga_inputs.sv`
- `src/testbench/integration/tb_subsystem2_peripheral.sv`
- `src/design/top/subsystem2_basys3_test_top.sv`
- `src/constraints/subsystem2_basys3_test.xdc`
