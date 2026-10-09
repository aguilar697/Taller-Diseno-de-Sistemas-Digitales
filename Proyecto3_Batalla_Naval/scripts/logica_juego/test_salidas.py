"""Pruebas del bloque ACTUALIZACION DE PERIFERICOS DE SALIDA (VGA, LED,
displays y buzzer)."""

import sys
from comun import (Juego, Resultados, BTN_OK, BTN_SEL, BTN_DOWN, BTN_RIGHT,
                   BTN_UP, FASE_COLOC, FASE_BATALLA, FASE_RESULT)

COL_FONDO, COL_AGUA, COL_BARCO = 0, 1, 2
COL_IMPACTO, COL_FALLO, COL_CURSOR, COL_HUD = 3, 4, 5, 6


def partida_ganada_por_j2(j):
    """Juega una partida completa en la que J2 hunde la flota de J1."""
    j.colocar_flota_j2()
    j.colocar_flota_j1()
    j.correr_vueltas(15)
    j.mover(BTN_DOWN, 7)
    objetivos = [(0, 0), (0, 1), (0, 2), (0, 3),
                 (2, 0), (2, 1), (2, 2), (4, 0), (4, 1)]
    for i, (fila, col) in enumerate(objetivos):
        if 0 < i < 8:
            j.mover(BTN_RIGHT, 1)
        elif i == 8:
            j.mover(BTN_UP, 1)
        j.pulsar(BTN_OK)
        j.enviar_shot(fila, col)
    j.correr_vueltas(30)
    return j


def pruebas(r):
    # --- El tablero propio muestra los barcos de J1 ---
    # Se aparta el cursor: su previsualizacion se dibuja encima del tablero y
    # taparia el barco recien colocado.
    j = Juego()
    j.pulsar(BTN_OK)                       # J1 coloca el barco de 4 en (0,0)
    j.mover(BTN_DOWN, 6)
    j.correr_vueltas(5)
    r.igual([j.tile_tablero("propio", 0, c) for c in range(5)],
            [COL_BARCO] * 4 + [COL_AGUA],
            "el tablero propio dibuja los barcos de J1")

    # --- REGLA CRITICA: el tablero rival nunca revela barcos intactos ---
    j = Juego()
    j.colocar_flota_j2()                   # J2 coloca en filas 0, 2 y 4
    j.correr_vueltas(10)
    rival = [[j.tile_tablero("rival", f, c) for c in range(8)] for f in range(8)]
    hay_barco_visible = any(COL_BARCO in fila for fila in rival)
    r.check(not hay_barco_visible,
            "ninguna casilla del tablero rival se dibuja como barco")
    r.igual(rival[0], [COL_AGUA] * 8,
            "la fila con el barco de 4 de J2 se ve como agua desde J1")
    r.igual(j.casilla(2, 0, 0), 1,
            "el barco si esta en la RAM: lo que se oculta es la presentacion")

    # --- Al impactar, la casilla rival se revela ---
    j = Juego()
    j.colocar_flota_j2()
    j.colocar_flota_j1()
    j.correr_vueltas(15)
    j.pulsar(BTN_OK)                       # J1 acierta en (0,0)
    j.mover(BTN_DOWN, 5)                   # aparta el cursor de la casilla
    j.correr_vueltas(10)
    r.igual(j.tile_tablero("rival", 0, 0), COL_IMPACTO,
            "un impacto se revela en el tablero rival")
    r.igual(j.tile_tablero("rival", 0, 1), COL_AGUA,
            "la casilla contigua del mismo barco sigue oculta")

    j.enviar_shot(7, 7)                    # J2 falla sobre el tablero de J1
    j.correr_vueltas(10)
    r.igual(j.tile_tablero("propio", 7, 7), COL_FALLO,
            "un fallo recibido se dibuja en el tablero propio")

    # --- Cursor ---
    j = Juego()
    j.mover(BTN_DOWN, 2)
    j.mover(BTN_RIGHT, 3)
    j.correr_vueltas(5)
    r.igual(j.tile_tablero("propio", 2, 3), COL_CURSOR,
            "en colocacion el cursor marca el tablero propio")
    r.igual([j.tile_tablero("propio", 2, c) for c in range(3, 7)],
            [COL_CURSOR] * 4,
            "el cursor previsualiza el barco completo horizontal")

    j.pulsar(BTN_SEL)                      # rota a vertical
    j.correr_vueltas(5)
    r.igual([j.tile_tablero("propio", f, 3) for f in range(2, 6)],
            [COL_CURSOR] * 4,
            "tras rotar, la previsualizacion es vertical")

    j = Juego()
    j.colocar_flota_j2()
    j.colocar_flota_j1()
    j.correr_vueltas(15)
    r.igual(j.tile_tablero("rival", 0, 0), COL_CURSOR,
            "en batalla el cursor marca el tablero rival")
    r.check(j.tile_tablero("propio", 0, 0) != COL_CURSOR,
            "en batalla el cursor no aparece en el tablero propio")

    # --- La previsualizacion no se sale del tablero ---
    j = Juego()
    j.mover(BTN_RIGHT, 7)                  # columna 7 con un barco de 4
    j.correr_vueltas(5)
    r.igual(j.tile_tablero("propio", 0, 7), COL_CURSOR,
            "el cursor se dibuja en la ultima columna")
    r.igual(j.color_tile(j.simbolos["TAB_FILA"],
                         j.simbolos["TAB_COL_PROPIO"] + 8), COL_FONDO,
            "la previsualizacion no invade la pantalla fuera del tablero")

    # --- LED por fase ---
    j = Juego()
    r.igual(j.sim.led, FASE_COLOC, "LED en colocacion")
    j.colocar_flota_j2()
    j.colocar_flota_j1()
    j.correr_vueltas(15)
    r.igual(j.sim.led, FASE_BATALLA, "LED en batalla")

    # --- Displays: J1 en el byte bajo, J2 en el siguiente ---
    j = Juego()
    r.igual(j.sim.display, 0, "el marcador arranca en cero")
    # Se comprueba por el camino real: el marcador solo cambia al terminar una
    # partida, y es ahi donde el programa refresca los displays.
    j.sim.escribir_ram(j.simbolos["P1_WINS"], 7)
    j.sim.escribir_ram(j.simbolos["P2_WINS"], 11)
    partida_ganada_por_j2(j)
    r.igual(j.sim.display & 0xFF, 7, "las victorias de J1 van en el byte bajo")
    r.igual((j.sim.display >> 8) & 0xFF, 12,
            "las victorias de J2 van en el byte siguiente, ya incrementadas")

    # --- Buzzer: cada evento tiene su codigo ---
    j = Juego()
    j.mover(BTN_RIGHT, 7)
    j.pulsar(BTN_OK)                       # colocacion invalida
    r.igual(j.sim.ordenes_buzzer[-1], 4, "colocacion invalida suena como tal")

    j = Juego()
    j.colocar_flota_j2()
    j.colocar_flota_j1()
    j.correr_vueltas(15)
    n_antes = len(j.sim.ordenes_buzzer)
    j.pulsar(BTN_OK)                       # acierto
    j.correr_vueltas(5)
    r.igual(j.sim.ordenes_buzzer[-1], 1, "el acierto suena como impacto")
    r.check(len(j.sim.ordenes_buzzer) > n_antes,
            "cada evento escribe una orden nueva al buzzer")

    # --- El HUD muestra el titulo y el marcador ---
    j = Juego()
    j.correr_vueltas(5)
    titulo = [(j.tile(0, c) >> 4) & 0xFF for c in range(3, 16)]
    r.igual("".join(chr(c) for c in titulo), "BATALLA NAVAL",
            "el HUD escribe el titulo del juego")
    r.check(all((j.tile(0, c) & 0x8) != 0 for c in range(3, 16)),
            "los tiles de texto llevan activo el bit de glifo")

    j.sim.escribir_ram(j.simbolos["P1_WINS"], 42)
    j.pulsar(BTN_SEL)
    j.correr_vueltas(5)
    col = j.simbolos["TAB_COL_PROPIO"] + 3
    digitos = [chr((j.tile(3, col + i) >> 4) & 0xFF) for i in range(2)]
    r.igual("".join(digitos), "42", "el HUD muestra el marcador de J1 con dos digitos")

    # --- La zona reservada de la memoria de video no se toca ---
    j = Juego()
    j.correr_vueltas(5)
    r.check(all(v == 0 for v in j.sim.vga[300:]),
            "el programa no escribe en los indices reservados de la VGA")

    # --- En fase de resultado se anuncia el ganador ---
    j = partida_ganada_por_j2(Juego())
    r.igual(j.var("GAME_PHASE"), FASE_RESULT, "la partida llego al resultado")
    r.igual(j.sim.led, FASE_RESULT, "LED en fase de resultado")
    fila = j.simbolos["FILA_MSG"]
    texto = "".join(chr((j.tile(fila, 1 + i) >> 4) & 0xFF) for i in range(7))
    r.igual(texto, "GANA J2", "el mensaje de victoria aparece en pantalla")


def main():
    r = Resultados("Actualizacion de perifericos de salida")
    pruebas(r)
    return r.reportar()


if __name__ == "__main__":
    sys.exit(main())
