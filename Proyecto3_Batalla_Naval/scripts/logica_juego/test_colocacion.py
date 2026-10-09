"""Pruebas del bloque GESTION DE COLOCACION DE BARCOS."""

import sys
from comun import (Juego, Resultados, BTN_OK, BTN_SEL, BTN_DOWN, BTN_RIGHT,
                   ORIENT_H, ORIENT_V, BARCO, AGUA, T_PLACE_RESULT,
                   FASE_COLOC, FASE_BATALLA)

PR_OK, PR_OVERLAP, PR_OUT_OF_BOUNDS = 0, 1, 2
PR_INVALID_SHIP, PR_ALREADY_PLACED, PR_INVALID_ORIENTATION = 3, 4, 5


def colocar(j, ship_id, fila, col, orient):
    """Envia un PLACE de J2 y devuelve (accepted, reason)."""
    j.limpiar_tramas()
    j.enviar_place(ship_id, fila, col, orient)
    respuesta = j.ultima_trama(T_PLACE_RESULT)
    if respuesta is None:
        return (None, None)
    return (respuesta[1], respuesta[2])


def pruebas(r):
    # --- Colocacion valida horizontal ---
    j = Juego()
    r.igual(colocar(j, 0, 0, 0, ORIENT_H), (1, PR_OK), "colocacion horizontal valida")
    r.igual([j.casilla(2, 0, c) for c in range(5)], [BARCO] * 4 + [AGUA],
            "el barco de longitud 4 ocupa exactamente 4 casillas")
    r.igual(j.barco(2, 0, "SH_PLACED"), 1, "la metadata marca el barco como colocado")
    r.igual(j.barco(2, 0, "SH_ROW"), 0, "la metadata guarda la fila")
    r.igual(j.barco(2, 0, "SH_COL"), 0, "la metadata guarda la columna")
    r.igual(j.barco(2, 0, "SH_ORIENT"), ORIENT_H, "la metadata guarda la orientacion")
    r.igual(j.barco(2, 0, "SH_LEN"), 4, "el barco 0 mide 4 casillas")
    r.igual(j.barco(2, 1, "SH_LEN"), 3, "el barco 1 mide 3 casillas")
    r.igual(j.barco(2, 2, "SH_LEN"), 2, "el barco 2 mide 2 casillas")

    # --- Colocacion valida vertical ---
    j = Juego()
    r.igual(colocar(j, 0, 2, 5, ORIENT_V), (1, PR_OK), "colocacion vertical valida")
    r.igual([j.casilla(2, f, 5) for f in range(2, 7)], [BARCO] * 4 + [AGUA],
            "el barco vertical ocupa 4 filas de la misma columna")

    # --- Traslape ---
    j = Juego()
    colocar(j, 0, 0, 0, ORIENT_H)
    r.igual(colocar(j, 1, 0, 2, ORIENT_H), (0, PR_OVERLAP),
            "se rechaza un barco que se traslapa")
    r.igual(j.barco(2, 1, "SH_PLACED"), 0, "un rechazo no marca el barco como colocado")
    r.igual(colocar(j, 1, 0, 3, ORIENT_V), (0, PR_OVERLAP),
            "se detecta traslape aunque la orientacion sea distinta")
    r.igual(colocar(j, 1, 1, 0, ORIENT_H), (1, PR_OK),
            "una fila libre contigua si se acepta")

    # --- Fuera del tablero: borde y casos limite ---
    j = Juego()
    r.igual(colocar(j, 0, 0, 5, ORIENT_H), (0, PR_OUT_OF_BOUNDS),
            "un barco de 4 en la columna 5 se sale del tablero")
    r.igual(colocar(j, 0, 0, 4, ORIENT_H), (1, PR_OK),
            "en la columna 4 el barco de 4 entra justo")
    j = Juego()
    r.igual(colocar(j, 0, 5, 0, ORIENT_V), (0, PR_OUT_OF_BOUNDS),
            "un barco de 4 en la fila 5 se sale por abajo")
    r.igual(colocar(j, 0, 4, 0, ORIENT_V), (1, PR_OK),
            "en la fila 4 el barco vertical de 4 entra justo")
    j = Juego()
    r.igual(colocar(j, 2, 7, 7, ORIENT_H), (0, PR_OUT_OF_BOUNDS),
            "la esquina no admite un barco de 2")
    r.igual(colocar(j, 2, 7, 6, ORIENT_H), (1, PR_OK),
            "el barco de 2 cabe justo en el borde derecho")

    # --- Coordenadas fuera de rango ---
    j = Juego()
    r.igual(colocar(j, 0, 8, 0, ORIENT_H), (0, PR_OUT_OF_BOUNDS),
            "una fila fuera del tablero se rechaza")
    r.igual(colocar(j, 0, 0, 200, ORIENT_H), (0, PR_OUT_OF_BOUNDS),
            "una columna muy grande se rechaza sin desbordar")

    # --- Identificador y orientacion invalidos ---
    j = Juego()
    r.igual(colocar(j, 3, 0, 0, ORIENT_H), (0, PR_INVALID_SHIP),
            "un identificador de barco fuera de 0..2 se rechaza")
    r.igual(colocar(j, 250, 0, 0, ORIENT_H), (0, PR_INVALID_SHIP),
            "un identificador grande se rechaza sin desbordar")
    r.igual(colocar(j, 0, 0, 0, 7), (0, PR_INVALID_ORIENTATION),
            "una orientacion distinta de 0 o 1 se rechaza")

    # --- Un barco aceptado no se puede reemplazar ---
    j = Juego()
    colocar(j, 0, 0, 0, ORIENT_H)
    r.igual(colocar(j, 0, 5, 5, ORIENT_H), (0, PR_ALREADY_PLACED),
            "no se puede recolocar un barco ya aceptado")
    r.igual(j.barco(2, 0, "SH_ROW"), 0, "la posicion original se conserva")

    # --- El estado de listo depende de los tres barcos ---
    j = Juego()
    colocar(j, 0, 0, 0, ORIENT_H)
    r.igual(j.var("P2_READY"), 0, "con un barco colocado aun no esta listo")
    colocar(j, 1, 2, 0, ORIENT_H)
    r.igual(j.var("P2_READY"), 0, "con dos barcos colocados aun no esta listo")
    colocar(j, 2, 4, 0, ORIENT_H)
    r.igual(j.var("P2_READY"), 1, "con los tres barcos queda listo")

    # --- Colocacion concurrente: el avance de uno no bloquea al otro ---
    j = Juego()
    j.pulsar(BTN_OK)                                  # J1 coloca su barco 0
    colocar(j, 0, 6, 0, ORIENT_H)                     # J2 coloca el suyo
    j.pulsar(BTN_DOWN)
    j.pulsar(BTN_DOWN)
    j.pulsar(BTN_OK)                                  # J1 coloca su barco 1
    colocar(j, 1, 0, 0, ORIENT_H)
    r.igual(j.barco(1, 0, "SH_PLACED"), 1, "J1 avanzo su primer barco")
    r.igual(j.barco(1, 1, "SH_PLACED"), 1, "J1 avanzo su segundo barco")
    r.igual(j.barco(2, 0, "SH_PLACED"), 1, "J2 avanzo su primer barco")
    r.igual(j.barco(2, 1, "SH_PLACED"), 1, "J2 avanzo su segundo barco")
    r.igual(j.var("GAME_PHASE"), FASE_COLOC,
            "ninguno de los dos bloqueo al otro ni adelanto la fase")

    # --- J1 por botones: cursor, rotacion y confirmacion ---
    j = Juego()
    j.pulsar(BTN_SEL)                                 # rota a vertical
    j.pulsar(BTN_OK)
    r.igual(j.barco(1, 0, "SH_ORIENT"), ORIENT_V,
            "SEL rota la orientacion antes de confirmar")
    r.igual([j.casilla(1, f, 0) for f in range(4)], [BARCO] * 4,
            "el barco vertical de J1 ocupa cuatro filas")

    j = Juego()
    j.mover(BTN_DOWN, 3)
    j.mover(BTN_RIGHT, 2)
    j.pulsar(BTN_OK)
    r.igual(j.barco(1, 0, "SH_ROW"), 3, "el cursor bajo tres filas")
    r.igual(j.barco(1, 0, "SH_COL"), 2, "el cursor avanzo dos columnas")

    # --- El cursor se detiene en el borde ---
    j = Juego()
    j.mover(BTN_DOWN, 12)
    j.mover(BTN_RIGHT, 12)
    r.igual(j.var("CUR_ROW"), 7, "el cursor no pasa de la fila 7")
    r.igual(j.var("CUR_COL"), 7, "el cursor no pasa de la columna 7")

    # --- Una colocacion invalida de J1 suena y no ocupa casillas ---
    j = Juego()
    j.mover(BTN_RIGHT, 7)                             # columna 7, barco de 4
    ordenes_antes = len(j.sim.ordenes_buzzer)
    j.pulsar(BTN_OK)
    r.igual(j.barco(1, 0, "SH_PLACED"), 0,
            "una colocacion invalida de J1 no se registra")
    r.check(len(j.sim.ordenes_buzzer) > ordenes_antes and
            j.sim.ordenes_buzzer[-1] == 4,
            "una colocacion invalida de J1 avisa con el buzzer")

    # --- Fuera de la fase de colocacion no se colocan barcos ---
    j = Juego()
    j.colocar_flota_j2()
    j.colocar_flota_j1()
    j.correr_vueltas(15)
    r.igual(j.var("GAME_PHASE"), FASE_BATALLA, "la partida entro en batalla")
    j.limpiar_tramas()
    j.enviar_place(0, 0, 0, ORIENT_H)
    r.check(j.ultima_trama(T_PLACE_RESULT) is None,
            "un PLACE en batalla no se responde como colocacion")


def main():
    r = Resultados("Gestion de colocacion de barcos")
    pruebas(r)
    return r.reportar()


if __name__ == "__main__":
    sys.exit(main())
