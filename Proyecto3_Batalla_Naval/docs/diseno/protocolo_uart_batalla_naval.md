# Protocolo UART de Batalla Naval

## 1. Alcance

La aplicación del Jugador 2 se comunica con el programa RISC-V de la FPGA mediante UART. La UART física trabaja a 115200 baud en formato 8N1. El análisis de las tramas y todas las reglas de Batalla Naval se ejecutan en software RISC-V; no se utiliza un `protocol_controller` en hardware.

## 2. Formato de trama

Cada trama utiliza el siguiente formato:

| Campo | Tamaño | Descripción |
|---|---:|---|
| `SOF` | 1 byte | Inicio de trama, siempre `0xA5` |
| `TYPE` | 1 byte | Tipo de mensaje |
| `LENGTH` | 1 byte | Cantidad de bytes del payload |
| `PAYLOAD` | `LENGTH` bytes | Datos del mensaje |

No se incluye checksum. Cuando el receptor espera `SOF`, descarta cualquier byte diferente de `0xA5`. Si `TYPE` no está definido o `LENGTH` no coincide con el tipo, se descarta la trama y se vuelve a buscar un nuevo `SOF`.

## 3. Mensajes PC → FPGA

### `0x10` — `PLACE_SHIP`

Solicita la colocación de un barco. `LENGTH = 4`.

| Byte | Campo | Valores |
|---:|---|---|
| 0 | `ship_id` | `0`: barco de 4, `1`: barco de 3, `2`: barco de 2 |
| 1 | `row` | 0–7 |
| 2 | `col` | 0–7 |
| 3 | `orientation` | `0`: horizontal, `1`: vertical |

### `0x11` — `SHOT`

Solicita un disparo del Jugador 2. `LENGTH = 2`.

| Byte | Campo | Valores |
|---:|---|---|
| 0 | `row` | 0–7 |
| 1 | `col` | 0–7 |

## 4. Mensajes FPGA → PC

### `0x80` — `PLACE_RESULT`

Informa el resultado de una colocación. `LENGTH = 3`.

| Byte | Campo | Valores |
|---:|---|---|
| 0 | `ship_id` | Identificador solicitado |
| 1 | `accepted` | `0`: rechazado, `1`: aceptado |
| 2 | `reason` | `0`: OK, `1`: overlap, `2`: out_of_bounds, `3`: invalid_data |

### `0x81` — `BATTLE_START`

Indica el inicio de la batalla. No tiene payload y utiliza `LENGTH = 0`.

### `0x82` — `TURN`

Indica el jugador que puede actuar. `LENGTH = 1`.

| Byte | Campo | Valores |
|---:|---|---|
| 0 | `player` | `1`: Jugador 1, `2`: Jugador 2 |

### `0x83` — `SHOT_RESULT`

Resultado de un disparo realizado por el Jugador 2. `LENGTH = 3`.

| Byte | Campo | Valores |
|---:|---|---|
| 0 | `row` | 0–7 |
| 1 | `col` | 0–7 |
| 2 | `result` | `0`: miss, `1`: hit, `2`: sunk, `3`: repeated |

### `0x84` — `INCOMING_SHOT`

Resultado de un disparo del Jugador 1 contra el Jugador 2. `LENGTH = 3`.

| Byte | Campo | Valores |
|---:|---|---|
| 0 | `row` | 0–7 |
| 1 | `col` | 0–7 |
| 2 | `result` | `0`: miss, `1`: hit, `2`: sunk |

### `0x85` — `GAME_OVER`

Informa el resultado final. `LENGTH = 3`.

| Byte | Campo | Valores |
|---:|---|---|
| 0 | `winner` | `1`: Jugador 1, `2`: Jugador 2 |
| 1 | `p1_shots` | Disparos realizados por J1 |
| 2 | `p2_shots` | Disparos realizados por J2 |

## 5. Responsabilidades

La aplicación de PC valida únicamente el formato de entrada, muestra los tableros y envía solicitudes. La FPGA y su programa RISC-V deciden si una colocación es válida, el resultado de cada disparo, los cambios de turno y el ganador.
