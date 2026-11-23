"""Trama de transitorio (variante de captura): envolvente de 50 Hz con ventana de un ciclo,
instante del evento, pico posterior y tiempo hasta quedar dentro de +-10 % de la referencia.

Uso: python analizar_transitorio.py trama.csv [--sin-grafica]
El evento es el cambio de amplitud de la referencia; si no lo hay (BTNL), el centro de la trama.
"""
import csv
import math
import sys
from pathlib import Path

import numpy as np

W0 = 2 * math.pi * 50.0


def leer(ruta):
    lineas = Path(ruta).read_text(encoding="utf-8").splitlines()
    cab = [l for l in lineas if l.startswith("#")]
    filas = list(csv.DictReader([l for l in lineas if not l.startswith("#")]))
    datos = {k: np.array([float(f[k]) for f in filas]) for k in ("t_s", "i_med_A", "i_ref_A", "m")}
    return datos, (cab[0][1:].strip() if cab else "")


def envolvente(t, x, n):
    e = np.full(len(x), np.nan)
    for k in range(n // 2, len(x) - n // 2):
        s = slice(k - n // 2, k - n // 2 + n)
        a = np.column_stack([np.sin(W0 * t[s]), np.cos(W0 * t[s]), np.ones(n)])
        c = np.linalg.lstsq(a, x[s], rcond=None)[0]
        e[k] = math.hypot(c[0], c[1])
    return e


def main():
    ruta = sys.argv[1]
    d, cab = leer(ruta)
    t, i, ref, m = d["t_s"], d["i_med_A"], d["i_ref_A"], d["m"]
    tr = t[1] - t[0]
    n = int(round(1 / 50.0 / tr))
    e_i, e_r = envolvente(t, i, n), envolvente(t, ref, n)
    cruces = np.nonzero(np.sign(ref[1:]) != np.sign(ref[:-1]))[0] + 1
    semiciclos = list(zip(cruces[:-1], cruces[1:]))
    picos = [np.max(np.abs(ref[a:b])) for a, b in semiciclos]
    k0 = None
    for (a, _), p in zip(semiciclos, picos):
        if abs(p - picos[0]) > 0.05 * max(p, picos[0]):
            k0 = int(a)
            break
    escalon = k0 is not None
    if not escalon:
        k0 = len(t) // 2
    final = picos[-1] if escalon else np.nanmax(e_r)
    fuera = [k for k in range(k0, len(t) - n // 2) if abs(e_i[k] - final) > 0.10 * final]
    t_est = (fuera[-1] + 1 - k0) * tr * 1e3 if fuera else 0.0
    pico = np.max(np.abs(i[k0:]))
    print(cab)
    print(f"evento en t = {t[k0]*1e3:.1f} ms ({'cambio de referencia' if escalon else 'centro de la trama'})")
    print(f"amplitud antes: {np.nanmean(e_i[n//2:max(k0-n//2, n//2+1)]):.3f} A; referencia final {final:.3f} A")
    print(f"pico de |i| despues del evento: {pico:.3f} A ({100*(pico/final-1):+.1f} % sobre la referencia)")
    print(f"envolvente dentro de +-10 % a los {t_est:.1f} ms (incluye ~10 ms de retardo de la ventana de un ciclo)")
    print(f"|m| maximo despues del evento: {np.max(np.abs(m[k0:])):.3f}")
    if "--sin-grafica" in sys.argv:
        return
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(2, 1, figsize=(7, 4.5), sharex=True, gridspec_kw={"height_ratios": [2, 1]})
    tm = t * 1e3
    ax[0].plot(tm, ref, color="#eb6834", ls="--", lw=1.1, label="Referencia")
    ax[0].plot(tm, i, color="#2a78d6", lw=1.1, label="Medida")
    ax[0].plot(tm, e_i, color="#2a78d6", lw=0.8, alpha=0.6, label="Envolvente (1 ciclo)")
    ax[0].plot(tm, -e_i, color="#2a78d6", lw=0.8, alpha=0.6)
    ax[0].axvline(t[k0] * 1e3, color="#8a8984", lw=0.8, ls=":")
    ax[0].set_ylabel("Corriente (A)")
    ax[0].legend(fontsize=7, frameon=False, ncol=3, loc="upper left")
    ax[0].set_title(cab, fontsize=7, loc="left")
    ax[1].plot(tm, m, color="#30302e", lw=1.0)
    for y in (0.85, -0.85):
        ax[1].axhline(y, color="#8a8984", lw=0.8, ls=":")
    ax[1].set_ylabel("m")
    ax[1].set_xlabel("Tiempo (ms)")
    for a in ax:
        a.grid(True, color="#e4e3df", lw=0.5)
    fig.tight_layout()
    salida = Path(ruta).with_name(Path(ruta).stem + "_transitorio.png")
    fig.savefig(salida, dpi=150)
    print("grafica:", salida)


if __name__ == "__main__":
    main()
