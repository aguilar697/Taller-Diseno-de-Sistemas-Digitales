"""Escenario de partida completa usado por la prueba de integracion.

Incluye colocaciones invalidas de ambos jugadores, rotacion, disparo fuera de
turno, disparo repetido, hundimientos, victoria de J1 y GAME_RST.
"""

from comun import (BTN_UP, BTN_DOWN, BTN_LEFT, BTN_RIGHT, BTN_SEL, BTN_OK,
                   BTN_RST, T_PLACE, T_SHOT)


def escenario():
    B = lambda m, n=1: [("boton", m)] * n
    e = []
    # J2 intenta un barco que se sale del tablero y luego coloca su flota.
    e += [("tx", T_PLACE, [0, 0, 6, 0])]
    e += [("tx", T_PLACE, [0, 0, 0, 0]), ("tx", T_PLACE, [1, 2, 0, 0]),
          ("tx", T_PLACE, [2, 4, 0, 0])]
    # J1 rota a vertical, intenta una colocacion que se sale y coloca su flota.
    e += B(BTN_SEL) + B(BTN_DOWN, 5) + B(BTN_OK) + B(BTN_UP, 5)
    e += B(BTN_OK)                                   # barco 0 en (0,0) vertical
    e += B(BTN_RIGHT, 2) + B(BTN_OK)                 # barco 1 en (0,2)
    e += B(BTN_RIGHT, 2) + B(BTN_OK)                 # barco 2 en (0,4): batalla
    e += [("foto", "batalla")]
    e += [("tx", T_SHOT, [7, 7])]                    # J2 fuera de turno
    # Batalla: J1 hunde la flota de J2; J2 dispara al agua.
    agua = iter([(7, 0), (7, 1), (7, 2), (7, 3), (7, 4), (7, 5), (7, 6), (7, 7)])
    rutas_j1 = [[], [BTN_RIGHT], [BTN_RIGHT], [BTN_RIGHT],
                [BTN_DOWN, BTN_DOWN, BTN_LEFT, BTN_LEFT, BTN_LEFT], [BTN_RIGHT], [BTN_RIGHT],
                [BTN_DOWN, BTN_DOWN, BTN_LEFT, BTN_LEFT], [BTN_RIGHT]]
    for i, ruta in enumerate(rutas_j1):
        for m in ruta:
            e += B(m)
        e += B(BTN_OK)
        if i == len(rutas_j1) - 1:
            break
        if i == 3:
            e += [("tx", T_SHOT, [7, 0])]            # J2 repite una casilla
        e += [("tx", T_SHOT, list(next(agua)))]
    e += [("foto", "resultado"), ("volcado",)]
    e += B(BTN_RST)                                  # nueva partida
    return e

