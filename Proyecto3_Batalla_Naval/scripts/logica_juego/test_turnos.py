"""Pruebas del bloque GESTION DE TURNOS Y DISPAROS."""

import sys
from comun import (Juego, Resultados, BTN_OK, BTN_DOWN, BTN_RIGHT, BTN_UP,
                   ORIENT_H, AGUA, BARCO, FALLO, HIT,
                   RES_MISS, RES_HIT, RES_SUNK,
                   T_SHOT_RESULT, T_INCOMING_SHOT, T_ERROR, T_TURN)

ER_WRONG_PHASE, ER_WRONG_TURN = 2, 3
ER_REPEATED_SHOT, ER_INVALID_COORDINATE = 4, 5
SND_HIT, SND_MISS, SND_SUNK, SND_INVALID = 1, 2, 3, 4


def en_batalla():
    """Partida con ambas flotas en filas 0, 2 y 4, lista para disparar."""
    j = Juego()
    j.colocar_flota_j2()
    j.colocar_flota_j1()
    j.correr_vueltas(15)
    j.limpiar_tramas()
    return j


def disparo_j2(j, fila, col):
    """Dispara como J2 y devuelve ('SHOT_RESULT'|'ERROR', payload)."""
    j.limpiar_tramas()
    j.enviar_shot(fila, col)
    resultado = j.ultima_trama(T_SHOT_RESULT)
    if resultado is not None:
        return ("SHOT_RESULT", resultado)
    error = j.ultima_trama(T_ERROR)
    return ("ERROR", error) if error else (None, None)


def pruebas(r):
    # --- Disparo de J1: acierto sobre el tablero rival ---
    j = en_batalla()
    j.pulsar(BTN_OK)                        # cursor en (0,0), barco de J2
    j.correr_vueltas(10)
    r.igual(j.casilla(2, 0, 0), HIT, "el acierto marca la casilla como impacto")
    r.igual(j.ultima_trama(T_INCOMING_SHOT), [0, 0, RES_HIT],
            "el disparo de J1 se notifica como INCOMING_SHOT")
    r.igual(j.var("CURRENT_TURN"), 2, "tras un disparo valido el turno pasa al rival")
    r.igual(j.var("P1_SHOTS"), 1, "se contabiliza el disparo de J1")
    r.igual(j.sim.ordenes_buzzer[-1], SND_HIT, "un acierto suena como impacto")

    # --- Disparo de J2: fallo sobre agua ---
    tipo, payload = disparo_j2(j, 7, 7)
    r.igual((tipo, payload), ("SHOT_RESULT", [7, 7, RES_MISS]),
            "el disparo de J2 al agua devuelve fallo")
    r.igual(j.casilla(1, 7, 7), FALLO, "el fallo marca la casilla del tablero de J1")
    r.igual(j.var("CURRENT_TURN"), 1, "el turno vuelve a J1")
    r.igual(j.var("P2_SHOTS"), 1, "se contabiliza el disparo de J2")
    r.igual(j.sim.ordenes_buzzer[-1], SND_MISS, "un fallo suena distinto")

    # --- Disparo repetido: no consume turno ni cuenta ---
    j = en_batalla()
    j.pulsar(BTN_OK)                        # J1 acierta en (0,0)
    j.correr_vueltas(5)
    tipo, payload = disparo_j2(j, 3, 3)     # J2 falla en (3,3)
    r.igual(tipo, "SHOT_RESULT", "primer disparo de J2 aceptado")
    turno_antes = j.var("CURRENT_TURN")
    disparos_antes = j.var("P1_SHOTS")
    j.pulsar(BTN_OK)                        # J1 repite la casilla (0,0)
    j.correr_vueltas(10)
    r.igual(j.var("CURRENT_TURN"), turno_antes,
            "un disparo repetido de J1 no consume el turno")
    r.igual(j.var("P1_SHOTS"), disparos_antes,
            "un disparo repetido de J1 no cuenta como disparo")
    r.igual(j.sim.ordenes_buzzer[-1], SND_INVALID,
            "un disparo repetido de J1 avisa con el buzzer")

    # Para que J2 pueda repetir, antes J1 debe ceder el turno con un disparo
    # valido: mientras siga siendo turno de J1, el motivo correcto es el turno.
    tipo, payload = disparo_j2(j, 3, 3)
    r.igual((tipo, payload), ("ERROR", [0x11, ER_WRONG_TURN]),
            "fuera de turno se reporta el turno, no la repeticion")
    j.mover(BTN_DOWN, 6)
    j.pulsar(BTN_OK)                        # J1 dispara a una casilla nueva
    j.correr_vueltas(10)
    r.igual(j.var("CURRENT_TURN"), 2, "el disparo valido de J1 cede el turno")
    tipo, payload = disparo_j2(j, 3, 3)     # ahora si, J2 repite su casilla
    r.igual((tipo, payload), ("ERROR", [0x11, ER_REPEATED_SHOT]),
            "un disparo repetido de J2 se responde con ERROR, no con silencio")
    r.igual(j.var("CURRENT_TURN"), 2,
            "un disparo repetido de J2 tampoco consume su turno")

    # --- Disparo fuera de turno ---
    j = en_batalla()                        # arranca el turno de J1
    tipo, payload = disparo_j2(j, 5, 5)
    r.igual((tipo, payload), ("ERROR", [0x11, ER_WRONG_TURN]),
            "J2 no puede disparar en el turno de J1")
    r.igual(j.casilla(1, 5, 5), AGUA, "un disparo fuera de turno no toca el tablero")
    r.igual(j.var("CURRENT_TURN"), 1, "un disparo fuera de turno no altera el turno")

    # --- Coordenadas invalidas ---
    j = en_batalla()
    j.pulsar(BTN_OK)                        # cede el turno a J2
    j.correr_vueltas(5)
    tipo, payload = disparo_j2(j, 8, 0)
    r.igual((tipo, payload), ("ERROR", [0x11, ER_INVALID_COORDINATE]),
            "una fila fuera del tablero se rechaza")
    tipo, payload = disparo_j2(j, 0, 99)
    r.igual((tipo, payload), ("ERROR", [0x11, ER_INVALID_COORDINATE]),
            "una columna muy grande se rechaza sin desbordar")
    r.igual(j.var("CURRENT_TURN"), 2, "una coordenada invalida no consume el turno")

    # --- Disparo fuera de la fase de batalla ---
    j = Juego()
    tipo, payload = disparo_j2(j, 0, 0)
    r.igual((tipo, payload), ("ERROR", [0x11, ER_WRONG_PHASE]),
            "no se puede disparar durante la colocacion")

    # --- Hundimiento de un barco completo ---
    j = en_batalla()
    j.mover(BTN_DOWN, 4)                    # fila 4: barco de 2 de J2
    j.pulsar(BTN_OK)                        # (4,0) impacto
    j.correr_vueltas(5)
    j.enviar_shot(7, 0)                     # turno de J2
    j.mover(BTN_RIGHT, 1)
    j.limpiar_tramas()
    j.pulsar(BTN_OK)                        # (4,1) completa el barco
    j.correr_vueltas(10)
    r.igual(j.ultima_trama(T_INCOMING_SHOT), [4, 1, RES_SUNK],
            "el ultimo impacto de un barco se notifica como hundido")
    r.igual(j.barco(2, 2, "SH_SUNK"), 1, "la metadata marca el barco como hundido")
    r.igual(j.barco(2, 2, "SH_HITS"), 2, "el barco acumulo sus dos impactos")
    r.igual(j.var("P1_SUNK"), 1, "J1 suma un barco enemigo hundido")
    r.igual(j.sim.ordenes_buzzer[-1], SND_SUNK, "el hundimiento tiene sonido propio")

    # --- El turno se notifica en cada cambio ---
    j = en_batalla()
    j.limpiar_tramas()
    j.pulsar(BTN_OK)
    j.correr_vueltas(10)
    r.igual(j.ultima_trama(T_TURN), [2], "tras disparar J1 se anuncia el turno de J2")
    j.limpiar_tramas()
    j.enviar_shot(6, 6)
    r.igual(j.ultima_trama(T_TURN), [1], "tras disparar J2 se anuncia el turno de J1")


def main():
    r = Resultados("Gestion de turnos y disparos")
    pruebas(r)
    return r.reportar()


if __name__ == "__main__":
    sys.exit(main())
