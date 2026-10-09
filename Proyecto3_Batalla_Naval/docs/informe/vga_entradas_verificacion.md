# Verificación — Subsistema 2: VGA y entradas del Jugador 1

**Subsistema:** S2  
**Responsable:** Kenneth Campos

---

## 1. Objetivo

La verificación del Subsistema 2 busca demostrar el funcionamiento correcto de:

```text
entradas del Jugador 1
sincronización
debounce
interfaz MMIO
reloj de píxel
reset VGA
temporización VGA
memoria de video
renderer
Glyph ROM
salida RGB
HSYNC
VSYNC
```

La estrategia combina:

1. pruebas unitarias;
2. pruebas de integración;
3. prueba black-box del periférico completo;
4. validación física sobre Basys 3;
5. pruebas de integración con el sistema completo.

El objetivo no es verificar las reglas de Batalla Naval dentro del Subsistema 2, ya que esas reglas pertenecen al software RISC-V.

---

## 2. Arquitectura verificada

La cadena de entradas es:

```text
botones / switches
        ↓
input_sync
        ↓
debounce
        ↓
player1_inputs
        ↓
input_rdata_o
        ↓
MMIO
        ↓
CPU
```

La cadena VGA es:

```text
CPU
 ↓
MMIO
 ↓
VRAM
 ↓
tile_renderer
 ↓
glyph_rom / color
 ↓
RGB
```

mientras:

```text
100 MHz
 ↓
Clocking Wizard/MMCM
 ↓
25 MHz
 ↓
vga_timing
 ↓
HSYNC / VSYNC
```

---

# 3. Mapa físico final

La asignación vigente es:

| Control | Función |
|---|---|
| `BTNU` | UP |
| `BTND` | DOWN |
| `BTNL` | LEFT |
| `BTNR` | RIGHT |
| `SW0` | SEL |
| `SW1` | OK |
| `BTNC` | GAME_RST |
| `SW15` | RUN/reset general |

El registro MMIO de entradas utiliza:

| Bit | Función |
|---:|---|
| 0 | UP |
| 1 | DOWN |
| 2 | LEFT |
| 3 | RIGHT |
| 4 | SEL |
| 5 | OK |
| 6 | GAME_RST |
| `[31:7]` | 0 |

La dirección es:

```text
0x00010120
```

---

# 4. Pruebas unitarias

## 4.1 `tb_input_sync`

Verifica el sincronizador de dos flip-flops empleado para las entradas físicas.

Se comprueba:

```text
reset
propagación del nivel
latencia esperada
estabilidad de salida
```

El objetivo es garantizar que las entradas asíncronas no se utilicen directamente por la lógica síncrona.

---

## 4.2 `tb_debounce`

Verifica el filtro de rebotes.

Se aplican:

```text
cambios breves
cambios estables
liberación
reset
```

Los pulsos que no permanecen estables durante el número requerido de ciclos no modifican la salida.

En hardware se utiliza:

```text
DEBOUNCE_CYCLES = 1_000_000
```

equivalente aproximadamente a:

```text
10 ms
```

a 100 MHz.

En simulación se utilizan parámetros reducidos cuando es necesario para disminuir el tiempo de ejecución.

---

## 4.3 `tb_player1_inputs`

Verifica el periférico de entradas completo.

Se comprueba:

```text
UP
DOWN
LEFT
RIGHT
SEL
OK
GAME_RST
```

y el empaquetado:

```text
[6:0]
=
GAME_RST OK SEL RIGHT LEFT DOWN UP
```

Además:

- las direcciones locales no implementadas retornan cero;
- las escrituras son ignoradas;
- el reset limpia los niveles observados.

---

# 5. Pruebas unitarias VGA

## 5.1 `tb_pixel_clock`

Comprueba la generación del reloj de píxel.

El bloque recibe:

```text
100 MHz
```

y genera:

```text
25 MHz
```

junto con la señal:

```text
locked
```

---

## 5.2 `tb_pixel_reset_sync`

Comprueba que el dominio VGA permanezca en reset mientras:

```text
rst_i = 1
```

o:

```text
locked_i = 0
```

y que la liberación se produzca sincronizada con:

```text
clk_pixel
```

---

## 5.3 `tb_vga_timing`

Verifica:

```text
contador horizontal
contador vertical
active_video
HSYNC
VSYNC
line_end
```

Parámetros esperados:

```text
H_TOTAL = 800
V_TOTAL = 525

HSYNC bajo = 96 ciclos
VSYNC bajo = 2 líneas
```

La región visible es:

```text
640 × 480
```

---

## 5.4 `tb_video_memory`

La VRAM se organiza como:

```text
512 × 32 bits
```

con:

```text
0...299   visibles
300...511 reservados
```

El puerto CPU opera a:

```text
100 MHz
```

y el puerto VGA a:

```text
25 MHz
```

El test comprueba:

- escritura y lectura del índice 0;
- escritura y lectura de posiciones intermedias;
- índice visible 299;
- lectura mediante el puerto VGA;
- protección del índice 300;
- protección del índice 511;
- escritura reservada ignorada;
- ausencia de corrupción del último tile visible.

![Waveform de la memoria de video](resultados/vga_entradas/08_tb_video_memory_waveform.png)

**Figura 8.** Accesos a posiciones visibles y reservadas de la memoria de video.

---

## 5.5 `tb_glyph_rom`

`glyph_rom` recibe:

```text
ASCII
glyph_x
glyph_y
```

y produce:

```text
glyph_bit
```

Se verifica:

- letra `A`;
- dígito `0`;
- guion;
- dos puntos;
- punto;
- espacio;
- caracteres no soportados;
- letras `A–Z`;
- dígitos `0–9`.

![Waveform de Glyph ROM](resultados/vga_entradas/09_tb_glyph_rom_waveform.png)

**Figura 9.** Verificación de los patrones gráficos implementados.

---

## 5.6 `tb_tile_renderer`

Comprueba la conversión:

```text
píxel
 ↓
tile
 ↓
VRAM
 ↓
color / glyph
 ↓
RGB
```

Los casos incluyen:

```text
(0,0)       → tile 0
(31,31)     → tile 0
(32,0)      → tile 1
(0,32)      → tile 20
(100,70)    → tile 43
(639,479)   → tile 299
```

También se verifican los colores:

```text
fondo
agua
barco
impacto
fallo
cursor
HUD
reservado
```

y:

```text
GLYPH_ENABLE
píxel blanco de glyph
expansión 4×4
fondo del glyph
blanking
```

![Waveform del Tile Renderer](resultados/vga_entradas/10_tb_tile_renderer_waveform.png)

**Figura 10.** Relación entre coordenadas, dirección de tile, palabra de VRAM y RGB.

---

# 6. Verificación integrada — `tb_subsystem2_vga_inputs`

Esta prueba instancia:

```text
subsystem2_vga_inputs
```

e incluye simultáneamente:

```text
pixel_clock
pixel_reset_sync
vga_timing
video_memory
tile_renderer
glyph_rom
player1_inputs
```

Se comprueba:

- reset general;
- lock del MMCM;
- liberación del dominio VGA;
- escritura CPU a VRAM;
- lectura de retorno;
- entrada `UP + OK`;
- liberación de entradas;
- dirección MMIO inválida;
- color agua;
- color cursor;
- glyph ASCII;
- blanking;
- `HSYNC`;
- `VSYNC`;
- alineación de sincronismos.

![Waveform de integración del Subsistema 2](resultados/vga_entradas/11_tb_subsystem2_vga_inputs_waveform.png)

**Figura 11.** Simulación integrada de MMIO, VRAM y salida VGA.

---

# 7. Prueba black-box — `tb_subsystem2_peripheral`

Esta es la prueba principal de aceptación funcional del Subsistema 2.

El DUT se observa exclusivamente desde sus interfaces externas.

No se depende de señales internas de:

```text
input_sync
debounce
video_memory
glyph_rom
tile_renderer
vga_timing
```

---

## 7.1 Interfaces estimuladas

Se utilizan:

```text
clk_100_i
rst_i

up_i
down_i
left_i
right_i
sel_i
ok_i
game_rst_i

input_addr_i
input_write_enable_i
input_wdata_i

vga_addr_i
vga_write_enable_i
vga_wdata_i
```

---

## 7.2 Salidas verificadas

Se observan:

```text
input_rdata_o
vga_rdata_o
vga_hsync_o
vga_vsync_o
vga_rgb_o
```

---

## 7.3 Comprobaciones

La prueba contiene:

```text
27 checks
```

incluyendo:

- reset;
- UP;
- DOWN;
- LEFT;
- RIGHT;
- SEL;
- OK;
- GAME_RST;
- las siete entradas simultáneamente;
- escrituras al periférico ignoradas;
- direcciones locales inválidas;
- liberación de entradas;
- tile 0;
- tile 299;
- tile reservado 300;
- agua;
- cursor;
- glyph `A`;
- blanking;
- ancho de HSYNC;
- período de HSYNC;
- ancho de VSYNC;
- reset final.

El resultado fue:

```text
SUBSYSTEM 2 PERIPHERAL TEST SUMMARY
Checks : 27
Errors : 0
RESULT : TEST PASSED
```

![Resumen autoverificable del periférico completo](resultados/vga_entradas/12_tb_subsystem2_peripheral_summary.png)

**Figura 12.** Resultado final de aceptación black-box.

---

## 7.4 Waveform externa

![Entradas y salidas del periférico completo](resultados/vga_entradas/13_tb_subsystem2_peripheral_io.png)

**Figura 13.** Interfaces MMIO, RGB y sincronismos observados desde la frontera del Subsistema 2.

---

# 8. Temporización observada en simulación

La prueba black-box midió:

| Parámetro | Resultado |
|---|---:|
| ancho bajo HSYNC | 3840 ns |
| período de línea HSYNC | 32000 ns |
| ancho bajo VSYNC | 64000 ns |

Estos valores corresponden a:

```text
96 × 40 ns = 3840 ns
800 × 40 ns = 32000 ns
2 × 32000 ns = 64000 ns
```

con:

```text
Tpixel = 1 / 25 MHz = 40 ns
```

---

# 9. Alineación RGB / sincronismos

La VRAM posee lectura síncrona.

Esto introduce:

```text
1 ciclo
```

de `clk_pixel`.

Por ello:

```text
HSYNC
VSYNC
```

se registran también durante un ciclo.

Así:

```text
RGB
HSYNC
VSYNC
```

corresponden al mismo píxel.

---

# 10. Validación física independiente

La implementación física independiente utiliza:

```text
src/design/top/subsystem2_basys3_test_top.sv
```

junto con:

```text
src/constraints/subsystem2_basys3_test.xdc
```

Este top no contiene lógica de Batalla Naval.

Su función es probar:

```text
entradas
debounce
VRAM
renderer
glyphs
VGA
```

---

## 10.1 Mapeo físico

| Control | Función | LED |
|---|---|---:|
| BTNU | UP | LED0 |
| BTND | DOWN | LED1 |
| BTNL | LEFT | LED2 |
| BTNR | RIGHT | LED3 |
| SW0 | SEL | LED4 |
| SW1 | OK | LED5 |
| BTNC | GAME_RST | LED6 |

Los LEDs `0–6` reflejan:

```text
input_status[6:0]
```

por lo que muestran las señales filtradas.

---

## 10.2 Reset y RUN

`SW15` se procesa mediante:

```systemverilog
(* ASYNC_REG = "TRUE" *) logic [1:0] reset_pipe_q = 2'b11;

always_ff @(posedge clk) begin
    reset_pipe_q <= {reset_pipe_q[0], ~sw[15]};
end

assign rst = reset_pipe_q[1];
```

Comportamiento:

```text
SW15 = 0
→ reset aplicado
→ LED15 = 0

SW15 = 1
→ RUN
→ LED15 = 1
```

---

## 10.3 Inicialización de VRAM

El top escribe automáticamente:

```text
300 tiles
```

visibles.

Durante el proceso:

```text
init_done_q = 0
```

y al finalizar:

```text
init_done_q = 1
```

La señal se conecta a:

```text
LED14
```

Por tanto:

```text
LED14 = 1
→ VRAM del patrón de prueba inicializada
```

---

# 11. Validación física VGA

La salida fue verificada físicamente conectando un monitor al puerto VGA de la Basys 3.

La prueba confirma el funcionamiento conjunto de:

```text
Clocking Wizard
pixel reset
vga_timing
VRAM
tile renderer
glyph_rom
RGB
HSYNC
VSYNC
```

![Validación física de la salida VGA del Subsistema 2](resultados/vga_entradas/16_subsystem2_vga_monitor_physical.jpeg)

**Figura 14.** Patrón del Subsistema 2 mostrado físicamente en un monitor.

---

# 12. Evidencia histórica

Existe además una prueba física anterior de las entradas del Subsistema 2.

Esta evidencia corresponde a una revisión anterior del mapeo físico y se conserva únicamente como parte del historial de desarrollo.

La asignación vigente es:

```text
BTNU → UP
BTND → DOWN
BTNL → LEFT
BTNR → RIGHT
SW0  → SEL
SW1  → OK
BTNC → GAME_RST
```

---

# 13. Implementación del Subsistema 2 aislado

Los reportes corresponden a:

```text
subsystem2_basys3_test_top
```

después de placement y routing.

Archivos:

```text
resultados/vga_entradas/14_subsystem2_utilization_impl.rpt
resultados/vga_entradas/15_subsystem2_timing_summary_impl.rpt
```

---

## 13.1 Recursos

| Recurso | Utilizado |
|---|---:|
| LUT | 172 |
| FF | 211 |
| RAMB18 | 1 |
| DSP | 0 |

---

## 13.2 Timing

| Métrica | Resultado |
|---|---:|
| WNS | +4.293 ns |
| TNS | 0.000 ns |
| WHS | +0.122 ns |
| THS | 0.000 ns |
| Setup failing endpoints | 0 |
| Hold failing endpoints | 0 |

Las restricciones temporales especificadas se cumplen.

---

# 14. Clocking Wizard y advertencias

Durante el desarrollo se detectaron advertencias críticas asociadas a una redefinición del reloj principal.

El Clocking Wizard se configuró como:

```text
Source = No buffer
```

manteniendo:

```text
create_clock
```

únicamente sobre el reloj superior de 100 MHz.

Después del ajuste desaparecieron las advertencias críticas:

```text
TIMING-4
TIMING-27
```

También se observaron advertencias no críticas relacionadas con:

```text
LUTAR-1
SYNTH-6
TIMING-18
```

que no impidieron implementar y generar el bitstream del S2.

---

# 15. Diferencia entre top de prueba y juego completo

Esta distinción es importante para interpretar correctamente los LEDs.

## Top independiente

```text
subsystem2_basys3_test_top
```

| LED | Función |
|---:|---|
| 0–6 | entradas filtradas |
| 7–13 | apagados |
| 14 | VRAM inicializada |
| 15 | RUN |

## Sistema completo

```text
basys3_top
```

| LED | Función |
|---:|---|
| 0 | BTNU físico |
| 1 | BTND físico |
| 2 | BTNL físico |
| 3 | BTNR físico |
| 4 | SW0 físico |
| 5 | SW1 físico |
| 6 | BTNC físico |
| 7–10 | apagados |
| 11 | colocación |
| 12 | batalla |
| 13 | resultado |
| 14 | apagado |
| 15 | RUN |

En el sistema completo los LED0–6 no muestran las señales filtradas.

El CPU sí continúa recibiendo:

```text
clean_levels
```

a través del periférico de entradas.

---

# 16. Verificación de LEDs de fase — `basys3_controls_tb`

La integración final incorpora:

```text
basys3_controls_tb.sv
```

Este testbench instancia:

```text
basys3_top
```

y:

```text
subsystem2_basys3_test_top
```

permitiendo comparar ambos contextos.

Se verifica:

```text
reset inicial
LED15
VRAM init LED14 del S2
liberación de reset en dos flancos
mapeo físico
debounce
GAME_RST
LED11
LED12
LED13
fase reservada
```

Los códigos forzados durante la prueba son:

```text
00 → LED11
01 → LED12
10 → LED13
11 → ninguno
```

---

# 17. GAME_RST no es reset de hardware

`basys3_controls_tb` verifica explícitamente que:

```text
BTNC / GAME_RST
```

no active:

```text
rst
```

Por tanto:

```text
GAME_RST
→ entrada lógica al software

SW15
→ reset general
```

Esta separación es un requisito funcional del diseño.

---

# 18. Verificación de switches activos al arrancar

La prueba:

```text
boot_switches_tb.sv
```

arranca el sistema con:

```text
SEL = 1
OK = 1
```

y utiliza el debounce físico de:

```text
1 000 000 ciclos
```

El software espera que el filtro se estabilice antes de capturar:

```text
BTN_PREV
```

Se verifica que esos niveles iniciales no produzcan:

```text
rotación accidental
colocación accidental
```

Después de liberar los switches se comprueba que el sistema continúa correctamente y el CPU no entra en `FAULT`.

---

# 19. Integración con el software VGA

La verificación final del sistema demuestra que el CPU puede escribir la VRAM utilizada por el Subsistema 2.

El programa calcula:

```text
tile_index = fila*20 + columna
```

y:

```text
direccion = VGA_BASE + 4*tile_index
```

La pantalla real incluye:

```text
BATALLA NAVAL
COLOCANDO
TURNO J1
TURNO J2
TU FLOTA
RIVAL
J1:nn
J2:nn
FIN
COLOCA BARCOS
IMPACTO
FALLO
HUNDIDO
NO VALIDO
GANA J1
GANA J2
```

La lógica de qué texto debe aparecer pertenece al software.

La forma gráfica pertenece al Subsistema 2.

---

# 20. Cursor según fase

El sistema utiliza:

```text
COL_CURSOR = 5
```

y el renderer lo convierte en:

```text
12'hFF0
```

Durante colocación:

```text
cursor → tablero propio
```

y representa la silueta del barco según:

```text
longitud
orientación
```

Durante batalla:

```text
cursor → tablero rival
```

Durante resultado:

```text
sin cursor
```

Esto confirma la separación entre:

```text
software
→ posición y significado

hardware VGA
→ representación RGB
```

---

# 21. Redibujado incremental

La aplicación utiliza:

```text
VGA_DIRTY
VGA_PASO
```

para realizar el redibujado por partes.

Esto permite regresar periódicamente al ciclo principal y atender:

```text
botones
UART RX
UART TX
```

La actualización VGA no bloquea innecesariamente el servicio de comunicación.

---

# 22. Pruebas globales relacionadas

El resumen de integración vigente registra `PASS` para:

```text
tb_input_sync
tb_debounce
tb_player1_inputs
tb_pixel_clock
tb_pixel_reset_sync
tb_vga_timing
tb_video_memory
tb_glyph_rom
tb_tile_renderer
tb_subsystem2_vga_inputs
tb_subsystem2_peripheral
basys3_controls_tb
boot_switches_tb
all_top_modules_tb
tb_battleship_system
```

Esto extiende la validación desde el bloque individual hasta el sistema completo.

---

# 23. Resultados del sistema completo

Estos resultados se presentan como contexto de integración y no sustituyen los del S2 aislado.

Para:

```text
basys3_top
```

se obtuvo:

| Recurso | Uso |
|---|---:|
| LUT | 1812 |
| FF | 1692 |
| RAMB36E1 | 4 |
| DSP | 0 |
| MMCM | 1 |
| BUFG | 3 |

Timing:

| Métrica | Resultado |
|---|---:|
| WNS | +0.219 ns |
| TNS | 0 |
| WHS | +0.122 ns |
| THS | 0 |
| WPWS | +3.000 ns |

El DRC final reportó:

```text
0 infracciones
```

---

# 24. Limitaciones

La verificación permite identificar las siguientes características de la arquitectura:

```text
VRAM sin doble buffer
```

por lo que una actualización puede hacerse visible durante un cuadro en curso.

La memoria dual-port permite dominios independientes, pero el diseño no establece un valor contractual durante una colisión exacta de lectura VGA y escritura CPU sobre la misma posición.

Estas características no afectan el funcionamiento esperado del juego bajo el esquema de actualización implementado.

---

# 25. Matriz final de verificación

| Bloque | Unit TB | Integración S2 | Sistema completo | FPGA |
|---|:---:|:---:|:---:|:---:|
| `input_sync` | ✅ | ✅ | ✅ | ✅ |
| `debounce` | ✅ | ✅ | ✅ | ✅ |
| `player1_inputs` | ✅ | ✅ | ✅ | ✅ |
| `pixel_clock` | ✅ | ✅ | ✅ | ✅ |
| `pixel_reset_sync` | ✅ | ✅ | ✅ | ✅ |
| `vga_timing` | ✅ | ✅ | ✅ | ✅ |
| `video_memory` | ✅ | ✅ | ✅ | ✅ |
| `glyph_rom` | ✅ | ✅ | ✅ | ✅ |
| `tile_renderer` | ✅ | ✅ | ✅ | ✅ |
| `subsystem2_vga_inputs` | — | ✅ | ✅ | ✅ |
| mapeo físico | — | — | ✅ | ✅ |
| LED11–LED13 | — | — | ✅ | integración global |
| GAME_RST vs reset | — | — | ✅ | ✅ |

---

# 26. Conclusiones

La verificación del Subsistema 2 cubre desde los bloques individuales hasta la integración con el juego completo.

Las entradas del Jugador 1 fueron verificadas desde la señal física hasta el registro MMIO, incluyendo sincronización y debounce.

La ruta VGA fue verificada desde las escrituras de VRAM hasta las señales RGB, `HSYNC` y `VSYNC`.

La prueba black-box:

```text
tb_subsystem2_peripheral
```

completó:

```text
27 checks
0 errors
TEST PASSED
```

La implementación independiente del S2 cumple timing con:

```text
WNS = +4.293 ns
WHS = +0.122 ns
```

La validación física confirmó:

```text
entradas
reset
VRAM
glyphs
colores
sincronismos
salida VGA
```

La integración posterior añadió pruebas específicas para:

```text
LED11 = colocación
LED12 = batalla
LED13 = resultado
GAME_RST separado del reset general
SW15 como RUN/reset
switches activos al arrancar
```

La lógica interna del Subsistema 2 no necesitó incorporar estados del juego.

Esto confirma que la arquitectura conserva correctamente la separación entre:

```text
hardware de interfaz
```

y:

```text
software RISC-V de Batalla Naval
```

---

## Referencias internas

- [Diseño de tercer nivel — VGA y entradas](../diseno/nivel_3_vga_entradas.md)
- [Diseño de cuarto nivel — VGA y entradas](../diseno/nivel_4_vga_entradas.md)
- [Informe general](informe_general.md)
- `src/design/inputs/`
- `src/design/vga/`
- `src/design/top/subsystem2_basys3_test_top.sv`
- `src/design/top/basys3_top.sv`
- `src/constraints/subsystem2_basys3_test.xdc`
- `src/constraints/basys3_battleship.xdc`
- `src/testbench/integration/tb_subsystem2_vga_inputs.sv`
- `src/testbench/integration/tb_subsystem2_peripheral.sv`
- `src/testbench/integration/basys3_controls_tb.sv`
- `src/testbench/integration/boot_switches_tb.sv`
- `docs/informe/resultados/vga_entradas/14_subsystem2_utilization_impl.rpt`
- `docs/informe/resultados/vga_entradas/15_subsystem2_timing_summary_impl.rpt`
- `docs/informe/resultados/vga_entradas/16_subsystem2_vga_monitor_physical.jpeg`