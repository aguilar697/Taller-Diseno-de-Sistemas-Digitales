# ---------------------------------------------------------------------------
# Bloque 5 de Nivel 2: COMUNICACION UART
#
# Protocolo de aplicacion con la terminal de J2: SOF | TYPE | LENGTH | PAYLOAD.
# - Recepcion: un parser por estados que procesa un byte por vuelta del
#   ciclo de servicio. La UART no tiene FIFO, asi que cada byte se consume
#   en cuanto llega.
# - Transmision: los mensajes se encolan completos en una cola circular y
#   servicio_uart_tx envia un byte por vuelta cuando la UART esta lista.
# El CPU no tiene lb/sb: cada byte ocupa una palabra completa.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# uart_init
# Deja vacia la cola de transmision y el parser esperando SOF.
# Entradas: ninguna.  Salidas: ninguna.
# ---------------------------------------------------------------------------
uart_init:
    li      t0, TX_HEAD
    sw      x0, 0(t0)
    li      t0, TX_TAIL
    sw      x0, 0(t0)
    li      t0, TX_COUNT
    sw      x0, 0(t0)
    j       uart_reset_parser       # salto de cola: su ret vuelve a quien llamo

# ---------------------------------------------------------------------------
# uart_reset_parser
# Vuelve el parser de recepcion al estado de espera de SOF y descarta la
# trama en curso.
# Entradas: ninguna.  Salidas: ninguna.
# ---------------------------------------------------------------------------
uart_reset_parser:
    li      t0, RX_STATE
    li      t1, RXS_SOF
    sw      t1, 0(t0)
    li      t0, RX_COUNT
    sw      x0, 0(t0)
    li      t0, RX_AGE
    sw      x0, 0(t0)
    ret

# ---------------------------------------------------------------------------
# tx_encolar
# Agrega un byte al final de la cola circular de transmision. Si la cola
# esta llena, el byte se descarta.
# Entradas: a0 = byte (se usan solo los 8 bits bajos)
# Salidas:  ninguna.  Modifica: t0-t6, a0
# ---------------------------------------------------------------------------
tx_encolar:
    li      t0, TX_COUNT
    lw      t1, 0(t0)
    li      t2, TX_CAP
    bge     t1, t2, txe_fin         # cola llena

    # TX_QUEUE[TX_TAIL] = byte
    li      t3, TX_TAIL
    lw      t4, 0(t3)
    slli    t5, t4, 2
    li      t6, TX_QUEUE
    add     t5, t6, t5
    andi    a0, a0, 0xFF
    sw      a0, 0(t5)

    # TX_TAIL avanza y vuelve a 0 al llegar a TX_CAP; TX_COUNT + 1.
    addi    t4, t4, 1
    blt     t4, t2, txe_guardar
    li      t4, 0
txe_guardar:
    sw      t4, 0(t3)
    addi    t1, t1, 1
    sw      t1, 0(t0)
txe_fin:
    ret

# ---------------------------------------------------------------------------
# tx_cabecera
# Encola la cabecera de una trama: SOF, TYPE y LENGTH.
# Entradas: a0 = TYPE, a1 = LENGTH.  Salidas: ninguna.
# ---------------------------------------------------------------------------
tx_cabecera:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    sw      s1, 4(sp)
    mv      s0, a0                  # s0 = TYPE
    mv      s1, a1                  # s1 = LENGTH

    li      a0, SOF
    call    tx_encolar
    mv      a0, s0
    call    tx_encolar
    mv      a0, s1
    call    tx_encolar

    lw      s1, 4(sp)
    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# servicio_uart_tx
# Tarea del ciclo de servicio: si hay bytes pendientes y la UART puede
# transmitir, envia el byte del frente de la cola. Nunca espera.
# Entradas: ninguna.  Salidas: ninguna.
# ---------------------------------------------------------------------------
servicio_uart_tx:
    li      t0, TX_COUNT
    lw      t1, 0(t0)
    beqz    t1, sut_fin             # cola vacia

    li      t2, UART_CTRL
    lw      t3, 0(t2)
    andi    t3, t3, UC_TX_LISTA
    beqz    t3, sut_fin             # la UART sigue transmitiendo

    # t6 = TX_QUEUE[TX_HEAD]
    li      t3, TX_HEAD
    lw      t4, 0(t3)
    slli    t5, t4, 2
    li      t6, TX_QUEUE
    add     t5, t6, t5
    lw      t6, 0(t5)

    li      t5, UART_TX
    sw      t6, 0(t5)               # escribir TX inicia la transmision

    # TX_HEAD avanza (circular); TX_COUNT - 1.
    li      t5, TX_CAP
    addi    t4, t4, 1
    blt     t4, t5, sut_guardar
    li      t4, 0
sut_guardar:
    sw      t4, 0(t3)
    addi    t1, t1, -1
    sw      t1, 0(t0)
sut_fin:
    ret

# ---------------------------------------------------------------------------
# servicio_uart_rx
# Tarea del ciclo de servicio: si llego un byte, lo lee, lo consume y lo
# pasa al parser. Ademas, si hay una trama a medias que lleva RX_EDAD_MAX
# vueltas sin completarse, la descarta para no quedar desincronizado.
# Entradas: ninguna.  Salidas: ninguna.
# ---------------------------------------------------------------------------
servicio_uart_rx:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    li      t0, UART_CTRL
    lw      t1, 0(t0)
    andi    t2, t1, UC_RX_VALIDO
    beqz    t2, sur_edad            # no llego nada

    li      t2, UART_RX
    lw      a0, 0(t2)               # a0 = byte recibido
    li      t2, UC_RX_VALIDO
    sw      t2, 0(t0)               # consume el byte (libera el registro)
    call    uart_parser_byte

    # Edad de la trama en curso (solo si no se esta esperando SOF).
sur_edad:
    li      t0, RX_STATE
    lw      t1, 0(t0)
    li      t2, RXS_SOF
    beq     t1, t2, sur_fin

    li      t0, RX_AGE
    lw      t1, 0(t0)
    addi    t1, t1, 1
    sw      t1, 0(t0)
    li      t2, RX_EDAD_MAX
    blt     t1, t2, sur_fin
    call    uart_reset_parser       # trama abandonada

sur_fin:
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# uart_parser_byte
# Maquina de estados de recepcion. Procesa un byte:
#   RXS_SOF     -> espera 0xA5; ignora cualquier otro byte
#   RXS_TYPE    -> guarda TYPE
#   RXS_LEN     -> guarda LENGTH y revisa que coincida con el TYPE (PLACE = 4,
#                  SHOT = 2); si no, responde ERROR/INVALID_MESSAGE
#   RXS_PAYLOAD -> guarda el byte; al completar LENGTH despacha la trama
# Entradas: a0 = byte recibido.  Salidas: ninguna.
# ---------------------------------------------------------------------------
uart_parser_byte:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    andi    s0, a0, 0xFF            # s0 = byte

    li      t0, RX_STATE
    lw      t1, 0(t0)               # t1 = estado actual

    li      t2, RXS_SOF
    beq     t1, t2, upb_sof
    li      t2, RXS_TYPE
    beq     t1, t2, upb_tipo
    li      t2, RXS_LEN
    beq     t1, t2, upb_len
    j       upb_payload

upb_sof:
    li      t2, SOF
    bne     s0, t2, upb_fin         # basura entre tramas: se ignora
    li      t2, RXS_TYPE
    sw      t2, 0(t0)
    li      t0, RX_AGE
    sw      x0, 0(t0)               # empieza a contar la edad de la trama
    j       upb_fin

upb_tipo:
    li      t2, RX_TYPE
    sw      s0, 0(t2)
    li      t2, RXS_LEN
    sw      t2, 0(t0)
    j       upb_fin

upb_len:
    li      t2, RX_LEN
    sw      s0, 0(t2)
    li      t2, RX_COUNT
    sw      x0, 0(t2)

    # Solo se aceptan PLACE con LENGTH 4 y SHOT con LENGTH 2.
    li      t2, RX_TYPE
    lw      t3, 0(t2)
    li      t4, T_PLACE
    bne     t3, t4, upb_len_shot
    li      t4, LEN_PLACE
    beq     s0, t4, upb_len_ok
    j       upb_len_malo
upb_len_shot:
    li      t4, T_SHOT
    bne     t3, t4, upb_len_malo
    li      t4, LEN_SHOT
    bne     s0, t4, upb_len_malo
upb_len_ok:
    li      t2, RXS_PAYLOAD
    sw      t2, 0(t0)
    j       upb_fin

upb_len_malo:
    call    uart_reset_parser
    li      t2, RX_TYPE
    lw      a0, 0(t2)
    li      a1, ER_INVALID_MESSAGE
    call    msg_error
    j       upb_fin

upb_payload:
    # RX_PAYLOAD[RX_COUNT] = byte; RX_COUNT + 1
    li      t2, RX_COUNT
    lw      t3, 0(t2)
    slli    t4, t3, 2
    li      t5, RX_PAYLOAD
    add     t4, t5, t4
    sw      s0, 0(t4)
    addi    t3, t3, 1
    sw      t3, 0(t2)

    li      t4, RX_LEN
    lw      t5, 0(t4)
    blt     t3, t5, upb_fin         # faltan bytes

    call    uart_despachar          # trama completa
    call    uart_reset_parser

upb_fin:
    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# uart_despachar
# Ejecuta una trama completa recibida de J2:
#   PLACE -> coloc_intentar para J2 y responde PLACE_RESULT
#   SHOT  -> turnos_disparar para J2; si es invalido responde ERROR
# Si la fase no corresponde responde ERROR/WRONG_PHASE.
# Entradas: RX_TYPE y RX_PAYLOAD en RAM.  Salidas: ninguna.
# ---------------------------------------------------------------------------
uart_despachar:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    li      t0, RX_TYPE
    lw      t1, 0(t0)
    li      t2, T_PLACE
    beq     t1, t2, ud_place
    li      t2, T_SHOT
    beq     t1, t2, ud_shot
    j       ud_fin

# --- PLACE: colocacion de un barco de J2 ---
ud_place:
    li      t0, GAME_PHASE
    lw      t1, 0(t0)
    li      t2, FASE_COLOC
    beq     t1, t2, ud_place_fase_ok
    li      a0, T_PLACE
    li      a1, ER_WRONG_PHASE
    call    msg_error
    j       ud_fin

ud_place_fase_ok:
    # Payload: ship_id, fila, columna, orientacion.
    li      t0, RX_PAYLOAD
    lw      a1, 0(t0)
    lw      a2, 4(t0)
    lw      a3, 8(t0)
    lw      a4, 12(t0)
    li      a0, JUGADOR_2
    call    coloc_intentar

    # PLACE_RESULT(ship_id, aceptado, motivo): aceptado = 1 si motivo = 0.
    mv      a2, a0
    li      a1, 0
    bnez    a0, ud_place_resp
    li      a1, 1
ud_place_resp:
    li      t0, RX_PAYLOAD
    lw      a0, 0(t0)
    call    msg_place_result
    call    estado_revisar_batalla  # quizas J2 completo sus barcos
    j       ud_fin

# --- SHOT: disparo de J2 sobre el tablero de J1 ---
ud_shot:
    li      t0, GAME_PHASE
    lw      t1, 0(t0)
    li      t2, FASE_BATALLA
    beq     t1, t2, ud_shot_fase_ok
    li      a0, T_SHOT
    li      a1, ER_WRONG_PHASE
    call    msg_error
    j       ud_fin

ud_shot_fase_ok:
    # Payload: fila, columna. Si es valido, turnos_disparar ya envio
    # SHOT_RESULT; si no, se responde ERROR con su motivo.
    li      t0, RX_PAYLOAD
    lw      a1, 0(t0)
    lw      a2, 4(t0)
    li      a0, JUGADOR_2
    call    turnos_disparar
    beqz    a0, ud_fin

    mv      a1, a0
    li      a0, T_SHOT
    call    msg_error

ud_fin:
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# Constructores de mensaje. Todos encolan la trama completa y vuelven de
# inmediato; servicio_uart_tx la envia byte a byte en las vueltas siguientes.
# ---------------------------------------------------------------------------

# msg_placement_start: PLACEMENT_START(victorias J1, victorias J2).
# Entradas: ninguna (lee P1_WINS y P2_WINS).
msg_placement_start:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    li      a0, T_PLACEMENT_START
    li      a1, 2
    call    tx_cabecera
    li      t0, P1_WINS
    lw      a0, 0(t0)
    call    tx_encolar
    li      t0, P2_WINS
    lw      a0, 0(t0)
    call    tx_encolar
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# msg_battle_start: BATTLE_START(jugador que empieza).
# Entradas: a0 = jugador que empieza.
msg_battle_start:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    mv      s0, a0
    li      a0, T_BATTLE_START
    li      a1, 1
    call    tx_cabecera
    mv      a0, s0
    call    tx_encolar
    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# msg_turn: TURN(jugador con el turno).
# Entradas: a0 = jugador con el turno.
msg_turn:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    mv      s0, a0
    li      a0, T_TURN
    li      a1, 1
    call    tx_cabecera
    mv      a0, s0
    call    tx_encolar
    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# msg_place_result: PLACE_RESULT(ship_id, aceptado, motivo).
# Entradas: a0 = ship_id, a1 = aceptado (1/0), a2 = motivo (PR_*).
msg_place_result:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    mv      s0, a0
    mv      s1, a1
    mv      s2, a2
    li      a0, T_PLACE_RESULT
    li      a1, 3
    call    tx_cabecera
    mv      a0, s0
    call    tx_encolar
    mv      a0, s1
    call    tx_encolar
    mv      a0, s2
    call    tx_encolar
    lw      s2, 16(sp)
    lw      s1, 20(sp)
    lw      s0, 24(sp)
    lw      ra, 28(sp)
    addi    sp, sp, 32
    ret

# msg_shot_result: SHOT_RESULT(fila, columna, resultado) del disparo de J2.
# Entradas: a0 = fila, a1 = columna, a2 = resultado (RES_*).
msg_shot_result:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    mv      s0, a0
    mv      s1, a1
    mv      s2, a2
    li      a0, T_SHOT_RESULT
    li      a1, 3
    call    tx_cabecera
    mv      a0, s0
    call    tx_encolar
    mv      a0, s1
    call    tx_encolar
    mv      a0, s2
    call    tx_encolar
    lw      s2, 16(sp)
    lw      s1, 20(sp)
    lw      s0, 24(sp)
    lw      ra, 28(sp)
    addi    sp, sp, 32
    ret

# msg_incoming_shot: INCOMING_SHOT(fila, columna, resultado), disparo de J1
# sobre el tablero de J2.
# Entradas: a0 = fila, a1 = columna, a2 = resultado (RES_*).
msg_incoming_shot:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    mv      s0, a0
    mv      s1, a1
    mv      s2, a2
    li      a0, T_INCOMING_SHOT
    li      a1, 3
    call    tx_cabecera
    mv      a0, s0
    call    tx_encolar
    mv      a0, s1
    call    tx_encolar
    mv      a0, s2
    call    tx_encolar
    lw      s2, 16(sp)
    lw      s1, 20(sp)
    lw      s0, 24(sp)
    lw      ra, 28(sp)
    addi    sp, sp, 32
    ret

# msg_error: ERROR(tipo de la trama rechazada, motivo).
# Entradas: a0 = TYPE de la trama rechazada, a1 = motivo (ER_*).
msg_error:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    sw      s1, 4(sp)
    mv      s0, a0
    mv      s1, a1
    li      a0, T_ERROR
    li      a1, 2
    call    tx_cabecera
    mv      a0, s0
    call    tx_encolar
    mv      a0, s1
    call    tx_encolar
    lw      s1, 4(sp)
    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# msg_game_over: GAME_OVER(ganador, disparos J1, disparos J2, hundidos J1,
# hundidos J2, victorias J1, victorias J2).
# Entradas: a0 = ganador (el resto se lee de RAM).
msg_game_over:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    mv      s0, a0

    li      a0, T_GAME_OVER
    li      a1, 7
    call    tx_cabecera

    mv      a0, s0
    call    tx_encolar
    li      t0, P1_SHOTS
    lw      a0, 0(t0)
    call    tx_encolar
    li      t0, P2_SHOTS
    lw      a0, 0(t0)
    call    tx_encolar
    li      t0, P1_SUNK
    lw      a0, 0(t0)
    call    tx_encolar
    li      t0, P2_SUNK
    lw      a0, 0(t0)
    call    tx_encolar
    li      t0, P1_WINS
    lw      a0, 0(t0)
    call    tx_encolar
    li      t0, P2_WINS
    lw      a0, 0(t0)
    call    tx_encolar

    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret
