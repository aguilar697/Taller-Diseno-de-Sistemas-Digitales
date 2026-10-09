# ---------------------------------------------------------------------------
# Programa principal: inicializacion y ciclo de servicio
#
# El programa nunca se bloquea esperando un boton, un byte de la UART o el
# fin de una transmision. En cada vuelta del ciclo atiende un poco de cada
# tarea, asi los dos jugadores pueden colocar barcos al mismo tiempo.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# inicio
# Punto de entrada tras el reset (direccion 0 de la ROM). Prepara la pila,
# inicializa el sistema y entra al ciclo de servicio, del que no sale.
# ---------------------------------------------------------------------------
inicio:
    li      sp, PILA_INICIO         # pila al final de la RAM, crece hacia abajo
    call    sistema_init

# Ciclo de servicio: cada subrutina revisa si tiene trabajo y regresa enseguida.
bucle_servicio:
    call    servicio_botones        # flancos de los botones de J1
    call    servicio_uart_rx        # a lo sumo un byte recibido de J2
    call    servicio_uart_tx        # a lo sumo un byte enviado al PC
    call    servicio_video          # un paso del redibujado de la pantalla
    j       bucle_servicio

# ---------------------------------------------------------------------------
# sistema_init
# Inicializacion que se hace una sola vez al encender: borra el marcador de
# victorias, inicializa la UART, espera a que se estabilicen las entradas y
# arranca la primera partida.
# Entradas: ninguna.  Salidas: ninguna.
# ---------------------------------------------------------------------------
sistema_init:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    # El marcador solo se borra aqui; GAME_RST (partida_init) lo conserva.
    li      t0, P1_WINS
    sw      x0, 0(t0)
    li      t0, P2_WINS
    sw      x0, 0(t0)

    call    uart_init

    # Espera de arranque (~13 ms): el antirrebote de las entradas arranca en
    # 0 y tarda ~10 ms en mostrar los switches que ya estan en alto. Si
    # partida_init tomara la foto de BTN_PREV antes, se leerian como
    # pulsaciones nuevas.
    li      t0, ESPERA_ARRANQUE
si_espera:
    addi    t0, t0, -1
    bnez    t0, si_espera

    call    partida_init

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret
