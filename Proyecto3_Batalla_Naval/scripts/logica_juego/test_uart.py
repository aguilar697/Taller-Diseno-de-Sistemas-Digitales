"""Pruebas del bloque COMUNICACION UART (protocolo y parser)."""

import sys
from comun import (Juego, Resultados, SOF, ORIENT_H, BTN_RIGHT,
                   T_PLACE, T_SHOT, T_PLACE_RESULT, T_ERROR, T_PLACEMENT_START,
                   T_BATTLE_START)

ER_INVALID_MESSAGE = 1


def pruebas(r):
    # --- Trama valida basica ---
    j = Juego()
    j.limpiar_tramas()
    j.enviar_place(0, 0, 0, ORIENT_H)
    r.igual(j.ultima_trama(T_PLACE_RESULT), [0, 1, 0],
            "una trama PLACE bien formada se acepta")

    # --- Tipo desconocido ---
    j = Juego()
    j.limpiar_tramas()
    j.enviar_trama(0x42, [1, 2])
    r.igual(j.ultima_trama(T_ERROR), [0x42, ER_INVALID_MESSAGE],
            "un tipo desconocido se rechaza indicando cual era")

    # --- Longitud incorrecta para un tipo valido ---
    j = Juego()
    j.limpiar_tramas()
    j.enviar_trama(T_PLACE, [0, 0, 0])            # PLACE necesita 4 bytes
    r.igual(j.ultima_trama(T_ERROR), [T_PLACE, ER_INVALID_MESSAGE],
            "una longitud incorrecta en PLACE se rechaza")
    j.limpiar_tramas()
    j.enviar_trama(T_SHOT, [1, 2, 3])             # SHOT necesita 2 bytes
    r.igual(j.ultima_trama(T_ERROR), [T_SHOT, ER_INVALID_MESSAGE],
            "una longitud incorrecta en SHOT se rechaza")

    # --- Tras rechazar una trama, la siguiente valida se procesa ---
    j.limpiar_tramas()
    j.enviar_place(0, 1, 1, ORIENT_H)
    r.igual(j.ultima_trama(T_PLACE_RESULT), [0, 1, 0],
            "el parser se recupera y acepta la trama siguiente")

    # --- Bytes sueltos antes del inicio de trama se ignoran ---
    j = Juego()
    j.limpiar_tramas()
    j.sim.alimentar_rx([0x00, 0x77, 0xFF])
    j.correr_vueltas(10)
    r.igual(j.tramas, [], "la basura fuera de trama no genera respuesta")
    j.enviar_place(0, 0, 0, ORIENT_H)
    r.igual(j.ultima_trama(T_PLACE_RESULT), [0, 1, 0],
            "tras la basura se sincroniza con el siguiente SOF")

    # --- Un 0xA5 dentro del payload es un dato, no un nuevo inicio ---
    j = Juego()
    j.limpiar_tramas()
    # SHOT con fila 0xA5: coordenada invalida, pero debe llegar como payload.
    j.enviar_trama(T_SHOT, [SOF, 0])
    error = j.ultima_trama(T_ERROR)
    r.check(error is not None and error[0] == T_SHOT,
            "un 0xA5 dentro del payload no reinicia la trama")

    j = Juego()
    j.limpiar_tramas()
    # PLACE con columna 0xA5: se procesa como coordenada fuera del tablero.
    j.enviar_trama(T_PLACE, [0, 0, SOF, ORIENT_H])
    r.igual(j.ultima_trama(T_PLACE_RESULT), [0, 0, 2],
            "el 0xA5 del payload se interpreta como dato fuera de rango")

    # --- Trama incompleta: se abandona tras un numero finito de vueltas ---
    j = Juego()
    j.limpiar_tramas()
    j.sim.alimentar_rx([SOF, T_PLACE, 4, 0])      # faltan tres bytes
    j.correr_vueltas(30)
    r.check(j.var("RX_STATE") != 0, "la trama incompleta deja el parser ocupado")
    r.check(j.var("RX_AGE") > 0, "la trama incompleta envejece")
    j.correr_vueltas(2100)                         # supera RX_EDAD_MAX = 2000
    r.igual(j.var("RX_STATE"), 0,
            "la trama incompleta se abandona al superar el limite de vueltas")
    j.limpiar_tramas()
    j.enviar_place(0, 0, 0, ORIENT_H)
    r.igual(j.ultima_trama(T_PLACE_RESULT), [0, 1, 0],
            "tras abandonar la trama incompleta se vuelve a aceptar trafico")

    # --- UART real: un solo byte de recepcion, sin FIFO ---
    # A 115200 baudios llega un byte cada 8680 ciclos. Ninguna vuelta del
    # ciclo de servicio puede tardar mas,
    # o un byte se pisaria con el siguiente. El peor caso es el redibujado:
    # aqui se envian tramas justo mientras se redibuja la pantalla completa.
    j = Juego()
    j.limpiar_tramas()
    j.sim.pulsar(BTN_RIGHT)                         # mover el cursor ensucia la pantalla
    j._vueltas_exactas(2)
    j.sim.pulsar(0)
    r.check(j.var("VGA_DIRTY") == 1, "hay un redibujado en curso al llegar la trama")
    j.enviar_place(0, 0, 0, ORIENT_H)
    j.enviar_place(1, 2, 0, ORIENT_H)
    r.igual(j.sim.rx_perdidos, 0, "ningun byte se pierde aunque se redibuje la pantalla")
    r.igual(j.tramas_de(T_PLACE_RESULT), [[0, 1, 0], [1, 1, 0]],
            "las dos tramas recibidas durante el redibujado se procesan")

    # --- Transmision a velocidad real: la TX se usa solo cuando esta lista ---
    j = Juego(ciclos_tx=8680)
    j.colocar_flota_j2()
    j.colocar_flota_j1()
    j.drenar()
    r.igual(j.sim.tx_ignorados, 0,
            "nunca se escribe TX_DATA con la transmision ocupada")
    r.check(any(t == T_BATTLE_START for t, _ in j.tramas),
            "a velocidad real salen todas las tramas, hasta BATTLE_START")

    # --- Orden de las tramas de salida ---
    j = Juego()
    j.colocar_flota_j2()
    j.limpiar_tramas()
    j.colocar_flota_j1()
    j.correr_vueltas(20)
    tipos = [t for t, _ in j.tramas]
    r.check(tipos.count(0x81) == 1, "BATTLE_START se emite una sola vez")
    if 0x81 in tipos:
        r.check(tipos.index(0x81) < tipos.index(0x82),
                "BATTLE_START precede al primer TURN")

    # --- PLACE_RESULT llega antes que BATTLE_START cuando lo cierra J2 ---
    j = Juego()
    j.colocar_flota_j1()
    j.correr_vueltas(10)
    j.limpiar_tramas()
    j.colocar_flota_j2()
    j.correr_vueltas(20)
    tipos = [t for t, _ in j.tramas]
    r.check(T_PLACE_RESULT in tipos and 0x81 in tipos,
            "se emiten PLACE_RESULT y BATTLE_START")
    if T_PLACE_RESULT in tipos and 0x81 in tipos:
        ultimo_place = len(tipos) - 1 - tipos[::-1].index(T_PLACE_RESULT)
        r.check(ultimo_place < tipos.index(0x81),
                "la respuesta a la ultima colocacion precede a BATTLE_START")

    # --- Todas las tramas emitidas respetan el formato ---
    j = Juego()
    j.colocar_flota_j2()
    j.colocar_flota_j1()
    j.correr_vueltas(20)
    bien_formadas = True
    for tipo, payload in j.tramas:
        if tipo not in (0x80, 0x81, 0x82, 0x83, 0x84, 0x85, 0x86, 0x87):
            bien_formadas = False
        if any(b > 0xFF for b in payload):
            bien_formadas = False
    r.check(bien_formadas, "todas las tramas emitidas usan tipos y bytes validos")
    r.check(len(j.tramas_de(T_PLACEMENT_START)) == 1,
            "PLACEMENT_START se emite una sola vez por partida")


def main():
    r = Resultados("Comunicacion UART")
    pruebas(r)
    return r.reportar()


if __name__ == "__main__":
    sys.exit(main())
