# ---------------------------------------------------------------------------
# Bloque 1 de Nivel 2: CONTROL DE ESTADO DEL JUEGO
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# partida_init
# ---------------------------------------------------------------------------
partida_init:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    li      t0, BOARD_J1
    li      t1, 128
pi_tableros:
    sw      x0, 0(t0)
    addi    t0, t0, 4
    addi    t1, t1, -1
    bnez    t1, pi_tableros

    li      t0, SHIPS_BASE
    li      t1, 48
pi_meta:
    sw      x0, 0(t0)
    addi    t0, t0, 4
    addi    t1, t1, -1
    bnez    t1, pi_meta

    li      t0, SHIPS_BASE
    li      t2, 2
pi_jugador:
    li      t3, 4
    li      t4, NUM_BARCOS
pi_barco:
    sw      t3, SH_LEN(t0)
    addi    t3, t3, -1
    addi    t0, t0, SH_TAM
    addi    t4, t4, -1
    bnez    t4, pi_barco
    addi    t2, t2, -1
    bnez    t2, pi_jugador

    li      t0, GAME_PHASE
    li      t1, FASE_COLOC
    sw      t1, 0(t0)
    li      t0, CURRENT_TURN
    li      t1, JUGADOR_1
    sw      t1, 0(t0)
    li      t0, P1_READY
    sw      x0, 0(t0)
    li      t0, P2_READY
    sw      x0, 0(t0)
    li      t0, P1_SHOTS
    sw      x0, 0(t0)
    li      t0, P2_SHOTS
    sw      x0, 0(t0)
    li      t0, P1_SUNK
    sw      x0, 0(t0)
    li      t0, P2_SUNK
    sw      x0, 0(t0)
    li      t0, WINNER
    sw      x0, 0(t0)

    li      t0, CUR_ROW
    sw      x0, 0(t0)
    li      t0, CUR_COL
    sw      x0, 0(t0)
    li      t0, J1_SHIP
    sw      x0, 0(t0)
    li      t0, J1_ORIENT
    sw      x0, 0(t0)

    li      t0, INPUTS
    lw      t1, 0(t0)
    li      t0, BTN_PREV
    sw      t1, 0(t0)

    li      t0, MSG_CODE
    li      t1, MSG_COLOCA
    sw      t1, 0(t0)

    call    uart_reset_parser
    call    msg_placement_start
    call    salidas_actualizar
    call    vga_marcar_sucio

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# servicio_botones
# ---------------------------------------------------------------------------
servicio_botones:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)

    li      t0, INPUTS
    lw      t1, 0(t0)
    li      t2, BTN_PREV
    lw      t3, 0(t2)
    sw      t1, 0(t2)

    not     t4, t3
    and     s0, t1, t4

    beqz    s0, sb_fin

    andi    t0, s0, BTN_RST
    beqz    t0, sb_por_fase
    call    partida_init
    j       sb_fin

sb_por_fase:
    li      t0, GAME_PHASE
    lw      t1, 0(t0)
    li      t2, FASE_COLOC
    bne     t1, t2, sb_batalla
    mv      a0, s0
    call    coloc_j1_flancos
    j       sb_fin

sb_batalla:
    li      t2, FASE_BATALLA
    bne     t1, t2, sb_fin
    mv      a0, s0
    call    turnos_j1_flancos

sb_fin:
    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# estado_revisar_batalla
# ---------------------------------------------------------------------------
estado_revisar_batalla:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    li      t0, GAME_PHASE
    lw      t1, 0(t0)
    li      t2, FASE_COLOC
    bne     t1, t2, erb_fin

    li      t0, P1_READY
    lw      t1, 0(t0)
    beqz    t1, erb_fin
    li      t0, P2_READY
    lw      t1, 0(t0)
    beqz    t1, erb_fin

    li      t0, GAME_PHASE
    li      t1, FASE_BATALLA
    sw      t1, 0(t0)
    li      t0, CURRENT_TURN
    li      t1, JUGADOR_1
    sw      t1, 0(t0)

    li      t0, CUR_ROW
    sw      x0, 0(t0)
    li      t0, CUR_COL
    sw      x0, 0(t0)

    li      t0, MSG_CODE
    li      t1, MSG_NADA
    sw      t1, 0(t0)

    li      a0, JUGADOR_1
    call    msg_battle_start
    li      a0, JUGADOR_1
    call    msg_turn
    call    salidas_actualizar
    call    vga_marcar_sucio

erb_fin:
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# estado_avanzar_turno
# ---------------------------------------------------------------------------
estado_avanzar_turno:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    li      t0, CURRENT_TURN
    lw      t1, 0(t0)
    li      t2, JUGADOR_1
    bne     t1, t2, eat_a_uno
    li      t1, JUGADOR_2
    j       eat_guardar
eat_a_uno:
    li      t1, JUGADOR_1
eat_guardar:
    sw      t1, 0(t0)

    mv      a0, t1
    call    msg_turn
    call    vga_marcar_sucio

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# estado_fin_partida
# ---------------------------------------------------------------------------
estado_fin_partida:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    mv      s0, a0

    li      t0, WINNER
    sw      s0, 0(t0)
    li      t0, GAME_PHASE
    li      t1, FASE_RESULT
    sw      t1, 0(t0)

    li      t0, P1_WINS
    li      t2, JUGADOR_1
    beq     s0, t2, efp_sumar
    li      t0, P2_WINS
efp_sumar:
    lw      t1, 0(t0)
    li      t2, MAX_WINS
    bge     t1, t2, efp_saturado
    addi    t1, t1, 1
    sw      t1, 0(t0)
efp_saturado:

    li      t0, MSG_CODE
    li      t1, MSG_GANA_J1
    li      t2, JUGADOR_1
    beq     s0, t2, efp_msg
    li      t1, MSG_GANA_J2
efp_msg:
    sw      t1, 0(t0)

    li      a0, SND_VICTORY
    call    salidas_buzzer
    mv      a0, s0
    call    msg_game_over
    call    salidas_actualizar
    call    vga_marcar_sucio

    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret
