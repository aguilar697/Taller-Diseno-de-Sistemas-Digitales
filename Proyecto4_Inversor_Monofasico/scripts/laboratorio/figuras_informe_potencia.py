"""Figuras del informe de Potencia e identificación de la carga a 50 Hz.

Uso: python figuras_informe_potencia.py [carpeta de tramas] [carpeta de figuras]
Por omisión lee laboratorio/2026-11-21 y escribe en docs/informe/potencia/figuras.
La impedancia se obtiene de la fundamental de m*Vdc menos la caída por tiempo
muerto, 4/pi*2*td*fsw*Vdc en fase con la corriente.
"""

import cmath
import csv
import math
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

PROYECTO = Path(__file__).resolve().parents[2]
TRAMAS = PROYECTO / "docs/informe/resultados/potencia/laboratorio/2026-11-21"
FIGURAS = PROYECTO / "docs/informe/potencia/figuras"
W0 = 2 * math.pi * 50.0
TD, FSW, TS = 1e-6, 10e3, 100e-6
AZUL, NARANJA, TINTA, GRIS = "#2a78d6", "#eb6834", "#30302e", "#8a8984"
ENSAYOS = {"03_pr_12v_0a2": 12.0, "04_pr_24v_0a2": 24.0, "09_variante_b_24v_0a5": 24.0}


def leer(ruta):
    filas = [l for l in ruta.read_text(encoding="utf-8").splitlines() if not l.startswith("#")]
    datos = list(csv.DictReader(filas))
    return {k: np.array([float(f[k]) for f in datos]) for k in ("t_s", "i_med_A", "i_ref_A", "m")}


def fasor(t, x):
    a = np.column_stack([np.sin(W0 * t), np.cos(W0 * t), np.ones_like(t)])
    s, c, _ = np.linalg.lstsq(a, x, rcond=None)[0]
    return complex(s, c)


def identificar(d, vdc, n=500):
    t = d["t_s"][-n:]
    i = fasor(t, d["i_med_A"][-n:])
    ref = fasor(t, d["i_ref_A"][-n:])
    m = fasor(t, d["m"][-n:]) * cmath.exp(-1j * W0 * TS)
    v = m * vdc - 4 / math.pi * 2 * TD * FSW * vdc * i / abs(i)
    z = v / i
    return {"I1": abs(i), "error": 100 * (abs(i) / abs(ref) - 1),
            "fase": math.degrees(cmath.phase(i / ref)), "M1": abs(m),
            "R": z.real, "L": z.imag / W0, "Z": abs(z)}


def estilo(ax):
    ax.grid(True, color="#e4e3df", linewidth=0.5)
    ax.set_axisbelow(True)
    for lado in ("top", "right"):
        ax.spines[lado].set_visible(False)
    for lado in ("left", "bottom"):
        ax.spines[lado].set_color(GRIS)
    ax.tick_params(colors=TINTA, labelsize=7, width=0.5)


def ventana(d, ciclos=3):
    n = int(round(ciclos / 50.0 / (d["t_s"][1] - d["t_s"][0])))
    t = d["t_s"][-n:]
    return slice(len(d["t_s"]) - n, None), (t - t[0]) * 1e3


def corrientes(ax, d, titulo):
    s, t = ventana(d)
    ax.plot(t, d["i_ref_A"][s], color=NARANJA, lw=1.2, ls="--", label="Referencia")
    ax.plot(t, d["i_med_A"][s], color=AZUL, lw=1.2, label="Medida (XADC)")
    ax.set_title(titulo, fontsize=8, color=TINTA, loc="left")
    ax.set_ylabel("Corriente (A)", fontsize=7, color=TINTA)
    estilo(ax)


def modulacion(ax, d, limite=False):
    s, t = ventana(d)
    ax.plot(t, d["m"][s], color=TINTA, lw=1.0)
    if limite:
        for y in (0.85, -0.85):
            ax.axhline(y, color=GRIS, lw=0.8, ls=":")
        ax.text(t[-1], 0.85, "límite ±0,85", fontsize=6, color=GRIS, ha="right", va="bottom")
    ax.set_ylabel("m", fontsize=7, color=TINTA)
    ax.set_xlabel("Tiempo (ms)", fontsize=7, color=TINTA)
    estilo(ax)


def main():
    tramas = Path(sys.argv[1]) if len(sys.argv) > 1 else TRAMAS
    figuras = Path(sys.argv[2]) if len(sys.argv) > 2 else FIGURAS
    figuras.mkdir(parents=True, exist_ok=True)
    datos = {k: leer(tramas / f"{k}.csv") for k in ENSAYOS}
    print("Ensayo, I1 (A), error (%), fase (grados), M1, R (ohm), L (mH), |Z| (ohm)")
    for k, vdc in ENSAYOS.items():
        r = identificar(datos[k], vdc)
        print(f"{k}, {r['I1']:.4f}, {r['error']:+.2f}, {r['fase']:+.2f}, {r['M1']:.4f}, "
              f"{r['R']:.2f}, {r['L'] * 1e3:.1f}, {r['Z']:.2f}")

    fig, ejes = plt.subplots(2, 2, figsize=(7.0, 3.6), sharex=True, gridspec_kw={"height_ratios": [2, 1]})
    corrientes(ejes[0, 0], datos["03_pr_12v_0a2"], "(a) Bus de 12 V, 0,2 A pico")
    corrientes(ejes[0, 1], datos["04_pr_24v_0a2"], "(b) Bus de 24 V, 0,2 A pico")
    modulacion(ejes[1, 0], datos["03_pr_12v_0a2"])
    modulacion(ejes[1, 1], datos["04_pr_24v_0a2"])
    ejes[0, 1].set_ylabel("")
    ejes[1, 1].set_ylabel("")
    for ax in ejes[0]:
        ax.set_ylim(-0.3, 0.3)
    for ax in ejes[1]:
        ax.set_ylim(-0.5, 0.5)
    ejes[0, 0].legend(fontsize=6.5, frameon=False, loc="upper right", ncol=2)
    fig.tight_layout(pad=0.4)
    fig.savefig(figuras / "seguimiento_0a2.pdf")
    plt.close(fig)

    fig, ejes = plt.subplots(2, 1, figsize=(3.5, 3.2), sharex=True, gridspec_kw={"height_ratios": [2, 1]})
    corrientes(ejes[0], datos["09_variante_b_24v_0a5"], "Bus de 24 V, 0,5 A pico, trama 09")
    ejes[0].set_ylim(-0.6, 0.9)
    ejes[0].legend(fontsize=6.5, frameon=False, loc="upper left", ncol=2)
    modulacion(ejes[1], datos["09_variante_b_24v_0a5"], limite=True)
    ejes[1].set_ylim(-1.0, 1.0)
    fig.tight_layout(pad=0.4)
    fig.savefig(figuras / "intento_0a5.pdf")
    plt.close(fig)
    print("Figuras en", figuras)


if __name__ == "__main__":
    main()
