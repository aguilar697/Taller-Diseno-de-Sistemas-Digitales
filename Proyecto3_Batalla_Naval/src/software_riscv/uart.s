# ---------------------------------------------------------------------------
# Bloque 5 de Nivel 2: COMUNICACION UART
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# uart_init
# ---------------------------------------------------------------------------
uart_init:
    li      t0, TX_HEAD
    sw      x0, 0(t0)
    li      t0, TX_TAIL
    sw      x0, 0(t0)
    li      t0, TX_COUNT
    sw      x0, 0(t0)
    j       uart_reset_parser

# ---------------------------------------------------------------------------
# uart_reset_parser
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
# ---------------------------------------------------------------------------
tx_encolar:
    li      t0, TX_COUNT
    lw      t1, 0(t0)
    li      t2, TX_CAP
    bge     t1, t2, txe_fin

    li      t3, TX_TAIL
    lw      t4, 0(t3)
    slli    t5, t4, 2
    li      t6, TX_QUEUE
    add     t5, t6, t5
    andi    a0, a0, 0xFF
    sw      a0, 0(t5)

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
# ---------------------------------------------------------------------------
tx_cabecera:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    sw      s1, 4(sp)
    mv      s0, a0
    mv      s1, a1

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
# ---------------------------------------------------------------------------
servicio_uart_tx:
    li      t0, TX_COUNT
    lw      t1, 0(t0)
    beqz    t1, sut_fin

    li      t2, UART_CTRL
    lw      t3, 0(t2)
    andi    t3, t3, UC_TX_LISTA
    beqz    t3, sut_fin

    li      t3, TX_HEAD
    lw      t4, 0(t3)
    slli    t5, t4, 2
    li      t6, TX_QUEUE
    add     t5, t6, t5
    lw      t6, 0(t5)

    li      t5, UART_TX
    sw      t6, 0(t5)

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
# ---------------------------------------------------------------------------
servicio_uart_rx:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    li      t0, UART_CTRL
    lw      t1, 0(t0)
    andi    t2, t1, UC_RX_VALIDO
    beqz    t2, sur_edad

    li      t2, UART_RX
    lw      a0, 0(t2)
    li      t2, UC_RX_VALIDO
    sw      t2, 0(t0)
    call    uart_parser_byte

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
    call    uart_reset_parser

sur_fin:
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# uart_parser_byte
# ---------------------------------------------------------------------------
uart_parser_byte:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    andi    s0, a0, 0xFF

    li      t0, RX_STATE
    lw      t1, 0(t0)

    li      t2, RXS_SOF
    beq     t1, t2, upb_sof
    li      t2, RXS_TYPE
    beq     t1, t2, upb_tipo
    li      t2, RXS_LEN
    beq     t1, t2, upb_len
    j       upb_payload

upb_sof:
    li      t2, SOF
    bne     s0, t2, upb_fin
    li      t2, RXS_TYPE
    sw      t2, 0(t0)
    li      t0, RX_AGE
    sw      x0, 0(t0)
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
    blt     t3, t5, upb_fin

    call    uart_despachar
    call    uart_reset_parser

upb_fin:
    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# uart_despachar
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
    li      t0, RX_PAYLOAD
    lw      a1, 0(t0)
    lw      a2, 4(t0)
    lw      a3, 8(t0)
    lw      a4, 12(t0)
    li      a0, JUGADOR_2
    call    coloc_intentar

    mv      a2, a0
    li      a1, 0
    bnez    a0, ud_place_resp
    li      a1, 1
ud_place_resp:
    li      t0, RX_PAYLOAD
    lw      a0, 0(t0)
    call    msg_place_result
    call    estado_revisar_batalla
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
# Constructores de mensaje: encolan la trama completa sin esperar la transmision.
# ---------------------------------------------------------------------------

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
