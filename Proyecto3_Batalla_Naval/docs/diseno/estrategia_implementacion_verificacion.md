# Estrategia de implementación y plan de verificación

## Método de desarrollo

El diseño parte del sistema y su entorno en el primer nivel. El segundo separa procesador, memorias, bus y periféricos; los niveles tercero y cuarto detallan las interfaces y los circuitos de cada subsistema. Las reglas del juego se implementan en ensamblador y utilizan los periféricos mediante MMIO.

El desarrollo por etapas permite localizar un fallo dentro de un bloque antes de introducir las dependencias del sistema completo. Las interfaces se fijan antes de la integración para que el CPU, las memorias y los periféricos compartan el mismo contrato de lectura, escritura y reset.

La secuencia de implementación y verificación es la siguiente:

1. Definir puertos, mapa de memoria, permisos, latencia de lectura y resets antes de conectar bloques.
2. Implementar y verificar CPU/ROM, VGA/entradas y plataforma de datos por separado, con testbenches autoverificables.
3. Ensamblar el programa y comprobar que `program.hex` coincide con las fuentes y cabe en 2048 palabras.
4. Integrar los bloques en `battleship_top` y adaptar los pines en `basys3_top`.
5. Ejecutar partidas completas sobre CPU/ROM reales en RTL, comparando tramas, RAM y salidas con una referencia.
6. Sintetizar e implementar para `xc7a35tcpg236-1`, usando el IP de reloj y las restricciones de Basys 3. Examinar recursos, latches, DRC y setup/hold.
7. Simular un fragmento representativo del netlist enrutado con SDF y verificar el sistema en placa. Conservar evidencias y versión de fuentes de cada ensayo.

## Matriz de requisitos y comprobaciones

La tabla relaciona cada requisito con los módulos que lo implementan y la condición que debe comprobarse. Las pruebas unitarias aíslan funciones, las partidas evalúan la integración y los ensayos temporizados y físicos comprueban el circuito implementado.

| ID | Requisito | Implementación | Prueba y criterio de aceptación |
|---|---|---|---|
| R01 | CPU RISC-V y ejecución desde ROM | `cpu`, `program_rom`, programa HEX | `cpu_tb`: estado arquitectónico contra referencia, 29 operaciones y latencias correctas; `program_rom_tb`: lectura registrada y límites |
| R02 | RAM y periféricos mediante palabras de 32 bits | `address_decoder`, `data_bus`, RAM y MMIO | TB de bus/memorias: destino único por escritura, lectura síncrona, direcciones no mapeadas sin efectos |
| R03 | Rechazo y recuperación de fallos del CPU | Validación de instrucciones/alineación, FSM FAULT | TB de control/datapath/CPU: sin escrituras indebidas y recuperación por reset desde diez estados |
| R04 | VGA 640 × 480, reloj de píxel y tiles | MMCM, timing, memoria, renderer, glifos | TB de VGA: límites, sincronismos, acceso de tiles, alineación y reset; comprobar imagen en monitor |
| R05 | Controles locales estables | Sincronización, debounce, registro INPUTS | TB de entradas y `basys3_controls_tb`: asignación física, rebotes y reset; comprobar navegación/SEL/OK en placa |
| R06 | Comunicación J2 por UART 115200, 8N1 | TX/RX, periférico UART, terminal | TB UART: muestreo, trama y reconocimiento RX; pruebas PC: parser/longitudes/estado; intercambio real en placa |
| R07 | Flotas 4/3/2, tableros 8 × 8 y colocación concurrente | Programa RISC-V y RAM | Partidas J1/J2: aceptación, orientación, traslape, límites, identificador y barco ya colocado |
| R08 | Disparos válidos, turnos y rechazo de repetidos | Programa RISC-V | Partidas: acciones fuera de fase/turno y coordenadas inválidas se rechazan sin consumir una jugada válida |
| R09 | Agua, impacto, hundimiento y victoria | RAM, mensajes, VGA e indicadores | Comparar cada trama y el estado final de tableros; ejecutar guiones con ambos ganadores |
| R10 | Información oculta del adversario | Representación gráfica y protocolo | Inspeccionar contenido de tiles/mensajes y verificar visualmente tablero propio y descubrimientos del rival |
| R11 | Sonidos distintos e indicadores | Buzzer, displays, LED | TB de salidas: períodos, duración, melodía, marcador y fase; comprobar audición y displays en placa |
| R12 | Nueva partida conserva victorias; reset general las borra | GAME_RST por software y reset RTL | Partidas: RAM/indicadores después de GAME_RST; TB de reset y ensayo físico con SW15 |
| R13 | Prueba general autoverificable y error identificado | `all_top_modules_tb` y partidas integradas | PASS normal; activar assertion falsa en copia de prueba y exigir `$fatal` con mensaje identificable |
| R14 | Diseño sintetizable y temporización de implementación | `basys3_top`, IP, XDC | Cero latches/infracciones DRC; slack no negativo en rutas analizadas; netlist/SDF para simulación temporizada |
| R15 | Entregable reproducible y documentación | Scripts, manifiestos, diseño e informe | HEX actualizado, enlaces válidos y evidencias asociadas a hashes de fuentes; revisión cruzada de subsistemas |

## Referencias y comparación automática

Los TB unitarios comparan resultados con valores esperados y detienen la simulación mediante `$fatal` si existe una discrepancia. `cpu_tb` compara registros y PC después de cada instrucción. Las partidas comparan todas las tramas con archivos esperados y comprueban 128 casillas más 11 variables de RAM y dos registros de salida. Las pruebas Python verifican el ensamblador y el estado de la terminal.

Una aserción deliberadamente falsa comprueba que el testbench detecta y comunica un fallo. Los estímulos inválidos de las partidas evalúan el comportamiento de rechazo del sistema, como conservar el turno después de un disparo repetido.

## Reproducción y evidencias

Los comandos están en la [guía de uso](../uso_basys3.md). Cada ejecución produce registros de consola y manifiestos SHA-256 en `build/`. Las evidencias utilizadas por el informe se conservan en `docs/informe/resultados/`, identificadas por fecha y módulo evaluado.

La prueba física comprende una partida completa, la respuesta de VGA y terminal, los sonidos y el marcador. Se comprueba que BTNC inicia otra partida conservando las victorias y que SW15 aplica reset general. El registro del ensayo identifica la revisión de fuentes y el bitstream utilizado. Los resultados obtenidos se presentan en el [informe general](../informe/informe_general.md).

[Arquitectura general](nivel_2.md) · [Índice de diseño](README.md)
