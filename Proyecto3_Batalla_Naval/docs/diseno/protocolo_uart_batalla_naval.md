# Protocolo UART de Batalla Naval

## Alcance

La aplicación del Jugador 2 se comunica con el programa RISC-V mediante UART a 115200 baud, 8N1. El periférico RTL transmite y recibe bytes; el parser y las reglas se ejecutan en software RISC-V. Este contrato corresponde a [constantes.s](../../src/software_riscv/constantes.s), [uart.s](../../src/software_riscv/uart.s) y [naval_terminal.py](../../src/software_pc/naval_terminal.py).

La PC no implementa las reglas de Batalla Naval. La lógica autoritativa está en el software RISC-V ejecutado en la FPGA. La terminal valida el formato de las entradas, presenta la información recibida y espera las respuestas de la FPGA.

## Formato

| Campo | Tamaño | Significado |
|---|---:|---|
| SOF | 1 byte | `0xA5` |
| TYPE | 1 byte | Tipo de mensaje |
| LENGTH | 1 byte | Número de bytes del payload |
| PAYLOAD | LENGTH bytes | Datos del mensaje |

No hay checksum ni escape de bytes. `0xA5` dentro de un payload es un dato y no reinicia una trama válida. Los bytes distintos de SOF se ignoran mientras el parser busca una cabecera. En recepción FPGA, la etapa de longitud comprueba el tipo almacenado y su tamaño esperado; una combinación inválida reinicia el parser y genera ERROR. Una trama incompleta se abandona al alcanzar `RX_EDAD_MAX=2000` iteraciones de servicio sin completar la recepción. Este umbral no es una duración fija en milisegundos.

Los campos son bytes binarios, no números escritos como texto. `LENGTH` cuenta únicamente el payload, de modo que la trama completa tiene `3 + LENGTH` bytes. No se añade CR, LF ni un terminador de string. Por ejemplo, `SHOT(row=6,col=7)` se transmite como `A5 11 02 06 07` en hexadecimal.

## Mensajes PC → FPGA

| TYPE | Nombre | LENGTH | Payload, bytes desde índice 0 | Significado |
|---|---|---:|---|---|
| `0x10` | PLACE_SHIP | 4 | `[0] ship_id`, `[1] row`, `[2] col`, `[3] orientation` | Solicitar colocación de un barco de J2 |
| `0x11` | SHOT | 2 | `[0] row`, `[1] col` | Solicitar disparo de J2 sobre el tablero de J1 |

`ship_id=0/1/2` selecciona el barco de longitud 4/3/2. Las coordenadas válidas son 0–7. `orientation=0` indica horizontal y `1` vertical. La terminal pide coordenadas 0–7 y orientación H/V, que convierte a 0/1 antes de transmitir. El programa denomina `T_PLACE` a PLACE_SHIP; no es otro tipo de mensaje.

## Mensajes FPGA → PC

| TYPE | Nombre | LENGTH | Payload, bytes desde índice 0 | Significado |
|---|---|---:|---|---|
| `0x80` | PLACE_RESULT | 3 | `[0] ship_id`, `[1] accepted`, `[2] reason` | Aceptación o rechazo de la colocación solicitada |
| `0x81` | BATTLE_START | 1 | `[0] first_player` | Anunciar que ambas flotas están completas; actualmente comienza J1 |
| `0x82` | TURN | 1 | `[0] player` | Informar a quién corresponde disparar |
| `0x83` | SHOT_RESULT | 3 | `[0] row`, `[1] col`, `[2] result` | Resultado del disparo de J2 |
| `0x84` | INCOMING_SHOT | 3 | `[0] row`, `[1] col`, `[2] result` | Disparo de J1 sobre el tablero de J2 |
| `0x85` | GAME_OVER | 7 | `[0] winner`, `[1] p1_shots`, `[2] p2_shots`, `[3] p1_sunk`, `[4] p2_sunk`, `[5] p1_wins`, `[6] p2_wins` | Ganador, estadísticas de la partida y marcador acumulado |
| `0x86` | PLACEMENT_START | 2 | `[0] p1_wins`, `[1] p2_wins` | Inicio o reinicio de colocación con marcador actual |
| `0x87` | ERROR | 2 | `[0] rejected_type`, `[1] reason` | Rechazo de una solicitud o cabecera inválida |

Los jugadores se identifican con 1 y 2. PLACE_RESULT usa `accepted=1` para aceptación y `0` para rechazo. SHOT_RESULT informa un disparo de J2; INCOMING_SHOT informa un disparo de J1. Ambos usan `result=0` agua, `1` impacto y `2` hundimiento. **Un disparo repetido se comunica mediante ERROR**, no como un cuarto resultado válido.

GAME_OVER incluye el ganador, los disparos válidos de ambos jugadores, los barcos que cada jugador hundió y el marcador acumulado. PLACEMENT_START anuncia una nueva partida y permite reiniciar el estado de la terminal conservando las victorias recibidas. Los contadores ocupan un byte en la trama; el programa limita las victorias a 99.

`p1_shots` y `p2_shots` están entre 0 y 64; `p1_sunk` y `p2_sunk` entre 0 y 3 y cuentan barcos enemigos hundidos por cada jugador. Las victorias están entre 0 y 99. La trama más larga, GAME_OVER, ocupa 10 bytes incluyendo cabecera. No contiene los tableros ni revela barcos enemigos no descubiertos.

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

PLACE_RESULT devuelve el identificador solicitado, incluso si es inválido. Una aceptación utiliza `accepted=1, reason=0`; un rechazo utiliza `accepted=0`. En ERROR, `rejected_type` conserva el tipo rechazado. Para un disparo repetido, la respuesta es `TYPE=0x87`, `LENGTH=2`, payload `11 04`; la terminal solicita otra coordenada sin descontar el turno. Una coordenada inválida usa motivo 5; un rechazo fuera de turno usa motivo 3 y la terminal espera otra notificación de turno.

## Secuencia y recuperación

Al arrancar, la terminal espera PLACEMENT_START antes de enviar el primer barco. Cada PLACE_SHIP espera PLACE_RESULT o ERROR; la terminal solo marca un barco propio después de la aceptación. Al completar ambas flotas, la FPGA encola BATTLE_START y TURN. Si la colocación de J2 completó la fase, PLACE_RESULT se encola antes de esos avisos.

La terminal envía SHOT al recibir TURN para J2 y bloquea otro disparo hasta una respuesta que permita continuar. SHOT_RESULT o INCOMING_SHOT actualizan la vista correspondiente con el resultado recibido. Un disparo válido que no termina la partida es seguido por TURN; el último produce GAME_OVER en lugar de otro turno. El estado de resultado permanece hasta GAME_RST, no hay un retorno por temporizador como en Ahorcado.

GAME_RST reinicia los tableros y el parser del programa, conserva las victorias y anuncia PLACEMENT_START. La terminal detecta ese anuncio durante colocación, batalla o espera final, reinicia sus vistas y comienza otra colocación con el marcador recibido. El reset general por SW15 reinicia el hardware y el programa inicializa las victorias a cero; no se confunde con GAME_RST.

El parser FPGA busca SOF, guarda TYPE, valida LENGTH y acumula el payload. Solo admite PLACE_SHIP con longitud 4 y SHOT con longitud 2. Un tipo o longitud inválidos generan ERROR con motivo 1 y devuelven el parser a espera de SOF. Una trama incompleta que caduca se descarta sin una respuesta a esa solicitud.

En la PC, `FrameParser` valida TYPE y LENGTH con `EXPECTED_LENGTHS`. Una cabecera inválida se descarta; si el byte que produjo el rechazo es `0xA5`, se reutiliza como inicio. El parser acepta datos fragmentados y varias tramas en una lectura. Un intervalo de al menos 0,5 s sin nuevos datos entre fragmentos reinicia la trama incompleta al procesar la siguiente lectura. Esta recuperación de la PC es distinta de las 2000 iteraciones del parser FPGA. Después de reconstruir una trama, `valid_notification` comprueba sus campos antes de modificar la interfaz.

## Acceso al periférico y límites

UART CONTROL está en `0x00010040`: bit 0 indica TX lista y bit 1 RX válida. UART TX está en `0x00010044` y UART RX en `0x00010048`. Escribir TX inicia una transmisión únicamente si está lista. Leer RX no reconoce la recepción: se escribe uno en CONTROL[1] para limpiar RX válida. Si recepción nueva y reconocimiento coinciden, se conserva el byte nuevo y su indicación válida.

Las lecturas MMIO son síncronas, con dirección antes del flanco N y captura por el CPU en N+1. Los bits superiores de TX_DATA y RX_DATA se leen como cero; STATUS no contiene `send`, contador FIFO ni errores seriales. Una escritura TX con el transmisor ocupado se ignora. Los mensajes se construyen y parsean en software, no en una FSM de protocolo dentro de UART.

El hardware RX conserva **un único byte, sin FIFO ni señal de overflow**. Un byte recibido reemplaza al anterior si no se consumió. El ciclo de servicio del programa atiende RX y distribuye el trabajo gráfico para reducir ese intervalo. La cola TX de software tiene capacidad para 192 bytes, almacenados como palabras en RAM; si está llena, `tx_encolar` descarta el byte nuevo. No debe confundirse con una FIFO hardware ni suponerse una transmisión ilimitada. Las partidas verificadas prueban el tráfico de sus guiones, no una garantía ante cualquier saturación del canal. Sin checksum, el contrato tampoco ofrece detección de todos los errores de contenido ni retransmisión automática.

## Evidencias

Las partidas con victoria J1/J2 comparan respectivamente 44 y 50 tramas con sus referencias. Las 31 pruebas de terminal comprueban longitudes, valores y recuperación del estado. Los registros y comandos están en el [informe integrado](../informe/integracion_verificacion.md).

[Diseño de la plataforma](nivel_3_uart.md) · [Índice de diseño](README.md)
