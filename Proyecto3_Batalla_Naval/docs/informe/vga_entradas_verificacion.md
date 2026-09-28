# Informe de verificación — Subsistema 2: VGA y entradas del Jugador 1

## 1. Objetivo

Documentar la verificación funcional del Subsistema 2 del Proyecto 3 — Batalla Naval. Este subsistema concentra dos funciones de hardware independientes pero integradas dentro de la interfaz local del Jugador 1:

1. generación y presentación de video VGA mediante memoria de tiles, glyphs y temporización 640×480;
2. captura, sincronización, filtrado y lectura MMIO de las entradas físicas del Jugador 1.

La lógica de Batalla Naval no se implementa en este subsistema. Las reglas de colocación, disparos, impactos, turnos, hundimientos y victoria pertenecen al programa ejecutado por el procesador RISC-V.

La estrategia de verificación se dividió en pruebas unitarias autoverificables, una prueba de integración completa, síntesis e implementación en Vivado y una validación física parcial sobre Basys 3.

---

## 2. Arquitectura verificada

El Subsistema 2 utiliza dos dominios de reloj:

| Dominio | Frecuencia | Elementos principales |
|---|---:|---|
| Sistema | 100 MHz | puerto CPU de VRAM, sincronizadores, debouncers y MMIO de entradas |
| Píxel | 25 MHz | temporización VGA, puerto VGA de VRAM y renderer |

El reloj de 25 MHz se deriva del reloj de 100 MHz mediante Clocking Wizard/MMCM. La memoria de video es dual-port: el CPU puede escribir y leer a 100 MHz mientras el renderer realiza lecturas a 25 MHz.

La pantalla visible se divide en 20 columnas × 15 filas de tiles de 32×32 píxeles, para 300 tiles visibles. La VRAM reserva 512 posiciones de 32 bits; los índices 0–299 son visibles y 300–511 permanecen reservados.

La palabra de cada tile utiliza:

| Bits | Campo |
|---:|---|
| `[2:0]` | color base |
| `[3]` | `GLYPH_ENABLE` |
| `[11:4]` | ASCII/glyph |
| `[31:12]` | reservado, cero |

El periférico de entradas entrega el registro:

| Bit | Entrada |
|---:|---|
| 0 | UP |
| 1 | DOWN |
| 2 | LEFT |
| 3 | RIGHT |
| 4 | SEL |
| 5 | OK |
| 6 | GAME_RST |
| 31:7 | cero |

Cada entrada física atraviesa primero un sincronizador de dos flip-flops y después un filtro de debounce.

---

## 3. Metodología de verificación

Los testbenches se diseñaron como pruebas autoverificables. Cada uno mantiene un contador de errores y genera mensajes `PASS`/`FAIL`; al finalizar se espera `TEST PASSED` y `errors = 0`.

Para reducir el tiempo de simulación, los testbenches de debounce utilizan un número pequeño de ciclos, conservando exactamente el comportamiento lógico que tendrá el filtro con el parámetro de hardware.

### Resumen de ejecuciones

| Testbench | Bloque | Tiempo final observado | Resultado |
|---|---|---:|---|
| `tb_input_sync.sv` | sincronización de entrada | 56 ns | PASS |
| `tb_debounce.sv` | debounce | 156 ns | PASS |
| `tb_player1_inputs.sv` | periférico completo de entradas | 936 ns | PASS |
| `tb_pixel_clock.sv` | 100 MHz → 25 MHz / MMCM | 1540 ns | PASS |
| `tb_pixel_reset_sync.sv` | reset de dominio de píxel | 229 ns | PASS |
| `tb_vga_timing.sv` | temporización 640×480 | 16.800061 ms | PASS |
| `tb_video_memory.sv` | VRAM dual-port | 461 ns | PASS |
| `tb_glyph_rom.sv` | ROM de glyphs | 2635 ns | PASS |
| `tb_tile_renderer.sv` | renderer tile/glyph | 1061 ns | PASS |
| `tb_subsystem2_vga_inputs.sv` | integración completa S2 | 159.496 µs | PASS |

---

## 4. Verificación de entradas del Jugador 1

### 4.1 `input_sync`

#### Función

`input_sync` introduce una señal asíncrona al dominio de 100 MHz mediante dos etapas de flip-flops. El objetivo es evitar utilizar directamente una entrada física dentro de la lógica síncrona y reducir el riesgo asociado a metastabilidad.

#### Qué verifica el testbench

`tb_input_sync.sv` comprueba:

- reset de la salida a cero;
- una transición asíncrona 0→1;
- que la salida no cambie prematuramente después de la primera etapa;
- propagación correcta después de la segunda etapa;
- transición 1→0 con la misma latencia.

![Waveform de input_sync](resultados/vga_entradas/01_tb_input_sync_waveform.png)

**Figura 1.** La salida `sync_o` sigue a `async_i` únicamente después de atravesar las dos etapas de sincronización. El contador de errores permanece en cero.

La waveform confirma que el cambio de la entrada no se refleja de forma combinacional en la salida. Esto es importante porque los botones y switches de la Basys 3 no están sincronizados con `clk_i`.

---

### 4.2 `debounce`

#### Función

`debounce` acepta un nuevo estado únicamente cuando la entrada sincronizada permanece diferente del valor filtrado durante `DEBOUNCE_CYCLES` ciclos consecutivos.

#### Qué verifica el testbench

Para acelerar la simulación se utiliza `TEST_CYCLES = 4`. Se comprueba:

- reset a cero;
- pulso alto corto rechazado;
- nivel alto estable aceptado;
- pulso bajo corto rechazado;
- nivel bajo estable aceptado.

![Waveform de debounce](resultados/vga_entradas/02_tb_debounce_waveform.png)

**Figura 2.** Los pulsos breves de `sync_i` no modifican `clean_o`. El cambio se acepta únicamente después de que el nuevo nivel permanece estable durante la cantidad requerida de ciclos.

El resultado demuestra que el periférico no interpreta directamente los rebotes mecánicos como múltiples cambios de estado.

---

### 4.3 `player1_inputs`

#### Función

`player1_inputs` integra siete cadenas idénticas:

```text
entrada física → input_sync → debounce → clean_levels → registro MMIO
```

#### Qué verifica el testbench

`tb_player1_inputs.sv` comprueba individualmente:

- UP → bit 0;
- DOWN → bit 1;
- LEFT → bit 2;
- RIGHT → bit 3;
- SEL → bit 4;
- OK → bit 5;
- GAME_RST → bit 6;
- las siete entradas simultáneas → `0x0000007F`;
- escrituras MMIO ignoradas;
- direcciones locales `01`, `10` y `11` retornando cero;
- reset final limpiando todos los niveles filtrados.

![Waveform del periférico de entradas](resultados/vga_entradas/03_tb_player1_inputs_waveform.png)

**Figura 3.** Durante la secuencia de prueba `input_rdata_o` toma sucesivamente `0x01`, `0x02`, `0x04`, `0x08`, `0x10`, `0x20` y `0x40`, coincidiendo con el bit asignado a cada control. Al activar todas las entradas se obtiene `0x7F`.

Esta prueba valida conjuntamente sincronización, debounce, empaquetado de estado y comportamiento de la interfaz MMIO.

---

## 5. Verificación VGA

### 5.1 `pixel_clock`

#### Función

`pixel_clock` encapsula el Clocking Wizard utilizado para generar el reloj de píxel. La configuración implementada recibe 100 MHz y genera 25 MHz mediante MMCM.

Durante la implementación física se configuró la fuente primaria como `No buffer`. El reloj externo ya está definido en el XDC sobre el puerto superior, por lo que esta configuración evita redefinir un reloj primario dentro de la jerarquía del IP.

#### Qué verifica el testbench

`tb_pixel_clock.sv` comprueba:

- `locked_o = 0` durante reset;
- período de entrada de 10 ns;
- adquisición de lock del MMCM;
- período generado de 40 ns;
- relación 4:1 entre período de píxel y período de entrada;
- pérdida de lock al reactivar reset.

![Waveform del Clocking Wizard](resultados/vga_entradas/04_tb_pixel_clock_waveform.png)

**Figura 4.** Tras liberar reset, el modelo del MMCM alcanza lock y aparece `clk_pixel_o` con período de 40 ns, correspondiente a 25 MHz.

---

### 5.2 `pixel_reset_sync`

#### Función

El dominio VGA debe mantenerse en reset mientras el MMCM no se encuentre bloqueado. Una vez que `locked_i = 1`, la liberación de `rst_pixel_o` se realiza de forma sincronizada con el reloj de píxel.

#### Qué verifica el testbench

Se comprueba:

- aserción por reset general;
- reset mantenido mientras `locked_i = 0`;
- liberación después de dos etapas de sincronización;
- aserción ante pérdida del lock;
- recuperación posterior;
- nueva aserción por reset general.

![Waveform del reset de píxel](resultados/vga_entradas/05_tb_pixel_reset_sync_waveform.png)

**Figura 5.** `reset_pipe_q` muestra las dos etapas utilizadas en la liberación del reset. La pérdida de `locked_i` vuelve a activar inmediatamente la solicitud de reset.

---

### 5.3 `vga_timing`

#### Función

`vga_timing` genera los contadores horizontal y vertical, `active_video`, `HSYNC`, `VSYNC` y la indicación de fin de línea para la temporización nominal 640×480.

La temporización implementada utiliza:

```text
Horizontal total = 800 píxeles
Visible           = 0 ... 639
HSYNC bajo        = 656 ... 751

Vertical total    = 525 líneas
Visible           = 0 ... 479
VSYNC bajo        = 490 ... 491
```

#### Qué verifica el testbench

Se recorren explícitamente los bordes importantes del cuadro:

- último píxel horizontal visible `x=639`;
- inicio de blanking `x=640`;
- flancos de HSYNC en `656` y `752`;
- fin de línea `x=799`;
- última línea visible `y=479`;
- inicio de blanking vertical `y=480`;
- flancos de VSYNC en `490` y `492`;
- último píxel del frame `(799,524)`;
- retorno a `(0,0)`.

![Waveform horizontal de VGA Timing](resultados/vga_entradas/06_tb_vga_timing_hsync.png)

**Figura 6.** Zona final de una línea. Se observa el final del pulso HSYNC y el avance del contador horizontal hasta `x=799`, donde se genera `line_end_o`.

![Waveform vertical de VGA Timing](resultados/vga_entradas/07_tb_vga_timing_vsync.png)

**Figura 7.** Transición de las líneas `478–491`. `active_video_o` se desactiva al entrar en blanking vertical y VSYNC se activa en bajo a partir de `y=490`.

---

### 5.4 `video_memory`

#### Función

La memoria de video permite acceso desde dos dominios:

- puerto CPU: 100 MHz, lectura/escritura;
- puerto VGA: 25 MHz, lectura.

Solo los índices 0–299 son visibles. Las posiciones 300–511 están reservadas.

#### Qué verifica el testbench

`tb_video_memory.sv` comprueba:

- escritura/lectura del índice 0;
- posición intermedia 125;
- último índice visible 299;
- lectura por el puerto VGA de datos escritos por CPU;
- lecturas de 300 y 511 retornando cero;
- escritura a 300 ignorada;
- ausencia de corrupción de la posición 299;
- coherencia entre ambos puertos para una misma palabra.

![Waveform de la memoria de video](resultados/vga_entradas/08_tb_video_memory_waveform.png)

**Figura 8.** Se observan accesos a `0`, `125`, `299`, `300`, `511` y `42`. Los índices reservados retornan cero, mientras ambos puertos observan correctamente los datos almacenados en posiciones visibles.

---

### 5.5 `glyph_rom`

#### Función

`glyph_rom` convierte un código ASCII y una coordenada interna 8×8 en un bit de glyph. El renderer escala cada píxel lógico 8×8 a un bloque físico 4×4 dentro de un tile de 32×32.

El conjunto mínimo implementado incluye espacio, `A–Z`, `0–9`, guion, dos puntos y punto. Un símbolo no soportado se representa como espacio.

#### Qué verifica el testbench

Se comprueban:

- píxeles conocidos de `A`;
- píxeles conocidos de `0`;
- guion, dos puntos y punto;
- espacio completamente vacío;
- caracteres no soportados en blanco;
- todas las letras `A–Z` con al menos un píxel visible;
- todos los dígitos `0–9` con al menos un píxel visible.

![Waveform de Glyph ROM](resultados/vga_entradas/09_tb_glyph_rom_waveform.png)

**Figura 9.** Barrido de coordenadas internas `glyph_x_i` y `glyph_y_i` mientras cambian los caracteres ASCII. `glyph_bit_o` representa los píxeles activos de cada carácter.

---

### 5.6 `tile_renderer`

#### Función

El renderer realiza tres operaciones principales:

```text
pixel_x / pixel_y
        ↓
pixel → tile_index
        ↓
lectura síncrona de VRAM
        ↓
decodificación COLOR / GLYPH_ENABLE / ASCII
        ↓
RGB
```

La lectura síncrona de VRAM obliga a registrar coordenadas y control durante un ciclo de píxel para mantener la correspondencia entre el dato leído y la posición representada.

#### Qué verifica el testbench

`tb_tile_renderer.sv` utiliza la memoria de video real y comprueba:

- mapeo `(0,0)` → tile 0;
- `(31,31)` todavía en tile 0;
- `(32,0)` → tile 1;
- `(0,32)` → tile 20;
- `(100,70)` → tile 43;
- `(639,479)` → tile 299;
- los códigos de color de fondo, agua, barco, impacto, fallo, cursor y HUD;
- color reservado representado en negro;
- glyph habilitado produciendo píxel blanco;
- expansión 4×4 del píxel lógico del glyph;
- fondo del glyph conservando el color base;
- `GLYPH_ENABLE=0` evitando modificar el color;
- video inactivo forzado a negro.

![Waveform del Tile Renderer](resultados/vga_entradas/10_tb_tile_renderer_waveform.png)

**Figura 10.** La waveform relaciona coordenadas, dirección de tile, palabra recuperada de VRAM y `vga_rgb_o`. Se observan tanto los casos de paleta como las pruebas de glyph y blanking.

---

## 6. Verificación integrada — `tb_subsystem2_vga_inputs`

La prueba integrada instancia `subsystem2_vga_inputs`, por lo que recorre el camino completo de los dos lados del subsistema.

### Elementos incluidos

- Clocking Wizard/MMCM;
- sincronizador de reset de píxel;
- VGA Timing;
- Video Memory;
- Tile Renderer;
- Glyph ROM;
- sincronizadores y debouncers de entradas;
- registro MMIO del Jugador 1.

### Comprobaciones principales

El testbench realiza, entre otras, las siguientes pruebas:

1. reset general limpia las entradas y mantiene el MMCM sin lock;
2. escritura CPU de tiles y lectura de retorno desde VRAM;
3. UP + OK llegan al registro MMIO como `0x21`;
4. liberación de botones vuelve el registro a cero;
5. dirección MMIO inválida retorna cero;
6. el MMCM alcanza lock y el reset de píxel se libera;
7. tile de agua y tile de cursor atraviesan VRAM→renderer→RGB;
8. el carácter ASCII `A` almacenado en VRAM produce el píxel de glyph esperado;
9. blanking horizontal fuerza RGB negro;
10. HSYNC/VSYNC se mantienen alineados con la tubería de renderizado.

![Waveform de integración del Subsistema 2](resultados/vga_entradas/11_tb_subsystem2_vga_inputs_waveform.png)

**Figura 11.** Vista global de la simulación integrada. Se observan las interfaces MMIO, la escritura/lectura de VRAM y las señales físicas VGA dentro de una misma ejecución autoverificable.

### Alineación de sincronismos

La implementación final registra `HSYNC` y `VSYNC` un ciclo de reloj de píxel antes de entregarlos a los pines físicos. Este retardo iguala la latencia introducida por la lectura síncrona de VRAM y el pipeline del renderer, manteniendo RGB y sincronismos asociados al mismo píxel.

---

## 7. Síntesis, implementación y análisis temporal

Para la validación física se utilizó `subsystem2_basys3_test_top.sv` como top sintetizable independiente del resto del Proyecto 3.

### Recursos después de implementación

| Recurso | Uso observado |
|---|---:|
| LUT | 175 |
| FF | 211 |
| BRAM | 0.5 RAMB18 |

La utilización reducida es coherente con un periférico de video basado en tiles y una memoria visible de 300 palabras de 32 bits.

### Timing

El diseño implementado reportó:

| Métrica | Resultado |
|---|---:|
| WNS | 4.543 ns |
| TNS | 0.000 ns |
| WHS | 0.122 ns |
| THS | 0.000 ns |
| Setup failing endpoints | 0 |
| Hold failing endpoints | 0 |

Vivado indicó que todas las restricciones temporales especificadas fueron satisfechas.

### Clocking Wizard

Durante la preparación de la prueba física se detectaron advertencias críticas de metodología asociadas a una redefinición del reloj primario. El Clocking Wizard se ajustó para utilizar `Source = No buffer`, manteniendo la restricción `create_clock` únicamente sobre el puerto superior de 100 MHz. Después del cambio, las advertencias críticas `TIMING-4` y `TIMING-27` desaparecieron.

### Advertencias restantes

La implementación todavía reporta advertencias no críticas que deben conservarse como observaciones técnicas:

- `LUTAR-1`: la solicitud asíncrona de reset del pipeline de `pixel_reset_sync` puede atravesar lógica LUT; es una advertencia real que conviene revisar en una limpieza posterior del RTL;
- `SYNTH-6`: el registro de salida de BRAM no fue absorbido dentro de la primitiva, por lo que Vivado informa una posible optimización de timing;
- `TIMING-18`: el top de prueba no define delays externos para varias entradas/salidas de interacción humana y observación.

Estas advertencias no produjeron violaciones de setup/hold en la implementación utilizada para la prueba.

---

## 8. Validación física en Basys 3

Para comprobar el hardware de forma independiente se implementó `subsystem2_basys3_test_top.sv` y un XDC específico de prueba.

### 8.1 Función del top físico

El top realiza dos tareas de observación:

1. presenta las entradas filtradas en LEDs;
2. inicializa automáticamente los 300 tiles visibles de VRAM con un patrón de prueba y activa `LED15` al finalizar.

La asignación utilizada es:

| Control | Indicador |
|---|---|
| BTNU / UP | LED0 |
| BTND / DOWN | LED1 |
| BTNL / LEFT | LED2 |
| BTNR / RIGHT | LED3 |
| SW0 / SEL | LED4 |
| SW1 / OK | LED5 |
| BTNC / GAME_RST | LED6 |
| inicialización VRAM terminada | LED15 |
| SW15 | reset general, activo en alto |

En hardware se utilizó `INPUT_DEBOUNCE_CYCLES = 1_000_000`, equivalente a aproximadamente 10 ms con un reloj de 100 MHz.

### 8.2 Resultado físico

La prueba confirmó:

- con `SW15=0`, el sistema sale de reset y `LED15` se enciende después de inicializar VRAM;
- cada botón direccional activa el LED correspondiente;
- `SW0` y `SW1` se observan como SEL y OK;
- BTNC se observa como GAME_RST;
- al colocar `SW15=1`, `LED15` y los indicadores de entrada se apagan por reset;
- al liberar SW15, el sistema reinicia y vuelve a completar la inicialización.

### 8.3 Evidencia en video

[Video de validación física del Subsistema 2 en Basys 3](https://www.youtube.com/watch?v=NLfvUTprTMg)

La demostración física valida las entradas, el reset general y la secuencia de inicialización de VRAM. En esta etapa no se conectó un monitor al puerto VGA; por lo tanto, la salida VGA física no se declara validada mediante monitor. Su funcionamiento queda respaldado por los testbenches, síntesis, implementación y análisis temporal descritos anteriormente.

---

## 9. Matriz de verificación

| Bloque | Unit TB | Integración | Waveform | FPGA física |
|---|:---:|:---:|:---:|:---:|
| `input_sync` | ✅ | ✅ | ✅ | ✅ dentro del periférico |
| `debounce` | ✅ | ✅ | ✅ | ✅ dentro del periférico |
| `player1_inputs` | ✅ | ✅ | ✅ | ✅ |
| `pixel_clock` | ✅ | ✅ | ✅ | ✅ implementado |
| `pixel_reset_sync` | ✅ | ✅ | ✅ | ✅ dentro del sistema |
| `vga_timing` | ✅ | ✅ | ✅ | no monitorizado |
| `video_memory` | ✅ | ✅ | ✅ | inicialización observada |
| `glyph_rom` | ✅ | ✅ | ✅ | no monitorizado |
| `tile_renderer` | ✅ | ✅ | ✅ | no monitorizado |
| `subsystem2_vga_inputs` | — | ✅ | ✅ | entradas/reset ✅; VGA visual pendiente |

---

## 10. Conclusiones

Las pruebas unitarias y la simulación integrada cubren los caminos funcionales principales del Subsistema 2. El periférico de entradas demuestra la cadena completa de sincronización, debounce y empaquetado MMIO, mientras que la ruta VGA verifica generación de reloj, reset de dominio, temporización, almacenamiento dual-port, selección de tiles, glyphs, color y blanking.

La simulación integrada demuestra que las escrituras realizadas desde el dominio del CPU pueden llegar a VRAM y convertirse posteriormente en RGB dentro del dominio de píxel, manteniendo la alineación necesaria entre datos y sincronismos. El diseño además cumple las restricciones temporales utilizadas durante la implementación en Basys 3.

La prueba física confirma el funcionamiento del acondicionamiento de entradas, el reset general y la inicialización de la memoria de video. La validación visual mediante un monitor VGA permanece como prueba física pendiente y no se sustituye por los resultados de simulación.

---

## Referencias internas

- [Diseño de tercer nivel — VGA y entradas](../diseno/nivel_3_vga_entradas.md)
- [Diseño de cuarto nivel — VGA y entradas](../diseno/nivel_4_vga_entradas.md)
- `src/design/inputs/`
- `src/design/vga/`
- `src/design/top/subsystem2_basys3_test_top.sv`
- `src/testbench/inputs/`
- `src/testbench/vga/`
- `src/testbench/integration/tb_subsystem2_vga_inputs.sv`
