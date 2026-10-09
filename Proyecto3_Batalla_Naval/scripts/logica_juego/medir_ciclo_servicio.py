"""Mide la vuelta mas larga del ciclo de servicio en una partida completa.

Reutiliza el escenario de la prueba de integracion y muestra el valor,
que test_integracion.py solo compara contra el limite.
"""

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from comun import Juego
import emu
import escenario as guion

LIMITE = emu.CICLOS_BYTE_UART


def main():
    j = Juego()
    j.vuelta_max = 0
    for paso in guion.escenario():
        if paso[0] == "boton":
            j.pulsar(paso[1])
        elif paso[0] == "tx":
            j.enviar_trama(paso[1], paso[2])
        j.drenar()
    margen = 100.0 * (LIMITE - j.vuelta_max) / LIMITE
    print("Vuelta mas larga del ciclo de servicio: %d ciclos" % j.vuelta_max)
    print("Un byte de UART a 115200 baudios:       %d ciclos" % LIMITE)
    print("Margen:                                 %.1f %%" % margen)
    print("Bytes recibidos perdidos:               %d" % j.sim.rx_perdidos)
    print("Escrituras a TX con la TX ocupada:      %d" % j.sim.tx_ignorados)
    ok = j.vuelta_max < LIMITE and j.sim.rx_perdidos == 0 and j.sim.tx_ignorados == 0
    print("RESULTADO: %s" % ("CUMPLE" if ok else "NO CUMPLE"))
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
