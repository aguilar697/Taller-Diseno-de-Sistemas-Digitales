# ---------------------------------------------------------------------------
# Bloque 6 de Nivel 2: ACTUALIZACION DE PERIFERICOS DE SALIDA
#
# Buzzer, LED, displays y pantalla VGA. Los perifericos solo muestran lo que
# el programa les escribe; toda decision esta en el programa.
#
# La pantalla no se redibuja de golpe: redibujarla completa tarda mas que
# los 8680 ciclos entre dos bytes de la UART (que no tiene FIFO). Por eso
# el redibujado se divide en 25 pasos y servicio_video hace uno por vuelta
# del ciclo de servicio.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# salidas_buzzer
# Pide un sonido al buzzer. El periferico decide su duracion y vuelve solo
# a silencio.
# Entradas: a0 = codigo de sonido (SND_*).  Salidas: ninguna.
# ---------------------------------------------------------------------------
salidas_buzzer:
    li      t0, BUZZER
    sw      a0, 0(t0)
    ret

# ---------------------------------------------------------------------------
# salidas_actualizar
# Muestra la fase en los LED y el marcador de victorias en los displays
# (J1 en el byte bajo, J2 en el byte siguiente).
# Entradas: ninguna.  Salidas: ninguna.
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
    or      t1, t1, t2              # t1 = P2_WINS<<8 | P1_WINS
    li      t0, DISPLAY
    sw      t1, 0(t0)
    ret

# ---------------------------------------------------------------------------
# vga_marcar_sucio
# Pide redibujar la pantalla desde el primer paso. Si habia un redibujado
# a medias, vuelve a empezar para no mostrar una mezcla de estados.
# Entradas: ninguna.  Salidas: ninguna.  Modifica: t0, t1
# ---------------------------------------------------------------------------
vga_marcar_sucio:
    li      t0, VGA_DIRTY
    li      t1, 1
    sw      t1, 0(t0)
    li      t0, VGA_PASO
    li      t1, -1                  # -1 = empezar en la proxima vuelta
    sw      t1, 0(t0)
    ret

# ---------------------------------------------------------------------------
# vga_tile
# Escribe un tile de la pantalla de 20x15.
# Entradas: a0 = fila de pantalla, a1 = columna de pantalla,
#           a2 = valor del tile ([2:0] color, [3] glyph_en, [11:4] caracter)
# Salidas:  ninguna.  Modifica: t0, t1
# ---------------------------------------------------------------------------
vga_tile:
    slli    t0, a0, 4
    slli    t1, a0, 2
    add     t0, t0, t1              # fila*20 = fila*16 + fila*4, sin mul
    add     t0, t0, a1              # + columna
    slli    t0, t0, 2               # * 4 bytes por tile
    li      t1, VGA_BASE
    add     t0, t1, t0
    sw      a2, 0(t0)
    ret

# ---------------------------------------------------------------------------
# vga_texto
# Escribe hasta 4 caracteres en color HUD a partir de (fila, columna). Los
# caracteres van empaquetados en a2, el primero en el byte bajo; un byte 0
# termina el texto antes. Devuelve la posicion siguiente para poder
# encadenar llamadas y escribir textos mas largos.
# Entradas: a0 = fila, a1 = columna, a2 = hasta 4 caracteres ASCII
# Salidas:  a0 = fila, a1 = columna despues del ultimo caracter
# ---------------------------------------------------------------------------
vga_texto:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    sw      s3, 12(sp)
    mv      s0, a0                  # s0 = fila
    mv      s1, a1                  # s1 = columna
    mv      s2, a2                  # s2 = caracteres restantes
    li      s3, 4                   # s3 = maximo de caracteres

vt_bucle:
    andi    t0, s2, 0xFF            # t0 = siguiente caracter
    beqz    t0, vt_fin

    # Tile = caracter<<4 | GLYPH_EN | COL_HUD
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
# Escribe un numero de 0 a 99 como dos digitos en color HUD.
# El CPU no tiene div: las decenas se obtienen con restas sucesivas.
# Entradas: a0 = fila, a1 = columna, a2 = numero (0..99)
# Salidas:  a0 = fila, a1 = columna + 2
# ---------------------------------------------------------------------------
vga_num2:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    mv      s0, a0                  # s0 = fila
    mv      s1, a1                  # s1 = columna
    mv      s2, a2                  # s2 = numero

    # t0 = decenas, s2 = unidades
    li      t0, 0
    li      t1, 10
vn_dividir:
    blt     s2, t1, vn_listo
    sub     s2, s2, t1
    addi    t0, t0, 1
    j       vn_dividir
vn_listo:
    addi    t0, t0, 48              # a ASCII ('0' = 48)
    addi    s2, s2, 48

    # Decenas
    slli    t1, t0, 4
    ori     t1, t1, GLYPH_EN
    ori     t1, t1, COL_HUD
    mv      a0, s0
    mv      a1, s1
    mv      a2, t1
    call    vga_tile

    # Unidades
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
# Tarea del ciclo de servicio. Si hay que redibujar, hace un solo paso:
# - VGA_PASO = -1: acaba de marcarse sucio; se pone en 0 y no dibuja aun.
# - Si no, ejecuta vga_paso(VGA_PASO) y avanza. Al terminar el ultimo
#   paso borra VGA_DIRTY y deja VGA_PASO en 0.
# Entradas: ninguna.  Salidas: ninguna.
# ---------------------------------------------------------------------------
servicio_video:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    li      t0, VGA_DIRTY
    lw      t1, 0(t0)
    beqz    t1, sv_fin              # pantalla al dia

    li      t0, VGA_PASO
    lw      a0, 0(t0)
    blt     a0, x0, sv_empezar
    call    vga_paso                # a0 = 1 si fue el ultimo paso

    li      t0, VGA_PASO
    lw      t1, 0(t0)
    addi    t1, t1, 1
    beqz    a0, sv_guardar
    li      t2, VGA_DIRTY
    sw      x0, 0(t2)               # redibujado terminado
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
# Ejecuta un paso del redibujado. El orden importa: cada paso pinta encima
# de los anteriores.
#   0..2   limpia la pantalla, 100 tiles (5 filas) por paso
#   3..18  una fila de un tablero: pasos pares J1, impares J2 (8 filas c/u)
#   19     cursor
#   20..23 HUD: titulo, fase, rotulos y marcador
#   24     mensaje de la fila inferior (ultimo paso)
# Entradas: a0 = numero de paso (0..24)
# Salida:   a0 = 1 si fue el ultimo paso, 0 si no
# ---------------------------------------------------------------------------
vga_paso:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    mv      s0, a0                  # s0 = paso

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

    # k = paso - 3: fila = k/2, jugador = J1 si k es par, J2 si es impar.
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
    li      a0, 1                   # paso 24: redibujado completo
vp_ret:
    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# vga_limpiar_bloque
# Pone en COL_FONDO un bloque de 100 tiles (5 filas de pantalla).
# Entradas: a0 = bloque (0..2).  Salidas: ninguna.
# ---------------------------------------------------------------------------
vga_limpiar_bloque:
    slli    t1, a0, 6
    slli    t2, a0, 5
    add     t1, t1, t2
    slli    t2, a0, 2
    add     t1, t1, t2              # t1 = bloque*100 = bloque*(64+32+4)
    slli    t1, t1, 2               # * 4 bytes por tile
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
# Pinta una fila (8 casillas) de un tablero.
# - Tablero de J1 (izquierda, propio): muestra agua, barcos, fallos e
#   impactos.
# - Tablero de J2 (derecha, rival): los barcos sin tocar se ven como agua;
#   solo se muestran fallos e impactos.
# Entradas: a0 = jugador dueno del tablero, a1 = fila del tablero (0..7)
# Salidas:  ninguna.
# ---------------------------------------------------------------------------
vga_tablero_fila:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    sw      s3, 12(sp)
    sw      s4, 8(sp)
    mv      s0, a0                  # s0 = jugador
    mv      s1, a1                  # s1 = fila
    li      s2, 0                   # s2 = columna

vtf_col:
    mv      a0, s0
    call    tablero_dir
    mv      a1, s1
    mv      a2, s2
    call    casilla_dir
    lw      s3, 0(a0)               # s3 = estado de la casilla

    li      t0, JUGADOR_1
    bne     s0, t0, vtf_rival

    # Tablero propio: AGUA, BARCO, FALLO o HIT con su color.
    li      s4, COL_AGUA            # s4 = color del tile
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

    # Tablero rival: los barcos se ocultan.
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

    # Posicion en pantalla: fila + TAB_FILA, columna + columna del tablero.
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
# Pinta el cursor de J1 encima de los tableros.
# - Batalla: un tile en el tablero rival, en la casilla apuntada.
# - Colocacion: la silueta del barco que se va a colocar (su longitud y
#   orientacion) sobre el tablero propio, recortada en el borde.
# - Resultado: no pinta nada.
# Entradas: ninguna (lee CUR_ROW, CUR_COL, J1_SHIP, J1_ORIENT).
# Salidas:  ninguna.
# ---------------------------------------------------------------------------
vga_cursor:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)

    li      t0, CUR_ROW
    lw      s0, 0(t0)               # s0 = fila
    li      t0, CUR_COL
    lw      s1, 0(t0)               # s1 = columna

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
    bge     t1, t2, vc_fin          # ya coloco los 3: no hay silueta

    li      a0, JUGADOR_1
    mv      a1, t1
    call    barco_dir
    lw      s2, SH_LEN(a0)          # s2 = casillas por pintar
    li      t0, J1_ORIENT
    lw      t1, 0(t0)               # t1 = orientacion

vc_bucle:
    # Se detiene al salir del tablero.
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
    sw      t1, 8(sp)               # vga_tile modifica t1: se guarda en la pila
    call    vga_tile
    lw      t1, 8(sp)

    li      t0, ORIENT_H
    bne     t1, t0, vc_avanza_fila
    addi    s1, s1, 1               # horizontal: columna siguiente
    j       vc_siguiente
vc_avanza_fila:
    addi    s0, s0, 1               # vertical: fila siguiente
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
# Escribe "BATALLA NAVAL" en la fila 0.
# Entradas: ninguna.  Salidas: ninguna.
# ---------------------------------------------------------------------------
vga_hud_titulo:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    # Cada vga_texto devuelve en a0/a1 la posicion siguiente.
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
# Escribe la fase en la fila 1: "COLOCANDO", "TURNO J1"/"TURNO J2" o "FIN".
# Entradas: ninguna.  Salidas: ninguna.
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
    # Digito del jugador con el turno ('0' + CURRENT_TURN).
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
# Escribe en la fila 2 el rotulo de cada tablero: "TU FLOTA" sobre el de
# J1 y "RIVAL" sobre el de J2.
# Entradas: ninguna.  Salidas: ninguna.
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
# Escribe en la fila 3 el marcador de victorias: "J1:nn" y "J2:nn".
# Entradas: ninguna.  Salidas: ninguna.
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
# Escribe en la fila FILA_MSG el mensaje indicado por MSG_CODE: "COLOCA
# BARCOS", "IMPACTO", "FALLO", "HUNDIDO", "NO VALIDO", "GANA J1" o
# "GANA J2". Con MSG_NADA no escribe nada.
# Entradas: ninguna.  Salidas: ninguna.
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
