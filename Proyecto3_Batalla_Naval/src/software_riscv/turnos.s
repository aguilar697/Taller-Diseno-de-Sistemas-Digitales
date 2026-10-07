# ---------------------------------------------------------------------------
# Bloque 3 de Nivel 2: GESTION DE TURNOS Y DISPAROS
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# turnos_disparar
# ---------------------------------------------------------------------------
turnos_disparar:
    addi    sp, sp, -48
    sw      ra, 44(sp)
    sw      s0, 40(sp)
    sw      s1, 36(sp)
    sw      s2, 32(sp)
    sw      s3, 28(sp)
    sw      s4, 24(sp)
    sw      s5, 20(sp)
    mv      s0, a0
    mv      s1, a1
    mv      s2, a2

    li      t0, GAME_PHASE
    lw      t1, 0(t0)
    li      t2, FASE_BATALLA
    beq     t1, t2, td_turno
    li      a0, ER_WRONG_PHASE
    j       td_fin

td_turno:
    li      t0, CURRENT_TURN
    lw      t1, 0(t0)
    beq     t1, s0, td_coords
    li      a0, ER_WRONG_TURN
    j       td_fin

td_coords:
    li      t0, TABLERO_N
    sltu    t1, s1, t0
    beqz    t1, td_coord_mala
    sltu    t1, s2, t0
    bnez    t1, td_objetivo
td_coord_mala:
    li      a0, ER_INVALID_COORDINATE
    j       td_fin

td_objetivo:
    li      t0, JUGADOR_1
    li      s3, JUGADOR_2
    beq     s0, t0, td_rival_listo
    mv      s3, t0
td_rival_listo:
    mv      a0, s3
    call    tablero_dir
    mv      a1, s1
    mv      a2, s2
    call    casilla_dir
    mv      s4, a0

    lw      t0, 0(s4)
    li      t1, CASILLA_FALLO
    blt     t0, t1, td_aplicar
    li      a0, ER_REPEATED_SHOT
    j       td_fin

td_aplicar:
    li      t1, CASILLA_BARCO
    beq     t0, t1, td_impacto
    li      t2, CASILLA_FALLO
    sw      t2, 0(s4)
    li      s5, RES_MISS
    j       td_contar

td_impacto:
    li      t2, CASILLA_HIT
    sw      t2, 0(s4)
    li      s5, RES_HIT
    mv      a0, s3
    mv      a1, s1
    mv      a2, s2
    call    victoria_registrar_impacto
    beqz    a0, td_contar
    li      s5, RES_SUNK
    li      t0, P1_SUNK
    li      t1, JUGADOR_1
    beq     s0, t1, td_sunk_dir
    li      t0, P2_SUNK
td_sunk_dir:
    lw      t2, 0(t0)
    addi    t2, t2, 1
    sw      t2, 0(t0)

td_contar:
    li      t0, P1_SHOTS
    li      t1, JUGADOR_1
    beq     s0, t1, td_shots_dir
    li      t0, P2_SHOTS
td_shots_dir:
    lw      t2, 0(t0)
    addi    t2, t2, 1
    sw      t2, 0(t0)

    li      t0, LAST_ROW
    sw      s1, 0(t0)
    li      t0, LAST_COL
    sw      s2, 0(t0)
    li      t0, LAST_RES
    sw      s5, 0(t0)

    li      t0, MSG_CODE
    li      t1, MSG_FALLO
    li      t2, RES_MISS
    beq     s5, t2, td_msg_guardar
    li      t1, MSG_IMPACTO
    li      t2, RES_HIT
    beq     s5, t2, td_msg_guardar
    li      t1, MSG_HUNDIDO
td_msg_guardar:
    sw      t1, 0(t0)

    mv      a0, s1
    mv      a1, s2
    mv      a2, s5
    li      t0, JUGADOR_1
    beq     s0, t0, td_notif_j1
    call    msg_shot_result
    j       td_victoria
td_notif_j1:
    call    msg_incoming_shot

td_victoria:
    mv      a0, s0
    call    victoria_revisar
    beqz    a0, td_sigue

    mv      a0, s0
    call    estado_fin_partida
    j       td_ok

td_sigue:
    li      a0, SND_MISS
    li      t0, RES_MISS
    beq     s5, t0, td_sonar
    li      a0, SND_HIT
    li      t0, RES_HIT
    beq     s5, t0, td_sonar
    li      a0, SND_SUNK
td_sonar:
    call    salidas_buzzer
    call    estado_avanzar_turno

td_ok:
    call    vga_marcar_sucio
    li      a0, 0
    mv      a1, s5

td_fin:
    lw      s5, 20(sp)
    lw      s4, 24(sp)
    lw      s3, 28(sp)
    lw      s2, 32(sp)
    lw      s1, 36(sp)
    lw      s0, 40(sp)
    lw      ra, 44(sp)
    addi    sp, sp, 48
    ret

# ---------------------------------------------------------------------------
# turnos_j1_flancos
# ---------------------------------------------------------------------------
turnos_j1_flancos:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    mv      s0, a0

    mv      a0, s0
    call    cursor_mover

    andi    t0, s0, BTN_OK
    beqz    t0, tjf_fin

    li      t0, CUR_ROW
    lw      a1, 0(t0)
    li      t0, CUR_COL
    lw      a2, 0(t0)
    li      a0, JUGADOR_1
    call    turnos_disparar
    beqz    a0, tjf_fin

    li      a0, SND_INVALID
    call    salidas_buzzer

tjf_fin:
    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret
