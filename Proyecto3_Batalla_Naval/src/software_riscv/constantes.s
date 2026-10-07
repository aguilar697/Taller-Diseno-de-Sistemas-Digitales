# ---------------------------------------------------------------------------
# Constantes del programa de Batalla Naval (Persona 4)
# ---------------------------------------------------------------------------

# --- Mapa de memoria: RAM de datos -----------------------------------------
.equ BOARD_J1,      0x00002000
.equ BOARD_J2,      0x00002100
.equ GAME_PHASE,    0x00002200
.equ CURRENT_TURN,  0x00002204
.equ P1_READY,      0x00002208
.equ P2_READY,      0x0000220C
.equ P1_WINS,       0x00002210
.equ P2_WINS,       0x00002214
.equ P1_SHOTS,      0x00002218
.equ P2_SHOTS,      0x0000221C
.equ SHIPS_BASE,    0x00002220

.equ SH_PLACED,     0
.equ SH_ROW,        4
.equ SH_COL,        8
.equ SH_ORIENT,     12
.equ SH_LEN,        16
.equ SH_HITS,       20
.equ SH_SUNK,       24
.equ SH_RESERVADO,  28
.equ SH_TAM,        32

# --- Variables auxiliares (0x22E0 - 0x23FF) --------------------------------
.equ CUR_ROW,       0x000022E0
.equ CUR_COL,       0x000022E4
.equ J1_SHIP,       0x000022E8
.equ J1_ORIENT,     0x000022EC
.equ BTN_PREV,      0x000022F0
.equ P1_SUNK,       0x000022F4
.equ P2_SUNK,       0x000022F8
.equ WINNER,        0x000022FC
.equ MSG_CODE,      0x00002300
.equ LAST_ROW,      0x00002304
.equ LAST_COL,      0x00002308
.equ LAST_RES,      0x0000230C
.equ VGA_DIRTY,     0x00002310
.equ VGA_PASO,      0x00002314

# --- Estado del protocolo UART (0x2400 - 0x27FF) ---------------------------
.equ RX_STATE,      0x00002400
.equ RX_TYPE,       0x00002404
.equ RX_LEN,        0x00002408
.equ RX_COUNT,      0x0000240C
.equ RX_AGE,        0x00002410
.equ RX_PAYLOAD,    0x00002420
.equ TX_HEAD,       0x00002440
.equ TX_TAIL,       0x00002444
.equ TX_COUNT,      0x00002448
.equ TX_QUEUE,      0x00002500
.equ TX_CAP,        192

.equ RX_EDAD_MAX,   2000

.equ RXS_SOF,       0
.equ RXS_TYPE,      1
.equ RXS_LEN,       2
.equ RXS_PAYLOAD,   3

# --- Perifericos -----------------------------------------------------------
.equ UART_CTRL,     0x00010040
.equ UART_TX,       0x00010044
.equ UART_RX,       0x00010048
.equ INPUTS,        0x00010120
.equ DISPLAY,       0x00010130
.equ LED,           0x00010138
.equ BUZZER,        0x00010140
.equ VGA_BASE,      0x00011000

.equ UC_TX_LISTA,   1
.equ UC_RX_VALIDO,  2

.equ BTN_UP,        1
.equ BTN_DOWN,      2
.equ BTN_LEFT,      4
.equ BTN_RIGHT,     8
.equ BTN_SEL,       16
.equ BTN_OK,        32
.equ BTN_RST,       64

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

.equ CASILLA_AGUA,  0
.equ CASILLA_BARCO, 1
.equ CASILLA_FALLO, 2
.equ CASILLA_HIT,   3

.equ ORIENT_H,      0
.equ ORIENT_V,      1

.equ TABLERO_N,     8
.equ NUM_BARCOS,    3
.equ MAX_WINS,      99

# --- Protocolo de aplicacion -----------------------------------------------
.equ SOF,           0xA5
.equ T_PLACE,           0x10
.equ T_SHOT,            0x11
.equ T_PLACE_RESULT,    0x80
.equ T_BATTLE_START,    0x81
.equ T_TURN,            0x82
.equ T_SHOT_RESULT,     0x83
.equ T_INCOMING_SHOT,   0x84
.equ T_GAME_OVER,       0x85
.equ T_PLACEMENT_START, 0x86
.equ T_ERROR,           0x87

.equ LEN_PLACE,     4
.equ LEN_SHOT,      2

.equ PR_OK,                 0
.equ PR_OVERLAP,            1
.equ PR_OUT_OF_BOUNDS,      2
.equ PR_INVALID_SHIP,       3
.equ PR_ALREADY_PLACED,     4
.equ PR_INVALID_ORIENTATION, 5

.equ ER_INVALID_MESSAGE,    1
.equ ER_WRONG_PHASE,        2
.equ ER_WRONG_TURN,         3
.equ ER_REPEATED_SHOT,      4
.equ ER_INVALID_COORDINATE, 5

.equ RES_MISS,      0
.equ RES_HIT,       1
.equ RES_SUNK,      2

# --- Distribucion de la pantalla VGA (acuerdo con Persona 2) ---------------
.equ VGA_COLS,      20
.equ VGA_FILAS,     15
.equ TAB_FILA,      4
.equ TAB_COL_PROPIO, 1
.equ TAB_COL_RIVAL, 11
.equ FILA_MSG,      13

.equ COL_FONDO,     0
.equ COL_AGUA,      1
.equ COL_BARCO,     2
.equ COL_IMPACTO,   3
.equ COL_FALLO,     4
.equ COL_CURSOR,    5
.equ COL_HUD,       6

.equ GLYPH_EN,      8

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
