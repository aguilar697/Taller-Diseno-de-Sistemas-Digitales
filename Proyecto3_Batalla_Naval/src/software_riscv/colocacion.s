# ---------------------------------------------------------------------------
# Bloque 2 de Nivel 2: GESTION DE COLOCACION DE BARCOS
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# barco_dir
# ---------------------------------------------------------------------------
barco_dir:
    addi    t0, a0, -1
    add     t2, t0, t0
    add     t2, t2, t0
    add     t2, t2, a1
    slli    t2, t2, 5
    li      t3, SHIPS_BASE
    add     a0, t3, t2
    ret

# ---------------------------------------------------------------------------
# tablero_dir
# ---------------------------------------------------------------------------
tablero_dir:
    li      t0, JUGADOR_1
    li      t1, BOARD_J1
    beq     a0, t0, tdir_fin
    li      t1, BOARD_J2
tdir_fin:
    mv      a0, t1
    ret

# ---------------------------------------------------------------------------
# casilla_dir
# ---------------------------------------------------------------------------
casilla_dir:
    slli    t0, a1, 3
    add     t0, t0, a2
    slli    t0, t0, 2
    add     a0, a0, t0
    ret

# ---------------------------------------------------------------------------
# coloc_validar
# ---------------------------------------------------------------------------
coloc_validar:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    sw      s3, 12(sp)
    sw      s4, 8(sp)
    mv      s0, a0
    mv      s1, a1
    mv      s2, a2
    mv      s3, a3
    mv      s4, a4

    li      t0, NUM_BARCOS
    sltu    t1, s1, t0
    bnez    t1, cv_orient
    li      a0, PR_INVALID_SHIP
    j       cv_fin

cv_orient:
    li      t0, 2
    sltu    t1, s4, t0
    bnez    t1, cv_placed
    li      a0, PR_INVALID_ORIENTATION
    j       cv_fin

cv_placed:
    mv      a0, s0
    mv      a1, s1
    call    barco_dir
    lw      t0, SH_PLACED(a0)
    beqz    t0, cv_limites
    li      a0, PR_ALREADY_PLACED
    j       cv_fin

cv_limites:
    li      t0, TABLERO_N
    sltu    t1, s2, t0
    beqz    t1, cv_fuera
    sltu    t1, s3, t0
    beqz    t1, cv_fuera

    mv      a0, s0
    mv      a1, s1
    call    barco_dir
    lw      t2, SH_LEN(a0)
    li      t3, ORIENT_H
    beq     s4, t3, cv_horizontal
    add     t4, s2, t2
    j       cv_extremo
cv_horizontal:
    add     t4, s3, t2
cv_extremo:
    li      t5, TABLERO_N
    addi    t5, t5, 1
    sltu    t6, t4, t5
    bnez    t6, cv_traslape
cv_fuera:
    li      a0, PR_OUT_OF_BOUNDS
    j       cv_fin

cv_traslape:
    mv      a0, s0
    mv      a1, s1
    call    barco_dir
    lw      t5, SH_LEN(a0)

    mv      a0, s0
    call    tablero_dir
    mv      a1, s2
    mv      a2, s3
    call    casilla_dir
    mv      t0, a0

    li      t1, 4
    li      t2, ORIENT_H
    beq     s4, t2, cv_paso_listo
    li      t1, 32
cv_paso_listo:
    mv      t2, t5

cv_bucle:
    lw      t3, 0(t0)
    beqz    t3, cv_siguiente
    li      a0, PR_OVERLAP
    j       cv_fin
cv_siguiente:
    add     t0, t0, t1
    addi    t2, t2, -1
    bnez    t2, cv_bucle

    li      a0, PR_OK

cv_fin:
    lw      s4, 8(sp)
    lw      s3, 12(sp)
    lw      s2, 16(sp)
    lw      s1, 20(sp)
    lw      s0, 24(sp)
    lw      ra, 28(sp)
    addi    sp, sp, 32
    ret

# ---------------------------------------------------------------------------
# coloc_aplicar
# ---------------------------------------------------------------------------
coloc_aplicar:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    sw      s3, 12(sp)
    sw      s4, 8(sp)
    mv      s0, a0
    mv      s1, a1
    mv      s2, a2
    mv      s3, a3
    mv      s4, a4

    mv      a0, s0
    mv      a1, s1
    call    barco_dir
    mv      t4, a0
    lw      t5, SH_LEN(t4)

    mv      a0, s0
    call    tablero_dir
    mv      a1, s2
    mv      a2, s3
    call    casilla_dir
    mv      t0, a0

    li      t1, 4
    li      t2, ORIENT_H
    beq     s4, t2, ca_paso_listo
    li      t1, 32
ca_paso_listo:
    mv      t2, t5
    li      t3, CASILLA_BARCO
ca_bucle:
    sw      t3, 0(t0)
    add     t0, t0, t1
    addi    t2, t2, -1
    bnez    t2, ca_bucle

    li      t0, 1
    sw      t0, SH_PLACED(t4)
    sw      s2, SH_ROW(t4)
    sw      s3, SH_COL(t4)
    sw      s4, SH_ORIENT(t4)
    sw      x0, SH_HITS(t4)
    sw      x0, SH_SUNK(t4)

    lw      s4, 8(sp)
    lw      s3, 12(sp)
    lw      s2, 16(sp)
    lw      s1, 20(sp)
    lw      s0, 24(sp)
    lw      ra, 28(sp)
    addi    sp, sp, 32
    ret

# ---------------------------------------------------------------------------
# coloc_actualizar_ready
# ---------------------------------------------------------------------------
coloc_actualizar_ready:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    mv      s0, a0

    mv      a0, s0
    li      a1, 0
    call    barco_dir
    mv      t0, a0
    li      t1, NUM_BARCOS
    li      t2, 1
car_bucle:
    lw      t3, SH_PLACED(t0)
    bnez    t3, car_siguiente
    li      t2, 0
car_siguiente:
    addi    t0, t0, SH_TAM
    addi    t1, t1, -1
    bnez    t1, car_bucle

    li      t0, P1_READY
    li      t3, JUGADOR_1
    beq     s0, t3, car_guardar
    li      t0, P2_READY
car_guardar:
    sw      t2, 0(t0)

    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# coloc_intentar
# ---------------------------------------------------------------------------
coloc_intentar:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    sw      s3, 12(sp)
    sw      s4, 8(sp)
    mv      s0, a0
    mv      s1, a1
    mv      s2, a2
    mv      s3, a3
    mv      s4, a4

    li      t0, GAME_PHASE
    lw      t1, 0(t0)
    li      t2, FASE_COLOC
    beq     t1, t2, ci_validar
    li      a0, PR_ALREADY_PLACED
    j       ci_fin

ci_validar:
    mv      a0, s0
    mv      a1, s1
    mv      a2, s2
    mv      a3, s3
    mv      a4, s4
    call    coloc_validar
    bnez    a0, ci_fin

    mv      a0, s0
    mv      a1, s1
    mv      a2, s2
    mv      a3, s3
    mv      a4, s4
    call    coloc_aplicar

    mv      a0, s0
    call    coloc_actualizar_ready
    call    vga_marcar_sucio
    li      a0, PR_OK

ci_fin:
    lw      s4, 8(sp)
    lw      s3, 12(sp)
    lw      s2, 16(sp)
    lw      s1, 20(sp)
    lw      s0, 24(sp)
    lw      ra, 28(sp)
    addi    sp, sp, 32
    ret

# ---------------------------------------------------------------------------
# cursor_mover
# ---------------------------------------------------------------------------
cursor_mover:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    mv      s0, a0

    andi    t0, s0, BTN_UP
    beqz    t0, cm_down
    li      t1, CUR_ROW
    lw      t2, 0(t1)
    beqz    t2, cm_down
    addi    t2, t2, -1
    sw      t2, 0(t1)
    call    vga_marcar_sucio

cm_down:
    andi    t0, s0, BTN_DOWN
    beqz    t0, cm_left
    li      t1, CUR_ROW
    lw      t2, 0(t1)
    li      t3, TABLERO_N
    addi    t3, t3, -1
    bge     t2, t3, cm_left
    addi    t2, t2, 1
    sw      t2, 0(t1)
    call    vga_marcar_sucio

cm_left:
    andi    t0, s0, BTN_LEFT
    beqz    t0, cm_right
    li      t1, CUR_COL
    lw      t2, 0(t1)
    beqz    t2, cm_right
    addi    t2, t2, -1
    sw      t2, 0(t1)
    call    vga_marcar_sucio

cm_right:
    andi    t0, s0, BTN_RIGHT
    beqz    t0, cm_fin
    li      t1, CUR_COL
    lw      t2, 0(t1)
    li      t3, TABLERO_N
    addi    t3, t3, -1
    bge     t2, t3, cm_fin
    addi    t2, t2, 1
    sw      t2, 0(t1)
    call    vga_marcar_sucio

cm_fin:
    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# coloc_j1_flancos
# ---------------------------------------------------------------------------
coloc_j1_flancos:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    mv      s0, a0

    li      t0, J1_SHIP
    lw      t1, 0(t0)
    li      t2, NUM_BARCOS
    bge     t1, t2, cjf_fin

    mv      a0, s0
    call    cursor_mover

cjf_sel:
    andi    t0, s0, BTN_SEL
    beqz    t0, cjf_ok
    li      t1, J1_ORIENT
    lw      t2, 0(t1)
    xori    t2, t2, 1
    sw      t2, 0(t1)
    call    vga_marcar_sucio

cjf_ok:
    andi    t0, s0, BTN_OK
    beqz    t0, cjf_fin

    li      t0, J1_SHIP
    lw      a1, 0(t0)
    li      t0, CUR_ROW
    lw      a2, 0(t0)
    li      t0, CUR_COL
    lw      a3, 0(t0)
    li      t0, J1_ORIENT
    lw      a4, 0(t0)
    li      a0, JUGADOR_1
    call    coloc_intentar
    bnez    a0, cjf_rechazo

    li      t0, J1_SHIP
    lw      t1, 0(t0)
    addi    t1, t1, 1
    sw      t1, 0(t0)
    li      t0, MSG_CODE
    li      t1, MSG_COLOCA
    sw      t1, 0(t0)
    call    estado_revisar_batalla
    j       cjf_fin

cjf_rechazo:
    li      a0, SND_INVALID
    call    salidas_buzzer
    li      t0, MSG_CODE
    li      t1, MSG_INVALIDO
    sw      t1, 0(t0)
    call    vga_marcar_sucio

cjf_fin:
    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret
