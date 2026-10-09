"""Ejecuta todas las pruebas autoverificables y resume el resultado.

Uso:  python tests/run_tests.py
Devuelve codigo de salida 0 si todo pasa, 1 si algo falla.
"""

import importlib
import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)

MODULOS = [
    ("Herramientas (ensamblador y emulador)", "test_herramientas"),
    ("Bloque 1: control de estado", "test_control_estado"),
    ("Bloque 2: colocacion de barcos", "test_colocacion"),
    ("Bloque 3: turnos y disparos", "test_turnos"),
    ("Bloque 4: hundido y victoria", "test_victoria"),
    ("Bloque 5: comunicacion UART", "test_uart"),
    ("Bloque 6: perifericos de salida", "test_salidas"),
    ("Integracion: partidas completas", "test_integracion"),
]


def main():
    fallidos = []
    for titulo, nombre in MODULOS:
        modulo = importlib.import_module(nombre)
        if modulo.main() != 0:
            fallidos.append(titulo)

    print()
    print("#" * 66)
    if fallidos:
        print("# RESULTADO GLOBAL: FALLARON %d BLOQUES" % len(fallidos))
        for f in fallidos:
            print("#   - %s" % f)
        print("#" * 66)
        return 1
    print("# RESULTADO GLOBAL: TODOS LOS BLOQUES PASARON")
    print("#" * 66)
    return 0


if __name__ == "__main__":
    sys.exit(main())
