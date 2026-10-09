"""Pruebas del bloque DETECCION DE HUNDIDO Y VICTORIA."""

import sys
from comun import (Juego, Resultados, BTN_OK, BTN_DOWN, BTN_RIGHT, BTN_UP,
                   ORIENT_V, RES_HIT, RES_SUNK, FASE_RESULT,
                   T_SHOT_RESULT, T_GAME_OVER)

SND_VICTORY = 5


def batalla_con(posiciones_j2=None):
    j = Juego()
    j.colocar_flota_j2(posiciones_j2)
    j.colocar_flota_j1()
    j.correr_vueltas(15)
    j.limpiar_tramas()
    return j


def pruebas(r):
    # --- El contador de impactos crece y solo hunde al completarse ---
    j = batalla_con()
    j.mover(BTN_DOWN, 4)                      # barco de 2 de J2 en (4,0)-(4,1)
    j.pulsar(BTN_OK)
    j.correr_vueltas(8)
    r.igual(j.barco(2, 2, "SH_HITS"), 1, "el primer impacto se contabiliza")
    r.igual(j.barco(2, 2, "SH_SUNK"), 0, "con un impacto el barco no esta hundido")

    j.enviar_shot(7, 0)                       # J2 falla y devuelve el turno
    j.mover(BTN_RIGHT, 1)
    j.limpiar_tramas()
    j.pulsar(BTN_OK)                          # completa el barco de 2
    j.correr_vueltas(8)
    r.igual(j.barco(2, 2, "SH_HITS"), 2, "el segundo impacto completa el barco")
    r.igual(j.barco(2, 2, "SH_SUNK"), 1, "el barco queda marcado como hundido")
    r.igual(j.var("P1_SUNK"), 1, "J1 contabiliza un barco enemigo hundido")
    r.igual(j.var("P2_SUNK"), 0, "J2 no ha hundido nada todavia")

    # --- Un barco hundido no se vuelve a contar ---
    # Las casillas ya impactadas se rechazan como disparo repetido, de modo
    # que el contador no puede incrementarse dos veces por el mismo barco.
    disparos_antes = j.var("P1_SUNK")
    j.enviar_shot(7, 1)
    j.pulsar(BTN_OK)                          # repite (4,1), ya impactada
    j.correr_vueltas(8)
    r.igual(j.var("P1_SUNK"), disparos_antes,
            "repetir el disparo sobre un barco hundido no lo cuenta otra vez")
    r.igual(j.barco(2, 2, "SH_HITS"), 2, "los impactos del barco no se duplican")

    # --- Hundir un barco vertical ---
    j = batalla_con([(0, 0, 0), (2, 0, 0), (4, 4, ORIENT_V)])
    j.mover(BTN_DOWN, 4)
    j.mover(BTN_RIGHT, 4)
    j.limpiar_tramas()
    j.pulsar(BTN_OK)                          # (4,4)
    j.correr_vueltas(8)
    r.igual(j.ultima_trama(T_SHOT_RESULT) or
            [p for t, p in j.tramas if t == 0x84][-1], [4, 4, RES_HIT],
            "primer impacto sobre el barco vertical")
    j.enviar_shot(7, 0)
    j.mover(BTN_DOWN, 1)
    j.limpiar_tramas()
    j.pulsar(BTN_OK)                          # (5,4) completa el barco de 2
    j.correr_vueltas(8)
    r.igual([p for t, p in j.tramas if t == 0x84][-1], [5, 4, RES_SUNK],
            "el barco vertical tambien se detecta hundido")

    # --- Victoria: hundir los tres barcos rivales ---
    j = batalla_con()
    objetivos = [(0, 0), (0, 1), (0, 2), (0, 3),
                 (2, 0), (2, 1), (2, 2), (4, 0), (4, 1)]
    j.mover(BTN_DOWN, 7)
    for i, (fila, col) in enumerate(objetivos):
        if 0 < i < 8:
            j.mover(BTN_RIGHT, 1)
        elif i == 8:
            j.mover(BTN_UP, 1)
        j.pulsar(BTN_OK)                      # J1 falla sobre agua
        j.enviar_shot(fila, col)              # J2 acierta
    j.correr_vueltas(30)

    r.igual(j.var("GAME_PHASE"), FASE_RESULT, "la partida pasa a fase de resultado")
    r.igual(j.var("WINNER"), 2, "gana quien hundio los tres barcos")
    r.igual(j.var("P2_SUNK"), 3, "el ganador acumula tres barcos hundidos")
    r.igual(j.var("P2_WINS"), 1, "el marcador del ganador sube")
    r.igual(j.var("P1_WINS"), 0, "el marcador del perdedor no cambia")
    r.igual(j.sim.ordenes_buzzer[-1], SND_VICTORY,
            "el disparo que termina la partida suena como victoria")

    fin = j.ultima_trama(T_GAME_OVER)
    r.check(fin is not None, "se emite GAME_OVER al terminar la partida")
    if fin:
        r.igual(len(fin), 7, "GAME_OVER lleva siete campos")
        r.igual(fin[0], 2, "GAME_OVER indica el ganador")
        r.igual(fin[1], j.var("P1_SHOTS"), "GAME_OVER informa los disparos de J1")
        r.igual(fin[2], j.var("P2_SHOTS"), "GAME_OVER informa los disparos de J2")
        r.igual(fin[3], 0, "GAME_OVER informa los barcos hundidos por J1")
        r.igual(fin[4], 3, "GAME_OVER informa los barcos hundidos por J2")
        r.igual(fin[5], 0, "GAME_OVER informa las victorias de J1")
        r.igual(fin[6], 1, "GAME_OVER informa las victorias de J2")

    # --- Tras la victoria no se admiten mas disparos ---
    j.limpiar_tramas()
    turno = j.var("CURRENT_TURN")
    j.pulsar(BTN_OK)
    j.enviar_shot(1, 1)
    j.correr_vueltas(10)
    r.igual(j.var("GAME_PHASE"), FASE_RESULT, "la fase de resultado se mantiene")
    r.igual(j.var("CURRENT_TURN"), turno, "no se alteran los turnos tras el final")
    r.igual(j.casilla(1, 1, 1), 0, "el tablero ya no cambia tras el final")


def main():
    r = Resultados("Deteccion de hundido y victoria")
    pruebas(r)
    return r.reportar()


if __name__ == "__main__":
    sys.exit(main())
