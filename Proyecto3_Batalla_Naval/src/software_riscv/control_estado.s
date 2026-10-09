# ---------------------------------------------------------------------------
# Bloque 1 de Nivel 2: CONTROL DE ESTADO DEL JUEGO
#
# Lleva la maquina de fases COLOCACION -> BATALLA -> RESULTADO, el turno y
# el reinicio de partida. Tambien reparte los botones de J1 al bloque que
# corresponda segun la fase.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# partida_init
# Deja todo listo para una partida nueva: borra tableros y metadata, fija
# la longitud de cada barco, pone la fase de colocacion con turno de J1,
# reinicia contadores y cursor, toma la foto de los botones, envia
# PLACEMENT_START y pide redibujar.
# Se usa al encender y con GAME_RST. Conserva P1_WINS y P2_WINS.
# Entradas: ninguna.  Salidas: ninguna.
# ---------------------------------------------------------------------------
partida_init:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    # Los dos tableros son contiguos: 2 x 64 = 128 palabras en AGUA (0).
    li      t0, BOARD_J1
    li      t1, 128
pi_tableros:
    sw      x0, 0(t0)
    addi    t0, t0, 4
    addi    t1, t1, -1
    bnez    t1, pi_tableros

    # Metadata de los 6 barcos: 6 x 8 = 48 palabras en 0.
    li      t0, SHIPS_BASE
    li      t1, 48
pi_meta:
    sw      x0, 0(t0)
    addi    t0, t0, 4
    addi    t1, t1, -1
    bnez    t1, pi_meta

    # Longitudes: barcos 0, 1 y 2 de cada jugador miden 4, 3 y 2.
    li      t0, SHIPS_BASE
    li      t2, 2                   # t2 = jugadores por recorrer
pi_jugador:
    li      t3, 4                   # t3 = longitud del barco actual
    li      t4, NUM_BARCOS          # t4 = barcos por recorrer
pi_barco:
    sw      t3, SH_LEN(t0)
    addi    t3, t3, -1
    addi    t0, t0, SH_TAM
    addi    t4, t4, -1
    bnez    t4, pi_barco
    addi    t2, t2, -1
    bnez    t2, pi_jugador

    # Estado de la partida: colocacion, turno de J1, nadie listo, sin
    # disparos, sin hundidos y sin ganador.
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

    # Cursor de J1 en (0,0), primer barco, orientacion horizontal.
    li      t0, CUR_ROW
    sw      x0, 0(t0)
    li      t0, CUR_COL
    sw      x0, 0(t0)
    li      t0, J1_SHIP
    sw      x0, 0(t0)
    li      t0, J1_ORIENT
    sw      x0, 0(t0)

    # Foto de las entradas: lo que ya esta en alto no cuenta como flanco
    # (por ejemplo, el boton de GAME_RST que se acaba de presionar).
    li      t0, INPUTS
    lw      t1, 0(t0)
    li      t0, BTN_PREV
    sw      t1, 0(t0)

    li      t0, MSG_CODE
    li      t1, MSG_COLOCA
    sw      t1, 0(t0)

    call    uart_reset_parser       # descarta una trama de J2 a medias
    call    msg_placement_start     # avisa al PC que empieza la colocacion
    call    salidas_actualizar      # LED de fase y displays
    call    vga_marcar_sucio

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# servicio_botones
# Tarea del ciclo de servicio para J1. Lee INPUTS, detecta los flancos de
# subida (botones recien presionados) y los entrega al bloque de la fase
# actual. GAME_RST tiene prioridad sobre todo lo demas.
# Entradas: ninguna.  Salidas: ninguna.
# ---------------------------------------------------------------------------
servicio_botones:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)

    # Flancos de subida: actual AND NOT anterior.
    li      t0, INPUTS
    lw      t1, 0(t0)               # t1 = lectura actual
    li      t2, BTN_PREV
    lw      t3, 0(t2)               # t3 = lectura anterior
    sw      t1, 0(t2)               # la actual sera la anterior de la proxima vuelta

    not     t4, t3
    and     s0, t1, t4              # s0 = bits que pasaron de 0 a 1

    beqz    s0, sb_fin              # nada nuevo

    andi    t0, s0, BTN_RST
    beqz    t0, sb_por_fase
    call    partida_init            # GAME_RST: partida nueva en cualquier fase
    j       sb_fin

sb_por_fase:
    li      t0, GAME_PHASE
    lw      t1, 0(t0)
    li      t2, FASE_COLOC
    bne     t1, t2, sb_batalla
    mv      a0, s0
    call    coloc_j1_flancos        # colocacion: cursor, orientacion, OK
    j       sb_fin

sb_batalla:
    li      t2, FASE_BATALLA
    bne     t1, t2, sb_fin          # en RESULTADO solo responde GAME_RST
    mv      a0, s0
    call    turnos_j1_flancos       # batalla: cursor y disparo

sb_fin:
    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret

# ---------------------------------------------------------------------------
# estado_revisar_batalla
# Si se esta en colocacion y los dos jugadores ya colocaron sus 3 barcos,
# pasa a BATALLA con turno de J1: reinicia el cursor, envia BATTLE_START y
# TURN, y actualiza LED y pantalla. Si no, no hace nada.
# Se llama despues de cada colocacion aceptada (de J1 o de J2).
# Entradas: ninguna.  Salidas: ninguna.
# ---------------------------------------------------------------------------
estado_revisar_batalla:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    li      t0, GAME_PHASE
    lw      t1, 0(t0)
    li      t2, FASE_COLOC
    bne     t1, t2, erb_fin         # solo aplica en colocacion

    li      t0, P1_READY
    lw      t1, 0(t0)
    beqz    t1, erb_fin             # J1 aun no termina
    li      t0, P2_READY
    lw      t1, 0(t0)
    beqz    t1, erb_fin             # J2 aun no termina

    # Ambos listos: empieza la batalla con turno de J1.
    li      t0, GAME_PHASE
    li      t1, FASE_BATALLA
    sw      t1, 0(t0)
    li      t0, CURRENT_TURN
    li      t1, JUGADOR_1
    sw      t1, 0(t0)

    # El cursor de J1 pasa al tablero rival en (0,0).
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
# Cambia el turno al otro jugador, envia TURN al PC y pide redibujar.
# Se llama despues de un disparo valido que no termino la partida.
# Entradas: ninguna.  Salidas: ninguna.
# ---------------------------------------------------------------------------
estado_avanzar_turno:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    li      t0, CURRENT_TURN
    lw      t1, 0(t0)
    li      t2, JUGADOR_1
    bne     t1, t2, eat_a_uno
    li      t1, JUGADOR_2           # era J1: pasa a J2
    j       eat_guardar
eat_a_uno:
    li      t1, JUGADOR_1           # era J2: pasa a J1
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
# Termina la partida: guarda el ganador, pasa a RESULTADO, suma una
# victoria al ganador (sin pasar de MAX_WINS), muestra el mensaje de
# ganador, suena el buzzer y envia GAME_OVER.
# Entradas: a0 = jugador ganador.  Salidas: ninguna.
# ---------------------------------------------------------------------------
estado_fin_partida:
    addi    sp, sp, -16
    sw      ra, 12(sp)
    sw      s0, 8(sp)
    mv      s0, a0                  # s0 = ganador

    li      t0, WINNER
    sw      s0, 0(t0)
    li      t0, GAME_PHASE
    li      t1, FASE_RESULT
    sw      t1, 0(t0)

    # Suma la victoria; el marcador se satura en 99 (dos digitos).
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
    call    salidas_actualizar      # LED de fase y marcador nuevo
    call    vga_marcar_sucio

    lw      s0, 8(sp)
    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret
