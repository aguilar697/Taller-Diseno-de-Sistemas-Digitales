# ---------------------------------------------------------------------------
# Programa principal: inicializacion y ciclo de servicio
# ---------------------------------------------------------------------------

inicio:
    li      sp, PILA_INICIO
    call    sistema_init

bucle_servicio:
    call    servicio_botones
    call    servicio_uart_rx
    call    servicio_uart_tx
    call    servicio_video
    j       bucle_servicio

# ---------------------------------------------------------------------------
# sistema_init
# ---------------------------------------------------------------------------
sistema_init:
    addi    sp, sp, -16
    sw      ra, 12(sp)

    li      t0, P1_WINS
    sw      x0, 0(t0)
    li      t0, P2_WINS
    sw      x0, 0(t0)

    call    uart_init
    call    partida_init

    lw      ra, 12(sp)
    addi    sp, sp, 16
    ret
