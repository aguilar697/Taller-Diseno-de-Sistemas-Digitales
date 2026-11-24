"""Amplitud de 50 Hz de la caída en una resistencia, desde los CSV de la resta CH1-CH2.

Cuando los extremos de la resistencia están en +Vbus, los dos canales saturan en el mismo
valor y la resta exporta 0 exacto; esas muestras se descartan y el ajuste seno/coseno se
hace con las demás. Uso: python analizar_osciloscopio.py CARPETA [R_ohm]
"""
import math
import sys
from pathlib import Path

import numpy as np

W0 = 2 * math.pi * 50.0


def leer(ruta):
    filas = ruta.read_text(encoding="utf-8", errors="replace").splitlines()[2:]
    d = np.array([[float(x) for x in f.split(",")[:2]] for f in filas if f.strip()])
    return d[:, 0], d[:, 1]


def amplitud(t, v, cero=2e-3):
    ok = np.abs(v) > cero
    a = np.column_stack([np.sin(W0 * t[ok]), np.cos(W0 * t[ok]), np.ones(ok.sum())])
    c = np.linalg.lstsq(a, v[ok], rcond=None)[0]
    return math.hypot(c[0], c[1]), ok.mean()


def main():
    carpeta = Path(sys.argv[1])
    r = float(sys.argv[2]) if len(sys.argv) > 2 else 3.3
    print(f"Captura, muestras válidas, V1 pico (V), I1 = V1/{r} (A)")
    for ruta in sorted(carpeta.rglob("*.csv")):
        t, v = leer(ruta)
        v1, validas = amplitud(t, v)
        print(f"{ruta.relative_to(carpeta)}, {100 * validas:.0f} %, {v1:.3f}, {v1 / r:.3f}")


if __name__ == "__main__":
    main()
