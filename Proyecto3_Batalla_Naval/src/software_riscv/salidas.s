# ---------------------------------------------------------------------------
# Bloque 6 de Nivel 2: ACTUALIZACION DE PERIFERICOS DE SALIDA
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# salidas_buzzer
# ---------------------------------------------------------------------------
salidas_buzzer:
    li      t0, BUZZER
    sw      a0, 0(t0)
    ret

# ---------------------------------------------------------------------------
# salidas_actualizar
# ---------------------------------------------------------------------------
salidas_actualizar:
    li      t0, GAME_PHASE
    lw      t1, 0(t0)
    li      t2, LED
    sw      t1, 0(t2)

    li      t0, P1_WINS
    lw      t1, 0(t0)
    li      t0, P2_WINS
    lw      t2, 0(t0)
    slli    t2, t2, 8
    or      t1, t1, t2
    li      t0, DISPLAY
    sw      t1, 0(t0)
    ret

# ---------------------------------------------------------------------------
# vga_marcar_sucio
# ---------------------------------------------------------------------------
vga_marcar_sucio:
    li      t0, VGA_DIRTY
    li      t1, 1
    sw      t1, 0(t0)
    li      t0, VGA_PASO
    li      t1, -1
    sw      t1, 0(t0)
    ret

# ---------------------------------------------------------------------------
# vga_tile
# ---------------------------------------------------------------------------
vga_tile:
    slli    t0, a0, 4
    slli    t1, a0, 2
    add     t0, t0, t1
    add     t0, t0, a1
    slli    t0, t0, 2
    li      t1, VGA_BASE
    add     t0, t1, t0
    sw      a2, 0(t0)
    ret

# ---------------------------------------------------------------------------
# vga_texto
# ---------------------------------------------------------------------------
vga_texto:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    sw      s3, 12(sp)
    mv      s0, a0
    mv      s1, a1
    mv      s2, a2
    li      s3, 4

vt_bucle:
    andi    t0, s2, 0xFF
    beqz    t0, vt_fin

    slli    t1, t0, 4
    ori     t1, t1, GLYPH_EN
    ori     t1, t1, COL_HUD
    mv      a0, s0
    mv      a1, s1
    mv      a2, t1
    call    vga_tile

    addi    s1, s1, 1
    srli    s2, s2, 8
    addi    s3, s3, -1
    bnez    s3, vt_bucle

vt_fin:
    mv      a0, s0
    mv      a1, s1
    lw      s3, 12(sp)
    lw      s2, 16(sp)
    lw      s1, 20(sp)
    lw      s0, 24(sp)
    lw      ra, 28(sp)
    addi    sp, sp, 32
    ret

# ---------------------------------------------------------------------------
# vga_num2
# ---------------------------------------------------------------------------
vga_num2:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    mv      s0, a0
    mv      s1, a1
    mv      s2, a2

    li      t0, 0
    li      t1, 10
vn_dividir:
    blt     s2, t1, vn_listo
    sub     s2, s2, t1
    addi    t0, t0, 1
    j       vn_dividir
vn_listo:
    addi    t0, t0, 48
    addi    s2, s2, 48

    slli    t1, t0, 4
    ori     t1, t1, GLYPH_EN
    ori     t1, t1, COL_HUD
    mv      a0, s0
    mv      a1, s1
    mv      a2, t1
    call    vga_tile

    slli    t1, s2, 4
    ori     t1, t1, GLYPH_EN
    ori     t1, t1, COL_HUD
    mv      a0, s0
    addi    a1, s1, 1
    mv      a2, t1
    call    vga_tile

    mv      a0, s0
    addi    a1, s1, 2
    lw      s2, 16(sp)
    lw      s1, 20(sp)
    lw      s0, 24(sp)
    lw      ra, 28(sp)
    addi    sp, sp, 32
    ret

# ---------------------------------------------------------------------------
# servicio_video
# ---------------------------------------------------------------------------
servicio_video:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    li      t0, VGA_DIRTY
    lw      t1, 0(t0)
    beqz    t1, sv_fin

    li      t0, VGA_PASO
    lw      a0, 0(t0)
    blt     a0, x0, sv_empezar
    call    vga_paso

    li      t0, VGA_PASO
    lw      t1, 0(t0)
    addi    t1, t1, 1
    beqz    a0, sv_guardar
    li      t2, VGA_DIRTY
    sw      x0, 0(t2)
    li      t1, 0
sv_guardar:
    sw      t1, 0(t0)
    j       sv_fin

sv_empezar:
    sw      x0, 0(t0)

sv_fin:
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# vga_paso
# ---------------------------------------------------------------------------
vga_paso:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    mv      s0, a0

    li      t0, 3
    blt     s0, t0, vp_fondo
    li      t0, 19
    blt     s0, t0, vp_tablero
    beq     s0, t0, vp_cursor
    li      t0, 20
    beq     s0, t0, vp_hud0
    li      t0, 21
    beq     s0, t0, vp_hud1
    li      t0, 22
    beq     s0, t0, vp_hud2
    li      t0, 23
    beq     s0, t0, vp_hud3
    call    vga_mensaje
    j       vp_fin

vp_fondo:
    mv      a0, s0
    call    vga_limpiar_bloque
    j       vp_fin

vp_tablero:
    addi    t0, s0, -3
    srli    a1, t0, 1
    andi    t0, t0, 1
    li      a0, JUGADOR_1
    beqz    t0, vp_tab_llamar
    li      a0, JUGADOR_2
vp_tab_llamar:
    call    vga_tablero_fila
    j       vp_fin

vp_cursor:
    call    vga_cursor
    j       vp_fin

vp_hud0:
    call    vga_hud_titulo
    j       vp_fin
vp_hud1:
    call    vga_hud_fase
    j       vp_fin
vp_hud2:
    call    vga_hud_rotulos
    j       vp_fin
vp_hud3:
    call    vga_hud_marcador

vp_fin:
    li      a0, 0
    li      t0, 24
    bne     s0, t0, vp_ret
    li      a0, 1
vp_ret:
    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# vga_limpiar_bloque
# ---------------------------------------------------------------------------
vga_limpiar_bloque:
    slli    t1, a0, 6
    slli    t2, a0, 5
    add     t1, t1, t2
    slli    t2, a0, 2
    add     t1, t1, t2
    slli    t1, t1, 2
    li      t0, VGA_BASE
    add     t0, t0, t1
    li      t1, 100
    li      t2, COL_FONDO
vlb_bucle:
    sw      t2, 0(t0)
    addi    t0, t0, 4
    addi    t1, t1, -1
    bnez    t1, vlb_bucle
    ret

# ---------------------------------------------------------------------------
# vga_tablero_fila
# ---------------------------------------------------------------------------
vga_tablero_fila:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    sw      s3, 12(sp)
    sw      s4, 8(sp)
    mv      s0, a0
    mv      s1, a1
    li      s2, 0

vtf_col:
    mv      a0, s0
    call    tablero_dir
    mv      a1, s1
    mv      a2, s2
    call    casilla_dir
    lw      s3, 0(a0)

    li      t0, JUGADOR_1
    bne     s0, t0, vtf_rival

    li      s4, COL_AGUA
    beqz    s3, vtf_pintar
    li      t0, CASILLA_BARCO
    bne     s3, t0, vtf_propio_1
    li      s4, COL_BARCO
    j       vtf_pintar
vtf_propio_1:
    li      t0, CASILLA_FALLO
    bne     s3, t0, vtf_propio_2
    li      s4, COL_FALLO
    j       vtf_pintar
vtf_propio_2:
    li      s4, COL_IMPACTO
    j       vtf_pintar

vtf_rival:
    li      s4, COL_AGUA
    li      t0, CASILLA_FALLO
    bne     s3, t0, vtf_rival_1
    li      s4, COL_FALLO
    j       vtf_pintar
vtf_rival_1:
    li      t0, CASILLA_HIT
    bne     s3, t0, vtf_pintar
    li      s4, COL_IMPACTO

vtf_pintar:
    li      t0, TAB_FILA
    add     a0, s1, t0
    li      t1, TAB_COL_PROPIO
    li      t0, JUGADOR_1
    beq     s0, t0, vtf_col_listo
    li      t1, TAB_COL_RIVAL
vtf_col_listo:
    add     a1, s2, t1
    mv      a2, s4
    call    vga_tile

    addi    s2, s2, 1
    li      t0, TABLERO_N
    blt     s2, t0, vtf_col

    lw      s4, 8(sp)
    lw      s3, 12(sp)
    lw      s2, 16(sp)
    lw      s1, 20(sp)
    lw      s0, 24(sp)
    lw      ra, 28(sp)
    addi    sp, sp, 32
    ret

# ---------------------------------------------------------------------------
# vga_cursor
# ---------------------------------------------------------------------------
vga_cursor:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)

    li      t0, CUR_ROW
    lw      s0, 0(t0)
    li      t0, CUR_COL
    lw      s1, 0(t0)

    li      t0, GAME_PHASE
    lw      t1, 0(t0)
    li      t2, FASE_COLOC
    beq     t1, t2, vc_coloc
    li      t2, FASE_BATALLA
    beq     t1, t2, vc_batalla
    j       vc_fin

vc_batalla:
    li      t0, TAB_FILA
    add     a0, s0, t0
    li      t0, TAB_COL_RIVAL
    add     a1, s1, t0
    li      a2, COL_CURSOR
    call    vga_tile
    j       vc_fin

vc_coloc:
    li      t0, J1_SHIP
    lw      t1, 0(t0)
    li      t2, NUM_BARCOS
    bge     t1, t2, vc_fin

    li      a0, JUGADOR_1
    mv      a1, t1
    call    barco_dir
    lw      s2, SH_LEN(a0)
    li      t0, J1_ORIENT
    lw      t1, 0(t0)

vc_bucle:
    li      t2, TABLERO_N
    sltu    t3, s0, t2
    beqz    t3, vc_fin
    sltu    t3, s1, t2
    beqz    t3, vc_fin

    li      t0, TAB_FILA
    add     a0, s0, t0
    li      t0, TAB_COL_PROPIO
    add     a1, s1, t0
    li      a2, COL_CURSOR
    sw      t1, 8(sp)
    call    vga_tile
    lw      t1, 8(sp)

    li      t0, ORIENT_H
    bne     t1, t0, vc_avanza_fila
    addi    s1, s1, 1
    j       vc_siguiente
vc_avanza_fila:
    addi    s0, s0, 1
vc_siguiente:
    addi    s2, s2, -1
    bnez    s2, vc_bucle

vc_fin:
    lw      s2, 16(sp)
    lw      s1, 20(sp)
    lw      s0, 24(sp)
    lw      ra, 28(sp)
    addi    sp, sp, 32
    ret

# ---------------------------------------------------------------------------
# vga_hud_titulo
# ---------------------------------------------------------------------------
vga_hud_titulo:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    li      a0, 0
    li      a1, 3
    li      a2, ('B') | ('A'<<8) | ('T'<<16) | ('A'<<24)
    call    vga_texto
    li      a2, ('L') | ('L'<<8) | ('A'<<16) | (' '<<24)
    call    vga_texto
    li      a2, ('N') | ('A'<<8) | ('V'<<16) | ('A'<<24)
    call    vga_texto
    li      a2, ('L')
    call    vga_texto

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# vga_hud_fase
# ---------------------------------------------------------------------------
vga_hud_fase:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    li      t0, GAME_PHASE
    lw      t1, 0(t0)
    li      t2, FASE_COLOC
    beq     t1, t2, vhf_coloc
    li      t2, FASE_BATALLA
    beq     t1, t2, vhf_turno
    j       vhf_resultado

vhf_coloc:
    li      a0, 1
    li      a1, 1
    li      a2, ('C') | ('O'<<8) | ('L'<<16) | ('O'<<24)
    call    vga_texto
    li      a2, ('C') | ('A'<<8) | ('N'<<16) | ('D'<<24)
    call    vga_texto
    li      a2, ('O')
    call    vga_texto
    j       vhf_fin

vhf_turno:
    li      a0, 1
    li      a1, 1
    li      a2, ('T') | ('U'<<8) | ('R'<<16) | ('N'<<24)
    call    vga_texto
    li      a2, ('O') | (' '<<8) | ('J'<<16)
    call    vga_texto
    li      t0, CURRENT_TURN
    lw      t1, 0(t0)
    addi    t1, t1, 48
    slli    t2, t1, 4
    ori     t2, t2, GLYPH_EN
    ori     t2, t2, COL_HUD
    mv      a2, t2
    call    vga_tile
    j       vhf_fin

vhf_resultado:
    li      a0, 1
    li      a1, 1
    li      a2, ('F') | ('I'<<8) | ('N'<<16)
    call    vga_texto

vhf_fin:
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# vga_hud_rotulos
# ---------------------------------------------------------------------------
vga_hud_rotulos:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    li      a0, 2
    li      a1, TAB_COL_PROPIO
    li      a2, ('T') | ('U'<<8) | (' '<<16) | ('F'<<24)
    call    vga_texto
    li      a2, ('L') | ('O'<<8) | ('T'<<16) | ('A'<<24)
    call    vga_texto
    li      a0, 2
    li      a1, TAB_COL_RIVAL
    li      a2, ('R') | ('I'<<8) | ('V'<<16) | ('A'<<24)
    call    vga_texto
    li      a2, ('L')
    call    vga_texto

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# vga_hud_marcador
# ---------------------------------------------------------------------------
vga_hud_marcador:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    li      a0, 3
    li      a1, TAB_COL_PROPIO
    li      a2, ('J') | ('1'<<8) | (':'<<16)
    call    vga_texto
    li      t0, P1_WINS
    lw      a2, 0(t0)
    call    vga_num2
    li      a0, 3
    li      a1, TAB_COL_RIVAL
    li      a2, ('J') | ('2'<<8) | (':'<<16)
    call    vga_texto
    li      t0, P2_WINS
    lw      a2, 0(t0)
    call    vga_num2

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# vga_mensaje
# ---------------------------------------------------------------------------
vga_mensaje:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    li      t0, MSG_CODE
    lw      t1, 0(t0)
    li      a0, FILA_MSG
    li      a1, 1

    li      t2, MSG_COLOCA
    beq     t1, t2, vm_coloca
    li      t2, MSG_IMPACTO
    beq     t1, t2, vm_impacto
    li      t2, MSG_FALLO
    beq     t1, t2, vm_fallo
    li      t2, MSG_HUNDIDO
    beq     t1, t2, vm_hundido
    li      t2, MSG_INVALIDO
    beq     t1, t2, vm_invalido
    li      t2, MSG_GANA_J1
    beq     t1, t2, vm_gana1
    li      t2, MSG_GANA_J2
    beq     t1, t2, vm_gana2
    j       vm_fin

vm_coloca:
    li      a2, ('C') | ('O'<<8) | ('L'<<16) | ('O'<<24)
    call    vga_texto
    li      a2, ('C') | ('A'<<8) | (' '<<16) | ('B'<<24)
    call    vga_texto
    li      a2, ('A') | ('R'<<8) | ('C'<<16) | ('O'<<24)
    call    vga_texto
    li      a2, ('S')
    call    vga_texto
    j       vm_fin

vm_impacto:
    li      a2, ('I') | ('M'<<8) | ('P'<<16) | ('A'<<24)
    call    vga_texto
    li      a2, ('C') | ('T'<<8) | ('O'<<16)
    call    vga_texto
    j       vm_fin

vm_fallo:
    li      a2, ('F') | ('A'<<8) | ('L'<<16) | ('L'<<24)
    call    vga_texto
    li      a2, ('O')
    call    vga_texto
    j       vm_fin

vm_hundido:
    li      a2, ('H') | ('U'<<8) | ('N'<<16) | ('D'<<24)
    call    vga_texto
    li      a2, ('I') | ('D'<<8) | ('O'<<16)
    call    vga_texto
    j       vm_fin

vm_invalido:
    li      a2, ('N') | ('O'<<8) | (' '<<16) | ('V'<<24)
    call    vga_texto
    li      a2, ('A') | ('L'<<8) | ('I'<<16) | ('D'<<24)
    call    vga_texto
    li      a2, ('O')
    call    vga_texto
    j       vm_fin

vm_gana1:
    li      a2, ('G') | ('A'<<8) | ('N'<<16) | ('A'<<24)
    call    vga_texto
    li      a2, (' ') | ('J'<<8) | ('1'<<16)
    call    vga_texto
    j       vm_fin

vm_gana2:
    li      a2, ('G') | ('A'<<8) | ('N'<<16) | ('A'<<24)
    call    vga_texto
    li      a2, (' ') | ('J'<<8) | ('2'<<16)
    call    vga_texto

vm_fin:
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret
