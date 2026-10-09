"""Pruebas del bloque CONTROL DE ESTADO DEL JUEGO."""

import sys
import comun
from comun import (Juego, Resultados, BTN_OK, BTN_RST, BTN_DOWN,
                   FASE_COLOC, FASE_BATALLA, FASE_RESULT,
                   T_PLACEMENT_START, T_BATTLE_START, T_TURN)


def pruebas(r):
    # --- Estado inicial tras el reset general ---
    j = Juego()
    j.correr_vueltas(10)
    r.igual(j.var("GAME_PHASE"), FASE_COLOC, "arranca en fase de colocacion")
    r.igual(j.var("CURRENT_TURN"), 1, "el turno inicial es de J1")
    r.igual(j.var("P1_READY"), 0, "J1 no esta listo al arrancar")
    r.igual(j.var("P2_READY"), 0, "J2 no esta listo al arrancar")
    r.igual(j.var("P1_WINS"), 0, "victorias de J1 en cero tras reset general")
    r.igual(j.var("P2_WINS"), 0, "victorias de J2 en cero tras reset general")
    r.igual(j.sim.led, FASE_COLOC, "LED indica colocacion")
    r.igual(j.ultima_trama(T_PLACEMENT_START), [0, 0],
            "se anuncia PLACEMENT_START con el marcador")

    # --- La batalla empieza solo cuando ambas flotas estan completas ---
    j = Juego()
    j.colocar_flota_j2()
    j.correr_vueltas(10)
    r.igual(j.var("P2_READY"), 1, "J2 queda listo tras colocar sus 3 barcos")
    r.igual(j.var("GAME_PHASE"), FASE_COLOC,
            "con una sola flota lista sigue en colocacion")
    r.check(j.ultima_trama(T_BATTLE_START) is None,
            "no se anuncia BATTLE_START con una sola flota lista")

    j.limpiar_tramas()
    j.colocar_flota_j1()
    j.correr_vueltas(15)
    r.igual(j.var("P1_READY"), 1, "J1 queda listo tras colocar sus 3 barcos")
    r.igual(j.var("GAME_PHASE"), FASE_BATALLA, "con ambas flotas empieza la batalla")
    r.igual(j.ultima_trama(T_BATTLE_START), [1], "BATTLE_START indica que empieza J1")
    r.igual(j.ultima_trama(T_TURN), [1], "el primer TURN es de J1")
    r.igual(j.sim.led, FASE_BATALLA, "LED indica batalla")

    # --- Alternancia de turnos ---
    j.limpiar_tramas()
    j.mover(BTN_DOWN, 7)
    j.pulsar(BTN_OK)                      # J1 dispara a una casilla de agua
    j.correr_vueltas(10)
    r.igual(j.var("CURRENT_TURN"), 2, "tras el disparo de J1 el turno pasa a J2")
    r.igual(j.ultima_trama(T_TURN), [2], "se notifica el cambio de turno")
    j.enviar_shot(7, 7)
    j.correr_vueltas(10)
    r.igual(j.var("CURRENT_TURN"), 1, "tras el disparo de J2 el turno vuelve a J1")

    # --- GAME_RST reinicia la partida y conserva las victorias ---
    j = partida_ganada_por_j2()
    r.igual(j.var("GAME_PHASE"), FASE_RESULT, "la partida termina en fase de resultado")
    r.igual(j.var("P2_WINS"), 1, "el ganador suma una victoria")
    victorias_previas = (j.var("P1_WINS"), j.var("P2_WINS"))

    j.limpiar_tramas()
    j.pulsar(BTN_RST)
    j.correr_vueltas(15)
    r.igual(j.var("GAME_PHASE"), FASE_COLOC, "GAME_RST vuelve a la colocacion")
    r.igual((j.var("P1_WINS"), j.var("P2_WINS")), victorias_previas,
            "GAME_RST conserva el marcador acumulado")
    r.igual(j.var("P1_READY"), 0, "GAME_RST borra el estado de listo de J1")
    r.igual(j.var("P2_READY"), 0, "GAME_RST borra el estado de listo de J2")
    r.igual(j.casilla(1, 0, 0), 0, "GAME_RST limpia el tablero de J1")
    r.igual(j.casilla(2, 0, 0), 0, "GAME_RST limpia el tablero de J2")
    r.igual(j.barco(1, 0, "SH_PLACED"), 0, "GAME_RST libera la metadata de los barcos")
    r.igual(j.var("CURRENT_TURN"), 1, "tras GAME_RST vuelve a empezar J1")
    r.igual(j.ultima_trama(T_PLACEMENT_START), list(victorias_previas),
            "PLACEMENT_START tras GAME_RST lleva el marcador conservado")

    # --- La fase de resultado ignora los botones de juego ---
    j = partida_ganada_por_j2()
    j.limpiar_tramas()
    turno_antes = j.var("CURRENT_TURN")
    j.pulsar(BTN_OK)
    j.pulsar(BTN_DOWN)
    j.correr_vueltas(10)
    r.igual(j.var("GAME_PHASE"), FASE_RESULT,
            "en fase de resultado los botones no cambian la fase")
    r.igual(j.var("CURRENT_TURN"), turno_antes,
            "en fase de resultado no se alteran los turnos")

    # --- Saturacion del marcador en 99 ---
    j = Juego()
    j.sim.escribir_ram(j.simbolos["P2_WINS"], 99)
    ganar_partida_j2(j)
    r.igual(j.var("P2_WINS"), 99, "el marcador satura en 99 victorias")


def partida_ganada_por_j2():
    """Juega una partida completa que gana J2 hundiendo la flota de J1."""
    j = Juego()
    ganar_partida_j2(j)
    return j


def ganar_partida_j2(j):
    j.colocar_flota_j2()
    j.colocar_flota_j1()
    j.correr_vueltas(15)
    j.mover(BTN_DOWN, 7)
    objetivos = [(0, 0), (0, 1), (0, 2), (0, 3),
                 (2, 0), (2, 1), (2, 2), (4, 0), (4, 1)]
    for i, (fila, col) in enumerate(objetivos):
        if 0 < i < 8:
            j.mover(comun.BTN_RIGHT, 1)
        elif i == 8:
            j.mover(comun.BTN_UP, 1)
        j.pulsar(BTN_OK)                  # J1 falla sobre agua
        j.enviar_shot(fila, col)          # J2 acierta
    j.correr_vueltas(30)
    return j


def main():
    r = Resultados("Control de estado del juego")
    pruebas(r)
    return r.reportar()


if __name__ == "__main__":
    sys.exit(main())
