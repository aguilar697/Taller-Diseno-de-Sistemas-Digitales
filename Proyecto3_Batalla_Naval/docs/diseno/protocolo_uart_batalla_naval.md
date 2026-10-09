# Protocolo UART de Batalla Naval

## Alcance

La aplicación del Jugador 2 se comunica con el programa RISC-V mediante UART a 115200 baud, 8N1. El periférico RTL transmite y recibe bytes; el parser y las reglas se ejecutan en software RISC-V. Este contrato corresponde a [constantes.s](../../src/software_riscv/constantes.s), [uart.s](../../src/software_riscv/uart.s) y [naval_terminal.py](../../src/software_pc/naval_terminal.py).

## Formato

| Campo | Tamaño | Significado |
|---|---:|---|
| SOF | 1 byte | `0xA5` |
| TYPE | 1 byte | Tipo de mensaje |
| LENGTH | 1 byte | Número de bytes del payload |
| PAYLOAD | LENGTH bytes | Datos del mensaje |

No hay checksum ni escape de bytes. `0xA5` dentro de un payload es un dato y no reinicia una trama válida. Los bytes distintos de SOF se ignoran mientras el parser busca una cabecera. En recepción FPGA, la etapa de longitud comprueba el tipo almacenado y su tamaño esperado; una combinación inválida reinicia el parser y genera ERROR. Una trama incompleta se abandona al alcanzar `RX_EDAD_MAX=2000` iteraciones de servicio sin completar la recepción. Este umbral no es una duración fija en milisegundos.

## Mensajes PC → FPGA

| Tipo | Nombre | LENGTH | Payload, en orden |
|---|---|---:|---|
| `0x10` | PLACE_SHIP | 4 | `ship_id`, `row`, `col`, `orientation` |
| `0x11` | SHOT | 2 | `row`, `col` |

`ship_id=0/1/2` selecciona el barco de longitud 4/3/2. Las coordenadas válidas son 0–7. `orientation=0` indica horizontal y `1` vertical. La terminal presenta coordenadas de usuario y las convierte a esos índices antes de transmitir.

## Mensajes FPGA → PC

| Tipo | Nombre | LENGTH | Payload, en orden |
|---|---|---:|---|
| `0x80` | PLACE_RESULT | 3 | `ship_id`, `accepted`, `reason` |
| `0x81` | BATTLE_START | 1 | `first_player` |
| `0x82` | TURN | 1 | `player` |
| `0x83` | SHOT_RESULT | 3 | `row`, `col`, `result` |
| `0x84` | INCOMING_SHOT | 3 | `row`, `col`, `result` |
| `0x85` | GAME_OVER | 7 | `winner`, `p1_shots`, `p2_shots`, `p1_sunk`, `p2_sunk`, `p1_wins`, `p2_wins` |
| `0x86` | PLACEMENT_START | 2 | `p1_wins`, `p2_wins` |
| `0x87` | ERROR | 2 | `rejected_type`, `reason` |

Los jugadores se identifican con 1 y 2. PLACE_RESULT usa `accepted=1` para aceptación y `0` para rechazo. SHOT_RESULT informa un disparo de J2; INCOMING_SHOT informa un disparo de J1. Ambos usan `result=0` agua, `1` impacto y `2` hundimiento. **Un disparo repetido se comunica mediante ERROR**, no como un cuarto resultado válido.

GAME_OVER incluye el ganador, los disparos válidos de ambos jugadores, los barcos que cada jugador hundió y el marcador acumulado. PLACEMENT_START anuncia una nueva partida y permite reiniciar el estado de la terminal conservando las victorias recibidas. Los contadores ocupan un byte en la trama; el programa limita las victorias a 99.

## Razones de rechazo

| PLACE_RESULT reason | Significado |
|---:|---|
| 0 | Colocación aceptada |
| 1 | Traslape |
| 2 | Fuera del tablero |
| 3 | Identificador de barco inválido |
| 4 | Barco ya colocado |
| 5 | Orientación inválida |

| ERROR reason | Significado |
|---:|---|
| 1 | Tipo o longitud de mensaje inválidos |
| 2 | Acción fuera de la fase permitida |
| 3 | Jugador fuera de turno |
| 4 | Disparo repetido |
| 5 | Coordenada inválida |

Los rechazos no se consideran disparos válidos ni deben cambiar el turno. La terminal muestra el resultado informado por la FPGA; su validación de entrada no reemplaza la validación del programa.

## Acceso al periférico y límites

UART CONTROL está en `0x00010040`: bit 0 indica TX lista y bit 1 RX válida. UART TX está en `0x00010044` y UART RX en `0x00010048`. Escribir TX inicia una transmisión únicamente si está lista. Leer RX no reconoce la recepción: se escribe uno en CONTROL[1] para limpiar RX válida. Si recepción nueva y reconocimiento coinciden, se conserva el byte nuevo y su indicación válida.

El hardware RX conserva **un único byte, sin FIFO ni señal de overflow**. Un byte recibido reemplaza al anterior si no se consumió. El ciclo de servicio del programa atiende RX y distribuye el trabajo gráfico para reducir ese intervalo. La cola TX de software tiene capacidad para 192 bytes, almacenados como palabras en RAM; tampoco es ilimitada. Las partidas verificadas prueban el tráfico de sus guiones, no una garantía ante cualquier saturación del canal.

## Evidencias

Las partidas con victoria J1/J2 comparan respectivamente 44 y 50 tramas con sus referencias. Las 31 pruebas de terminal comprueban longitudes, valores y recuperación del estado. Los registros y comandos están en el [informe integrado](../informe/integracion_verificacion.md).

[Diseño de la plataforma](nivel_3_uart.md) · [Índice de diseño](README.md)
