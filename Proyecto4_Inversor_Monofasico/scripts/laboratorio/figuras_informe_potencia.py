"""Figuras del informe de Potencia e identificación de la carga a 50 Hz.

Uso: python figuras_informe_potencia.py [carpeta de tramas] [carpeta de figuras]
Por omisión lee laboratorio/2026-11-23 y escribe en docs/informe/potencia/figuras.
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
TRAMAS = PROYECTO / "docs/informe/resultados/potencia/laboratorio/2026-11-23"
FIGURAS = PROYECTO / "docs/informe/potencia/figuras"
W0 = 2 * math.pi * 50.0
TD, FSW, TS = 1e-6, 10e3, 100e-6
AZUL, NARANJA, TINTA, GRIS = "#2a78d6", "#eb6834", "#30302e", "#8a8984"
ENSAYOS = {"03_pr_12v_0a2": 12.0, "04_pr_24v_0a2": 24.0, "06_pr_24v_0a5": 24.0,
           "08_pr_24v_1a": 24.0, "15_pr_24v_0a5_9v9": 24.0}


def leer(ruta):
    filas = [l for l in ruta.read_text(encoding="utf-8").splitlines() if not l.startswith("#")]
    datos = list(csv.DictReader(filas))
    return {k: np.array([float(f[k]) for f in datos]) for k in ("t_s", "i_med_A", "i_ref_A", "m")}


def fasor(t, x):
    a = np.column_stack([np.sin(W0 * t), np.cos(W0 * t), np.ones_like(t)])
    s, c, _ = np.linalg.lstsq(a, x, rcond=None)[0]
    return complex(s, c)


def identificar(d, vdc):
    tr = d["t_s"][1] - d["t_s"][0]
    n = int(round(5 / 50.0 / tr))
    t = d["t_s"][-n:]
    i = fasor(t, d["i_med_A"][-n:])
    ref = fasor(t, d["i_ref_A"][-n:])
    m = fasor(t, d["m"][-n:]) * cmath.exp(-1j * W0 * TS)
    v = m * vdc - 4 / math.pi * 2 * TD * FSW * vdc * i / abs(i)
    z = v / i
    return {"I1": abs(i), "error": 100 * (abs(i) / abs(ref) - 1),
            "fase": math.degrees(cmath.phase(i / ref)), "M1": abs(m),
            "R": z.real, "L": z.imag / W0, "Z": abs(z)}


def envolvente(t, x):
    n = int(round(0.02 / (t[1] - t[0])))
    e = np.full(len(x), np.nan)
    for k in range(n // 2, len(x) - n // 2):
        s = slice(k - n // 2, k - n // 2 + n)
        a = np.column_stack([np.sin(W0 * t[s]), np.cos(W0 * t[s]), np.ones(n)])
        c = np.linalg.lstsq(a, x[s], rcond=None)[0]
        e[k] = math.hypot(c[0], c[1])
    return e


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


def corrientes(ax, d, titulo, s=None, t=None):
    if s is None:
        s, t = ventana(d)
    ax.plot(t, d["i_ref_A"][s], color=NARANJA, lw=1.1, ls="--", label="Referencia")
    ax.plot(t, d["i_med_A"][s], color=AZUL, lw=1.1, label="Medida (XADC)")
    ax.set_title(titulo, fontsize=8, color=TINTA, loc="left")
    ax.set_ylabel("Corriente (A)", fontsize=7, color=TINTA)
    estilo(ax)


def modulacion(ax, d, s=None, t=None):
    if s is None:
        s, t = ventana(d)
    ax.plot(t, d["m"][s], color=TINTA, lw=0.9)
    for y in (0.85, -0.85):
        ax.axhline(y, color=GRIS, lw=0.8, ls=":")
    ax.set_ylim(-1.0, 1.0)
    ax.set_ylabel("m", fontsize=7, color=TINTA)
    ax.set_xlabel("Tiempo (ms)", fontsize=7, color=TINTA)
    estilo(ax)


def main():
    tramas = Path(sys.argv[1]) if len(sys.argv) > 1 else TRAMAS
    figuras = Path(sys.argv[2]) if len(sys.argv) > 2 else FIGURAS
    figuras.mkdir(parents=True, exist_ok=True)
    print("Ensayo, I1 (A), error (%), fase (grados), M1, R (ohm), L (mH), |Z| (ohm)")
    for k, vdc in ENSAYOS.items():
        r = identificar(leer(tramas / f"{k}.csv"), vdc)
        print(f"{k}, {r['I1']:.4f}, {r['error']:+.2f}, {r['fase']:+.2f}, {r['M1']:.4f}, "
              f"{r['R']:.2f}, {r['L'] * 1e3:.1f}, {r['Z']:.2f}")

    casos = (
        ("04_pr_24v_0a2", "seguimiento_0a2.pdf", "24 V, 0,2 A pico", (-0.3, 0.3)),
        ("21_pr_24v_0a5_rep2", "seguimiento_0a5.pdf", "24 V, 0,5 A pico", (-0.8, 0.8)),
    )
    for nombre, salida, titulo, limites in casos:
        d = leer(tramas / f"{nombre}.csv")
        fig, ejes = plt.subplots(2, 1, figsize=(3.5, 2.8), sharex=True,
                                 gridspec_kw={"height_ratios": [2, 1]})
        corrientes(ejes[0], d, titulo)
        ejes[0].set_ylim(*limites)
        ejes[0].legend(fontsize=6.5, frameon=False, loc="upper right", ncol=2)
        modulacion(ejes[1], d)
        fig.tight_layout(pad=0.4)
        fig.savefig(figuras / salida)
        plt.close(fig)

    c = leer(tramas / "08_pr_24v_1a.csv")
    fig, ejes = plt.subplots(2, 1, figsize=(3.5, 3.2), sharex=True, gridspec_kw={"height_ratios": [2, 1]})
    corrientes(ejes[0], c, "24 V, 1 A pico")
    ejes[0].set_ylim(-1.3, 1.6)
    ejes[0].legend(fontsize=6.5, frameon=False, loc="upper left", ncol=2)
    modulacion(ejes[1], c)
    fig.tight_layout(pad=0.4)
    fig.savefig(figuras / "limite_1a.pdf")
    plt.close(fig)

    e = leer(tramas / "24_escalon_0a2_0a5_c102.csv")
    fig, ejes = plt.subplots(2, 1, figsize=(3.5, 2.8), sharex=True,
                             gridspec_kw={"height_ratios": [2, 1]})
    te = (e["t_s"] - e["t_s"][0]) * 1e3
    todo = slice(None)
    corrientes(ejes[0], e, "Escalón 0,2 a 0,5 A, 24 V", todo, te)
    modulacion(ejes[1], e, todo, te)
    ejes[0].set_ylim(-0.8, 0.8)
    ejes[0].legend(fontsize=6.5, frameon=False, loc="upper left", ncol=2)
    for ax in ejes:
        ax.axvline(51.0, color=GRIS, lw=0.8, ls="--")
    fig.tight_layout(pad=0.4)
    fig.savefig(figuras / "escalon_referencia.pdf")
    plt.close(fig)

    g = leer(tramas / "37_cambio_carga_6v6_9v9_c410.csv")
    fig, ejes = plt.subplots(2, 1, figsize=(3.5, 2.8), sharex=True,
                             gridspec_kw={"height_ratios": [2, 1]})
    tg = (g["t_s"] - g["t_s"][0]) * 1e3
    ei, em = envolvente(g["t_s"], g["i_med_A"]), envolvente(g["t_s"], g["m"])
    ejes[0].plot(tg, ei, color=AZUL, lw=1.3, label="Amplitud de la corriente")
    ejes[0].axhline(0.5, color=NARANJA, ls="--", lw=1.0, label="Referencia")
    ejes[0].set_ylim(0.40, 0.52)
    ejes[0].set_title("Cambio de carga 6,6 a 9,9 Ω, 0,5 A, 24 V", fontsize=8, color=TINTA, loc="left")
    ejes[0].set_ylabel("Amplitud (A)", fontsize=7, color=TINTA)
    ejes[0].legend(fontsize=6.5, frameon=False, loc="lower left")
    estilo(ejes[0])
    ejes[1].plot(tg, em, color=TINTA, lw=1.3)
    ejes[1].set_ylim(0.6, 0.8)
    ejes[1].set_ylabel("Amplitud de m", fontsize=7, color=TINTA)
    ejes[1].set_xlabel("Tiempo (ms)", fontsize=7, color=TINTA)
    estilo(ejes[1])
    for ax in ejes:
        ax.axvline(297.0, color=GRIS, lw=0.8, ls="--")
    fig.tight_layout(pad=0.4)
    fig.savefig(figuras / "cambio_carga.pdf")
    plt.close(fig)
    print("Figuras en", figuras)


if __name__ == "__main__":
    main()
