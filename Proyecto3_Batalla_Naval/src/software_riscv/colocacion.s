# ---------------------------------------------------------------------------
# Bloque 2 de Nivel 2: GESTION DE COLOCACION DE BARCOS
#
# J1 coloca con cursor y botones (coloc_j1_flancos); J2 coloca con mensajes
# PLACE (uart_despachar). Las dos vias terminan en coloc_intentar, asi que
# las reglas de colocacion estan escritas una sola vez.
# Tambien contiene utilidades de direcciones y el movimiento del cursor,
# que usan otros bloques.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# barco_dir
# Calcula la direccion del registro de metadata de un barco.
# Entradas: a0 = jugador (1 o 2), a1 = ship_id (0..2)
# Salida:   a0 = SHIPS_BASE + 32*(3*(jugador-1) + ship_id)
# Modifica: t0, t2, t3
# ---------------------------------------------------------------------------
barco_dir:
    addi    t0, a0, -1              # t0 = jugador - 1
    add     t2, t0, t0
    add     t2, t2, t0              # t2 = 3*(jugador-1), sin mul
    add     t2, t2, a1              # t2 = indice del barco (0..5)
    slli    t2, t2, 5               # * 32 bytes por registro
    li      t3, SHIPS_BASE
    add     a0, t3, t2
    ret

# ---------------------------------------------------------------------------
# tablero_dir
# Devuelve la direccion base del tablero de un jugador.
# Entradas: a0 = jugador (1 o 2)
# Salida:   a0 = BOARD_J1 o BOARD_J2
# Modifica: t0, t1
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
# Calcula la direccion de una casilla dentro de un tablero.
# Entradas: a0 = base del tablero, a1 = fila, a2 = columna
# Salida:   a0 = base + 4*(fila*8 + columna)
# Modifica: t0
# ---------------------------------------------------------------------------
casilla_dir:
    slli    t0, a1, 3               # fila*8
    add     t0, t0, a2              # + columna
    slli    t0, t0, 2               # * 4 bytes por casilla
    add     a0, a0, t0
    ret

# ---------------------------------------------------------------------------
# coloc_validar
# Decide si una colocacion es legal, sin modificar nada. Revisa en orden:
# ship_id valido, orientacion valida, barco no colocado, proa dentro del
# tablero y extremo dentro del tablero, y que ninguna casilla este ocupada.
# Entradas: a0 = jugador, a1 = ship_id, a2 = fila, a3 = columna,
#           a4 = orientacion
# Salida:   a0 = PR_OK (0) o el motivo del primer fallo (PR_*)
# ---------------------------------------------------------------------------
coloc_validar:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    sw      s3, 12(sp)
    sw      s4, 8(sp)
    mv      s0, a0                  # s0 = jugador
    mv      s1, a1                  # s1 = ship_id
    mv      s2, a2                  # s2 = fila
    mv      s3, a3                  # s3 = columna
    mv      s4, a4                  # s4 = orientacion

    # 1) ship_id < 3. Sin signo: un 0xFF llegado por UART tambien falla.
    #    Se revisa antes de usarlo en barco_dir.
    li      t0, NUM_BARCOS
    sltu    t1, s1, t0
    bnez    t1, cv_orient
    li      a0, PR_INVALID_SHIP
    j       cv_fin

    # 2) orientacion 0 (H) o 1 (V).
cv_orient:
    li      t0, 2
    sltu    t1, s4, t0
    bnez    t1, cv_placed
    li      a0, PR_INVALID_ORIENTATION
    j       cv_fin

    # 3) el barco no debe estar colocado ya.
cv_placed:
    mv      a0, s0
    mv      a1, s1
    call    barco_dir
    lw      t0, SH_PLACED(a0)
    beqz    t0, cv_limites
    li      a0, PR_ALREADY_PLACED
    j       cv_fin

    # 4) proa en 0..7 y extremo (proa + longitud) <= 8.
cv_limites:
    li      t0, TABLERO_N
    sltu    t1, s2, t0
    beqz    t1, cv_fuera
    sltu    t1, s3, t0
    beqz    t1, cv_fuera

    mv      a0, s0
    mv      a1, s1
    call    barco_dir
    lw      t2, SH_LEN(a0)          # t2 = longitud del barco
    li      t3, ORIENT_H
    beq     s4, t3, cv_horizontal
    add     t4, s2, t2              # vertical: extremo = fila + longitud
    j       cv_extremo
cv_horizontal:
    add     t4, s3, t2              # horizontal: extremo = columna + longitud
cv_extremo:
    li      t5, TABLERO_N
    addi    t5, t5, 1
    sltu    t6, t4, t5              # extremo < 9, es decir, <= 8
    bnez    t6, cv_traslape
cv_fuera:
    li      a0, PR_OUT_OF_BOUNDS
    j       cv_fin

    # 5) traslape: todas las casillas que ocuparia deben ser AGUA.
    #    La longitud se lee antes de tablero_dir/casilla_dir y se guarda en
    #    t5, que esas subrutinas no modifican.
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
    mv      t0, a0                  # t0 = casilla de la proa

    # Paso entre casillas: 4 bytes (columna siguiente) si es horizontal,
    # 32 bytes (fila siguiente) si es vertical.
    li      t1, 4
    li      t2, ORIENT_H
    beq     s4, t2, cv_paso_listo
    li      t1, 32
cv_paso_listo:
    mv      t2, t5                  # t2 = casillas por revisar

cv_bucle:
    lw      t3, 0(t0)
    beqz    t3, cv_siguiente        # AGUA: libre
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
# Escribe un barco ya validado: marca sus casillas como CASILLA_BARCO y
# llena su metadata (placed = 1, fila, columna, orientacion, hits = 0,
# sunk = 0). Supone que coloc_validar lo acepto.
# Entradas: a0 = jugador, a1 = ship_id, a2 = fila, a3 = columna,
#           a4 = orientacion
# Salidas:  ninguna.
# ---------------------------------------------------------------------------
coloc_aplicar:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    sw      s3, 12(sp)
    sw      s4, 8(sp)
    mv      s0, a0                  # s0 = jugador
    mv      s1, a1                  # s1 = ship_id
    mv      s2, a2                  # s2 = fila
    mv      s3, a3                  # s3 = columna
    mv      s4, a4                  # s4 = orientacion

    # t4 = metadata y t5 = longitud; tablero_dir/casilla_dir no los tocan.
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
    mv      t0, a0                  # t0 = casilla de la proa

    # Mismo paso que en coloc_validar: 4 bytes en H, 32 bytes en V.
    li      t1, 4
    li      t2, ORIENT_H
    beq     s4, t2, ca_paso_listo
    li      t1, 32
ca_paso_listo:
    mv      t2, t5                  # t2 = casillas por marcar
    li      t3, CASILLA_BARCO
ca_bucle:
    sw      t3, 0(t0)
    add     t0, t0, t1
    addi    t2, t2, -1
    bnez    t2, ca_bucle

    # Metadata del barco.
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
# Recalcula P1_READY o P2_READY: queda en 1 si los 3 barcos del jugador
# tienen placed = 1, y en 0 si falta alguno. Se deduce de la metadata en
# lugar de llevar un contador aparte.
# Entradas: a0 = jugador.  Salidas: ninguna.
# ---------------------------------------------------------------------------
coloc_actualizar_ready:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    mv      s0, a0                  # s0 = jugador

    mv      a0, s0
    li      a1, 0
    call    barco_dir
    mv      t0, a0                  # t0 = metadata del barco 0
    li      t1, NUM_BARCOS
    li      t2, 1                   # t2 = listo, hasta encontrar uno sin colocar
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
# Entrada comun para colocar un barco, venga de J1 o de J2. Rechaza si no
# se esta en colocacion; si no, valida y, si se acepta, aplica el barco,
# recalcula el READY del jugador y pide redibujar.
# No envia mensajes por UART ni suena el buzzer: eso lo decide quien llama.
# Entradas: a0 = jugador, a1 = ship_id, a2 = fila, a3 = columna,
#           a4 = orientacion
# Salida:   a0 = PR_OK (0) o el motivo del rechazo (PR_*)
# ---------------------------------------------------------------------------
coloc_intentar:
    addi    sp, sp, -32
    sw      ra, 28(sp)
    sw      s0, 24(sp)
    sw      s1, 20(sp)
    sw      s2, 16(sp)
    sw      s3, 12(sp)
    sw      s4, 8(sp)
    mv      s0, a0                  # s0 = jugador
    mv      s1, a1                  # s1 = ship_id
    mv      s2, a2                  # s2 = fila
    mv      s3, a3                  # s3 = columna
    mv      s4, a4                  # s4 = orientacion

    # Proteccion extra: fuera de colocacion se rechaza.
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
    bnez    a0, ci_fin              # rechazado: devuelve el motivo, nada cambio

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
# Mueve el cursor de J1 una casilla por cada boton de direccion recien
# presionado, sin salir del tablero (0..7). Pide redibujar si se movio.
# Se usa en colocacion y en batalla.
# Entradas: a0 = flancos de subida de INPUTS.  Salidas: ninguna.
# ---------------------------------------------------------------------------
cursor_mover:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    mv      s0, a0                  # s0 = flancos

    # Arriba: fila - 1 si fila > 0.
    andi    t0, s0, BTN_UP
    beqz    t0, cm_down
    li      t1, CUR_ROW
    lw      t2, 0(t1)
    beqz    t2, cm_down
    addi    t2, t2, -1
    sw      t2, 0(t1)
    call    vga_marcar_sucio

    # Abajo: fila + 1 si fila < 7.
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

    # Izquierda: columna - 1 si columna > 0.
cm_left:
    andi    t0, s0, BTN_LEFT
    beqz    t0, cm_right
    li      t1, CUR_COL
    lw      t2, 0(t1)
    beqz    t2, cm_right
    addi    t2, t2, -1
    sw      t2, 0(t1)
    call    vga_marcar_sucio

    # Derecha: columna + 1 si columna < 7.
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
# Atiende los botones de J1 en la fase de colocacion: mueve el cursor, SEL
# cambia la orientacion y OK intenta colocar el barco J1_SHIP en el cursor.
# Si se acepta, pasa al siguiente barco y revisa si ya empieza la batalla;
# si se rechaza, suena SND_INVALID y muestra "NO VALIDO".
# Cuando J1 ya coloco sus 3 barcos ignora los botones.
# Entradas: a0 = flancos de subida de INPUTS.  Salidas: ninguna.
# ---------------------------------------------------------------------------
coloc_j1_flancos:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    mv      s0, a0                  # s0 = flancos

    li      t0, J1_SHIP
    lw      t1, 0(t0)
    li      t2, NUM_BARCOS
    bge     t1, t2, cjf_fin         # ya coloco los 3: espera a J2

    mv      a0, s0
    call    cursor_mover

    # SEL: alterna horizontal/vertical.
cjf_sel:
    andi    t0, s0, BTN_SEL
    beqz    t0, cjf_ok
    li      t1, J1_ORIENT
    lw      t2, 0(t1)
    xori    t2, t2, 1
    sw      t2, 0(t1)
    call    vga_marcar_sucio

    # OK: intenta colocar con los datos actuales del cursor.
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

    # Aceptado: siguiente barco.
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
