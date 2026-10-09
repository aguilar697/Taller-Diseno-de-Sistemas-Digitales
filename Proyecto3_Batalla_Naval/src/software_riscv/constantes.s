# ---------------------------------------------------------------------------
# Constantes del programa de Batalla Naval (Persona 4)
#
# Solo define nombres (.equ); no genera instrucciones ni datos. Todos los
# demas archivos usan estos nombres en lugar de numeros sueltos.
# ---------------------------------------------------------------------------

# --- Mapa de memoria: RAM de datos -----------------------------------------
# Tableros de 8x8 casillas, una palabra por casilla:
#   direccion = BOARD_Jx + 4*(fila*8 + columna)
.equ BOARD_J1,      0x00002000
.equ BOARD_J2,      0x00002100
# Variables de estado de la partida (una palabra cada una)
.equ GAME_PHASE,    0x00002200      # FASE_COLOC / FASE_BATALLA / FASE_RESULT
.equ CURRENT_TURN,  0x00002204      # JUGADOR_1 o JUGADOR_2
.equ P1_READY,      0x00002208      # 1 cuando J1 coloco sus 3 barcos
.equ P2_READY,      0x0000220C      # 1 cuando J2 coloco sus 3 barcos
.equ P1_WINS,       0x00002210      # partidas ganadas por J1 (0..99)
.equ P2_WINS,       0x00002214      # partidas ganadas por J2 (0..99)
.equ P1_SHOTS,      0x00002218      # disparos de J1 en la partida
.equ P2_SHOTS,      0x0000221C      # disparos de J2 en la partida
# Metadata de los barcos: 6 registros de 32 bytes (3 de J1 y luego 3 de J2)
.equ SHIPS_BASE,    0x00002220

# Desplazamientos dentro del registro de un barco
.equ SH_PLACED,     0               # 1 si ya esta colocado
.equ SH_ROW,        4               # fila de la proa
.equ SH_COL,        8               # columna de la proa
.equ SH_ORIENT,     12              # ORIENT_H u ORIENT_V
.equ SH_LEN,        16              # longitud: 4, 3 o 2
.equ SH_HITS,       20              # impactos recibidos
.equ SH_SUNK,       24              # 1 si ya se hundio
.equ SH_RESERVADO,  28
.equ SH_TAM,        32              # tamano del registro

# --- Variables auxiliares (0x22E0 - 0x23FF) --------------------------------
.equ CUR_ROW,       0x000022E0      # fila del cursor de J1
.equ CUR_COL,       0x000022E4      # columna del cursor de J1
.equ J1_SHIP,       0x000022E8      # siguiente barco que coloca J1 (0..3)
.equ J1_ORIENT,     0x000022EC      # orientacion elegida por J1
.equ BTN_PREV,      0x000022F0      # lectura anterior de INPUTS (flancos)
.equ P1_SUNK,       0x000022F4      # barcos que hundio J1
.equ P2_SUNK,       0x000022F8      # barcos que hundio J2
.equ WINNER,        0x000022FC      # ganador de la partida (0 = ninguno)
.equ MSG_CODE,      0x00002300      # mensaje de la fila inferior (MSG_*)
.equ LAST_ROW,      0x00002304      # ultimo disparo: fila
.equ LAST_COL,      0x00002308      # ultimo disparo: columna
.equ LAST_RES,      0x0000230C      # ultimo disparo: RES_*
.equ VGA_DIRTY,     0x00002310      # 1 = hay que redibujar la pantalla
.equ VGA_PASO,      0x00002314      # paso actual del redibujado (-1 = empezar)

# --- Estado del protocolo UART (0x2400 - 0x27FF) ---------------------------
.equ RX_STATE,      0x00002400      # estado del parser (RXS_*)
.equ RX_TYPE,       0x00002404      # TYPE de la trama en curso
.equ RX_LEN,        0x00002408      # LENGTH de la trama en curso
.equ RX_COUNT,      0x0000240C      # bytes de payload recibidos
.equ RX_AGE,        0x00002410      # vueltas sin terminar la trama
.equ RX_PAYLOAD,    0x00002420      # payload, un byte por palabra
.equ TX_HEAD,       0x00002440      # cola circular de TX: indice de lectura
.equ TX_TAIL,       0x00002444      # indice de escritura
.equ TX_COUNT,      0x00002448      # bytes pendientes
.equ TX_QUEUE,      0x00002500      # bytes de la cola, uno por palabra
.equ TX_CAP,        192             # capacidad de la cola en bytes

.equ RX_EDAD_MAX,   2000            # vueltas antes de descartar una trama a medias
.equ ESPERA_ARRANQUE, 120000        # iteraciones de la espera inicial

# Estados del parser de recepcion
.equ RXS_SOF,       0               # esperando 0xA5
.equ RXS_TYPE,      1               # esperando TYPE
.equ RXS_LEN,       2               # esperando LENGTH
.equ RXS_PAYLOAD,   3               # recibiendo el payload

# --- Perifericos -----------------------------------------------------------
.equ UART_CTRL,     0x00010040
.equ UART_TX,       0x00010044
.equ UART_RX,       0x00010048
.equ INPUTS,        0x00010120
.equ DISPLAY,       0x00010130
.equ LED,           0x00010138
.equ BUZZER,        0x00010140
.equ VGA_BASE,      0x00011000      # memoria de tiles 20x15

# Bits de UART_CTRL
.equ UC_TX_LISTA,   1               # lectura: se puede transmitir
.equ UC_RX_VALIDO,  2               # lectura: hay byte; escritura: consumirlo

# Bits de INPUTS (activos en alto)
.equ BTN_UP,        1
.equ BTN_DOWN,      2
.equ BTN_LEFT,      4
.equ BTN_RIGHT,     8
.equ BTN_SEL,       16
.equ BTN_OK,        32
.equ BTN_RST,       64

# Codigos de sonido del buzzer
.equ SND_OFF,       0
.equ SND_HIT,       1
.equ SND_MISS,      2
.equ SND_SUNK,      3
.equ SND_INVALID,   4
.equ SND_VICTORY,   5

# --- Estado del juego ------------------------------------------------------
.equ FASE_COLOC,    0
.equ FASE_BATALLA,  1
.equ FASE_RESULT,   2

.equ JUGADOR_1,     1
.equ JUGADOR_2,     2

# Valores de una casilla del tablero
.equ CASILLA_AGUA,  0
.equ CASILLA_BARCO, 1
.equ CASILLA_FALLO, 2
.equ CASILLA_HIT,   3

.equ ORIENT_H,      0
.equ ORIENT_V,      1

.equ TABLERO_N,     8
.equ NUM_BARCOS,    3
.equ MAX_WINS,      99              # limite del marcador (dos digitos)

# --- Protocolo de aplicacion -----------------------------------------------
# Trama: SOF | TYPE | LENGTH | PAYLOAD
.equ SOF,           0xA5
.equ T_PLACE,           0x10        # PC -> FPGA
.equ T_SHOT,            0x11        # PC -> FPGA
.equ T_PLACE_RESULT,    0x80        # FPGA -> PC
.equ T_BATTLE_START,    0x81
.equ T_TURN,            0x82
.equ T_SHOT_RESULT,     0x83
.equ T_INCOMING_SHOT,   0x84
.equ T_GAME_OVER,       0x85
.equ T_PLACEMENT_START, 0x86
.equ T_ERROR,           0x87

.equ LEN_PLACE,     4               # ship_id, fila, columna, orientacion
.equ LEN_SHOT,      2               # fila, columna

# Motivos de PLACE_RESULT
.equ PR_OK,                 0
.equ PR_OVERLAP,            1
.equ PR_OUT_OF_BOUNDS,      2
.equ PR_INVALID_SHIP,       3
.equ PR_ALREADY_PLACED,     4
.equ PR_INVALID_ORIENTATION, 5

# Motivos de ERROR
.equ ER_INVALID_MESSAGE,    1
.equ ER_WRONG_PHASE,        2
.equ ER_WRONG_TURN,         3
.equ ER_REPEATED_SHOT,      4
.equ ER_INVALID_COORDINATE, 5

# Resultado de un disparo
.equ RES_MISS,      0
.equ RES_HIT,       1
.equ RES_SUNK,      2

# --- Distribucion de la pantalla VGA (acuerdo con Persona 2) ---------------
.equ VGA_COLS,      20
.equ VGA_FILAS,     15
.equ TAB_FILA,      4               # fila de pantalla de la fila 0 del tablero
.equ TAB_COL_PROPIO, 1              # columna de pantalla del tablero de J1
.equ TAB_COL_RIVAL, 11              # columna de pantalla del tablero de J2
.equ FILA_MSG,      13              # fila del mensaje inferior

# Colores de un tile (bits [2:0])
.equ COL_FONDO,     0
.equ COL_AGUA,      1
.equ COL_BARCO,     2
.equ COL_IMPACTO,   3
.equ COL_FALLO,     4
.equ COL_CURSOR,    5
.equ COL_HUD,       6

.equ GLYPH_EN,      8               # bit 3: el tile muestra un caracter

# Mensajes de la fila inferior (valor de MSG_CODE)
.equ MSG_NADA,      0
.equ MSG_COLOCA,    1
.equ MSG_IMPACTO,   2
.equ MSG_FALLO,     3
.equ MSG_HUNDIDO,   4
.equ MSG_INVALIDO,  5
.equ MSG_GANA_J1,   6
.equ MSG_GANA_J2,   7
.equ MSG_ESPERA,    8

.equ PILA_INICIO,   0x00003000
