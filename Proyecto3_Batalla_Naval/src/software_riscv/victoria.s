# ---------------------------------------------------------------------------
# Bloque 4 de Nivel 2: DETECCION DE HUNDIDO Y VICTORIA
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# victoria_barco_en
# ---------------------------------------------------------------------------
victoria_barco_en:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    sw      s3, 12(sp)
    mv      s1, a1
    mv      s2, a2

    li      a1, 0
    call    barco_dir
    mv      s0, a0
    li      s3, NUM_BARCOS

vbe_bucle:
    lw      t0, SH_PLACED(s0)
    beqz    t0, vbe_siguiente

    lw      t1, SH_ROW(s0)
    lw      t2, SH_COL(s0)
    lw      t3, SH_ORIENT(s0)
    lw      t4, SH_LEN(s0)

    li      t5, ORIENT_H
    bne     t3, t5, vbe_vertical

    bne     s1, t1, vbe_siguiente
    blt     s2, t2, vbe_siguiente
    add     t6, t2, t4
    bge     s2, t6, vbe_siguiente
    j       vbe_encontrado

vbe_vertical:
    bne     s2, t2, vbe_siguiente
    blt     s1, t1, vbe_siguiente
    add     t6, t1, t4
    bge     s1, t6, vbe_siguiente

vbe_encontrado:
    mv      a0, s0
    j       vbe_fin

vbe_siguiente:
    addi    s0, s0, SH_TAM
    addi    s3, s3, -1
    bnez    s3, vbe_bucle
    li      a0, 0

vbe_fin:
    lw      s3, 12(sp)
    lw      s2, 16(sp)
    lw      s1, 20(sp)
    lw      s0, 24(sp)
    lw      ra, 28(sp)
    addi    sp, sp, 32
    ret

# ---------------------------------------------------------------------------
# victoria_registrar_impacto
# ---------------------------------------------------------------------------
victoria_registrar_impacto:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    call    victoria_barco_en
    beqz    a0, vri_no

    mv      t0, a0
    lw      t1, SH_SUNK(t0)
    bnez    t1, vri_no

    lw      t1, SH_HITS(t0)
    addi    t1, t1, 1
    sw      t1, SH_HITS(t0)
    lw      t2, SH_LEN(t0)
    blt     t1, t2, vri_no

    li      t3, 1
    sw      t3, SH_SUNK(t0)
    li      a0, 1
    j       vri_fin

vri_no:
    li      a0, 0
vri_fin:
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# victoria_revisar
# ---------------------------------------------------------------------------
victoria_revisar:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    sw      s1, 4(sp)

    li      t0, JUGADOR_1
    li      t1, JUGADOR_2
    beq     a0, t0, vr_rival_listo
    mv      t1, t0
vr_rival_listo:
    mv      a0, t1
    li      a1, 0
    call    barco_dir
    mv      s0, a0
    li      s1, NUM_BARCOS

vr_bucle:
    lw      t0, SH_SUNK(s0)
    beqz    t0, vr_no
    addi    s0, s0, SH_TAM
    addi    s1, s1, -1
    bnez    s1, vr_bucle
    li      a0, 1
    j       vr_fin
vr_no:
    li      a0, 0
vr_fin:
    lw      s1, 4(sp)
    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret
