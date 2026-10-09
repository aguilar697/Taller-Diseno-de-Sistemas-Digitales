"""Prueba de integracion: partidas completas de principio a fin.

Comprueba el sistema como lo veria un jugador: colocacion concurrente,
batalla alternada, victoria, reinicio con GAME_RST y una segunda partida que
conserva el marcador.
"""

import sys
from comun import (Juego, Resultados, BTN_OK, BTN_RST, BTN_UP, BTN_DOWN,
                   BTN_LEFT, BTN_RIGHT, ORIENT_H, FASE_COLOC, FASE_BATALLA,
                   FASE_RESULT, RES_HIT, RES_SUNK, HIT, FALLO,
                   T_PLACEMENT_START, T_PLACE_RESULT, T_BATTLE_START, T_TURN,
                   T_SHOT_RESULT, T_INCOMING_SHOT, T_GAME_OVER)

# Casillas de agua que usa cada jugador para ceder el turno sin acertar.
AGUA_J2 = [(7, c) for c in range(8)] + [(6, 0)]


def ir_a(j, fila, col):
    """Lleva el cursor de J1 a una casilla concreta desde donde este."""
    j.mover(BTN_UP, 8)
    j.mover(BTN_LEFT, 8)
    if fila:
        j.mover(BTN_DOWN, fila)
    if col:
        j.mover(BTN_RIGHT, col)


def pruebas(r):
    # =================================================================
    # Partida 1: gana J1 hundiendo la flota de J2
    # =================================================================
    j = Juego()
    r.igual(j.var("GAME_PHASE"), FASE_COLOC, "la partida arranca en colocacion")
    r.igual(j.ultima_trama(T_PLACEMENT_START), [0, 0],
            "se invita a colocar anunciando el marcador")

    # Colocacion entrelazada: ningun jugador espera al otro.
    j.pulsar(BTN_OK)                                 # J1 barco 0 en (0,0)
    j.enviar_place(0, 0, 0, ORIENT_H)                # J2 barco 0
    j.mover(BTN_DOWN, 2)
    j.pulsar(BTN_OK)                                 # J1 barco 1 en (2,0)
    j.enviar_place(1, 2, 0, ORIENT_H)                # J2 barco 1
    r.igual(j.var("GAME_PHASE"), FASE_COLOC,
            "con dos barcos por jugador sigue la colocacion")
    j.mover(BTN_DOWN, 2)
    j.pulsar(BTN_OK)                                 # J1 barco 2 en (4,0)
    r.igual(j.var("P1_READY"), 1, "J1 termino su flota")
    r.igual(j.var("P2_READY"), 0, "J2 aun no termino")
    r.igual(j.var("GAME_PHASE"), FASE_COLOC,
            "la batalla espera a que ambos terminen")

    j.limpiar_tramas()
    j.enviar_place(2, 4, 0, ORIENT_H)                # J2 cierra su flota
    j.correr_vueltas(25)
    r.igual(j.var("GAME_PHASE"), FASE_BATALLA, "con ambas flotas empieza la batalla")

    tipos = [t for t, _ in j.tramas]
    r.check(T_PLACE_RESULT in tipos and T_BATTLE_START in tipos,
            "se responde la colocacion y se anuncia el inicio de la batalla")
    if T_PLACE_RESULT in tipos and T_BATTLE_START in tipos:
        r.check(tipos.index(T_PLACE_RESULT) < tipos.index(T_BATTLE_START),
                "la respuesta a la colocacion precede al inicio de batalla")
    r.igual(j.ultima_trama(T_BATTLE_START), [1], "J1 abre la batalla")
    r.igual(j.ultima_trama(T_TURN), [1], "el primer turno es de J1")

    # Batalla: J1 hunde los tres barcos de J2, J2 falla en agua.
    objetivos_j1 = [(0, 0), (0, 1), (0, 2), (0, 3),
                    (2, 0), (2, 1), (2, 2), (4, 0), (4, 1)]
    for i, (fila, col) in enumerate(objetivos_j1):
        j.limpiar_tramas()
        ir_a(j, fila, col)
        j.pulsar(BTN_OK)
        j.correr_vueltas(12)
        aviso = j.ultima_trama(T_INCOMING_SHOT)
        r.check(aviso is not None and aviso[0] == fila and aviso[1] == col,
                "el disparo %d de J1 se notifica a la PC" % (i + 1))
        if j.var("GAME_PHASE") == FASE_RESULT:
            break
        fila_j2, col_j2 = AGUA_J2[i]
        j.enviar_shot(fila_j2, col_j2)
        j.correr_vueltas(8)

    r.igual(j.var("GAME_PHASE"), FASE_RESULT, "la partida termina")
    r.igual(j.var("WINNER"), 1, "gana J1")
    r.igual(j.var("P1_WINS"), 1, "el marcador de J1 sube a 1")
    r.igual(j.var("P2_WINS"), 0, "el marcador de J2 se queda en 0")
    r.igual(j.var("P1_SUNK"), 3, "J1 hundio los tres barcos rivales")

    fin = j.ultima_trama(T_GAME_OVER)
    r.check(fin is not None, "se emite GAME_OVER")
    if fin:
        r.igual(fin[0], 1, "GAME_OVER declara ganador a J1")
        r.igual(fin[3], 3, "GAME_OVER informa 3 barcos hundidos por J1")
        r.igual(fin[5], 1, "GAME_OVER informa la victoria de J1")
    r.igual(j.sim.led, FASE_RESULT, "el LED indica resultado")
    r.igual(j.sim.display & 0xFF, 1, "los displays muestran la victoria de J1")

    # Tras GAME_OVER no debe haber otro TURN.
    j.limpiar_tramas()
    j.correr_vueltas(20)
    r.check(j.ultima_trama(T_TURN) is None,
            "tras GAME_OVER no se anuncia otro turno")

    # =================================================================
    # Reinicio con GAME_RST y segunda partida
    # =================================================================
    j.limpiar_tramas()
    j.pulsar(BTN_RST)
    j.correr_vueltas(25)
    r.igual(j.var("GAME_PHASE"), FASE_COLOC, "GAME_RST vuelve a colocacion")
    r.igual(j.var("P1_WINS"), 1, "el marcador se conserva tras GAME_RST")
    r.igual(j.ultima_trama(T_PLACEMENT_START), [1, 0],
            "la nueva partida anuncia el marcador acumulado")
    r.igual([j.casilla(1, 0, c) for c in range(8)], [0] * 8,
            "el tablero de J1 quedo limpio")
    r.igual([j.casilla(2, 0, c) for c in range(8)], [0] * 8,
            "el tablero de J2 quedo limpio")

    # Segunda partida, ahora gana J2.
    j.colocar_flota_j2()
    j.colocar_flota_j1()
    j.correr_vueltas(20)
    r.igual(j.var("GAME_PHASE"), FASE_BATALLA, "la segunda partida entra en batalla")

    objetivos_j2 = [(0, 0), (0, 1), (0, 2), (0, 3),
                    (2, 0), (2, 1), (2, 2), (4, 0), (4, 1)]
    for i, (fila, col) in enumerate(objetivos_j2):
        ir_a(j, *AGUA_J2[i])
        j.pulsar(BTN_OK)                             # J1 falla
        j.correr_vueltas(8)
        j.limpiar_tramas()
        j.enviar_shot(fila, col)                     # J2 acierta
        j.correr_vueltas(10)
        respuesta = j.ultima_trama(T_SHOT_RESULT)
        r.check(respuesta is not None and respuesta[2] in (RES_HIT, RES_SUNK),
                "el disparo %d de J2 acierta y se responde" % (i + 1))
        if j.var("GAME_PHASE") == FASE_RESULT:
            break

    r.igual(j.var("GAME_PHASE"), FASE_RESULT, "la segunda partida termina")
    r.igual(j.var("WINNER"), 2, "gana J2 la segunda partida")
    r.igual(j.var("P1_WINS"), 1, "J1 conserva su victoria anterior")
    r.igual(j.var("P2_WINS"), 1, "J2 suma su primera victoria")
    r.igual(j.sim.display, (1 << 8) | 1,
            "los displays muestran una victoria por jugador")

    # --- Coherencia final del tablero ---
    impactos = sum(1 for f in range(8) for c in range(8)
                   if j.casilla(1, f, c) == HIT)
    r.igual(impactos, 9, "las nueve casillas de la flota de J1 estan impactadas")
    fallos = sum(1 for f in range(8) for c in range(8)
                 if j.casilla(1, f, c) == FALLO)
    r.igual(fallos, 0, "J2 no gasto disparos en agua en esta partida")
    r.check(all(j.barco(1, s, "SH_SUNK") == 1 for s in range(3)),
            "los tres barcos de J1 figuran hundidos")

    # --- El CPU nunca se detuvo ---
    r.check(not j.sim.detenido,
            "el CPU no entro en estado de fallo durante las dos partidas")

    # --- Ninguna vuelta del ciclo de servicio tarda mas que un byte UART ---
    # La UART real no tiene FIFO: si una vuelta tardara mas de 8680 ciclos
    # (un byte a 115200 baudios), un byte recibido se perderia. Se juega la
    # partida de la prueba de integracion, que incluye colocaciones invalidas,
    # hundimientos, victoria y GAME_RST, y se mide cada vuelta en ciclos.
    import escenario as guion
    j = Juego()
    j.vuelta_max = 0
    for paso in guion.escenario():
        if paso[0] == "boton":
            j.pulsar(paso[1])
        elif paso[0] == "tx":
            j.enviar_trama(paso[1], paso[2])
        j.drenar()
    r.check(j.vuelta_max < 8680,
            "la vuelta mas larga del ciclo de servicio (%d ciclos) dura menos que "
            "un byte UART (8680 ciclos)" % j.vuelta_max)
    r.igual(j.sim.rx_perdidos, 0, "ningun byte recibido se pierde en toda la partida")
    r.igual(j.sim.tx_ignorados, 0, "nunca se escribe TX_DATA con la TX ocupada")


def main():
    r = Resultados("Integracion: partidas completas")
    pruebas(r)
    return r.reportar()


if __name__ == "__main__":
    sys.exit(main())
