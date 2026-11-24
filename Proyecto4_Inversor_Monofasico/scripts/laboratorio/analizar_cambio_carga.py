"""Trama de cambio de carga: ubica el cambio por el salto de la amplitud de m (envolvente de un
ciclo), mide la caída y la recuperación de la corriente y el error antes y después.

Uso: python analizar_cambio_carga.py trama.csv [--evento-ms MS]
"""
import argparse
import csv
import math
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

W0 = 2 * math.pi * 50
parser = argparse.ArgumentParser(description="Analiza un cambio de carga con referencia constante.")
parser.add_argument("trama", type=Path)
parser.add_argument("--evento-ms", type=float, help="Instante del cambio respecto al inicio del registro")
args = parser.parse_args()
ruta = args.trama
lineas = ruta.read_text(encoding="utf-8").splitlines()
cab = lineas[0].lstrip("# ")
filas = list(csv.DictReader([l for l in lineas if not l.startswith("#")]))
t = np.array([float(f["t_s"]) for f in filas])
i = np.array([float(f["i_med_A"]) for f in filas])
ref = np.array([float(f["i_ref_A"]) for f in filas])
m = np.array([float(f["m"]) for f in filas])
n = int(round(0.02 / (t[1] - t[0])))


def envolvente(x):
    e = np.full(len(x), np.nan)
    for k in range(n // 2, len(x) - n // 2):
        s = slice(k - n // 2, k - n // 2 + n)
        a = np.column_stack([np.sin(W0 * t[s]), np.cos(W0 * t[s]), np.ones(n)])
        c = np.linalg.lstsq(a, x[s], rcond=None)[0]
        e[k] = math.hypot(c[0], c[1])
    return e


def fundamental(s):
    a = np.column_stack([np.sin(W0 * t[s]), np.cos(W0 * t[s]), np.ones(len(t[s]))])
    ci = np.linalg.lstsq(a, i[s], rcond=None)[0]
    cr = np.linalg.lstsq(a, ref[s], rcond=None)[0]
    return math.hypot(ci[0], ci[1]), math.hypot(cr[0], cr[1])


ei, em = envolvente(i), envolvente(m)
valido = ~np.isnan(em)
m_antes = np.nanmedian(em[: len(em) // 3])
m_despues = np.nanmedian(em[-len(em) // 4:])
if args.evento_ms is not None:
    k0 = int(np.searchsorted(t - t[0], args.evento_ms / 1000))
    origen = "marca indicada"
else:
    salto = m_despues - m_antes
    if not np.isfinite(salto) or abs(salto) < 0.03:
        parser.error("Sin cambio de modulación distinguible. Indique --evento-ms si el evento se registró por otro medio.")
    umbral = (m_antes + m_despues) / 2
    signo = np.sign(salto)
    cruces = np.flatnonzero(valido[:-1] & valido[1:]
                            & (signo * (em[:-1] - umbral) < 0)
                            & (signo * (em[1:] - umbral) >= 0)) + 1
    for cruce in cruces:
        siguientes = em[cruce:cruce + n]
        if len(siguientes) == n and np.all(signo * (siguientes - umbral) >= 0):
            k0 = int(cruce) - n // 2
            break
    else:
        parser.error("Sin cruce sostenido. Use --evento-ms si cuenta con una marca del ensayo.")
    origen = "estimación por modulación"
if not n <= k0 <= len(t) - 2 * n:
    parser.error("Se necesita al menos un ciclo antes y dos después del instante indicado.")
ia, ra = fundamental(slice(0, max(k0 - n // 2, n)))
idp, rd = fundamental(slice(min(k0 + 3 * n, len(t) - 2 * n), len(t)))
caida = np.nanmin(ei[k0:k0 + 3 * n])
final = np.nanmedian(ei[-len(ei) // 4:])
evaluados = np.flatnonzero((np.arange(len(t)) >= k0) & np.isfinite(ei))
fuera = evaluados[np.abs(ei[evaluados] - final) > 0.02 * final]
print(cab)
print(f"cambio de carga en t = {(t[k0] - t[0]) * 1e3:.0f} ms ({origen})")
print(f"amplitud de m en las ventanas extremas: {m_antes:.3f} a {m_despues:.3f}")
print(f"antes:   I1 = {ia:.3f} A, error {100 * (ia / ra - 1):+.2f} %")
print(f"despues: I1 = {idp:.3f} A, error {100 * (idp / rd - 1):+.2f} %")
print(f"minimo de la envolvente tras el cambio: {caida:.3f} A ({100 * (caida / ia - 1):+.1f} % respecto de antes)")
if fuera.size and fuera[-1] == evaluados[-1]:
    print("recuperación en +-2 % no observada dentro de la ventana evaluable")
else:
    t_rec = (fuera[-1] + 1 - k0) * (t[1] - t[0]) * 1e3 if fuera.size else 0.0
    print(f"envolvente dentro de +-2 % del valor final a los {t_rec:.0f} ms (ajuste centrado de un ciclo)")

tm = (t - t[0]) * 1e3
fig, ax = plt.subplots(3, 1, figsize=(7.5, 6.5), sharex=True, gridspec_kw={"height_ratios": [2, 1.3, 1.3]})
ax[0].plot(tm, ref, color="#eb6834", ls="--", lw=1.0, label="Referencia")
ax[0].plot(tm, i, color="#2a78d6", lw=1.0, label="Corriente medida")
ax[0].set_ylabel("Corriente (A)")
ax[0].legend(fontsize=7, frameon=False, ncol=2, loc="upper left")
ax[0].set_title(cab, fontsize=7, loc="left")
ax[1].plot(tm, ei, color="#2a78d6", lw=1.6, label="Amplitud por ciclo")
ax[1].axhline(0.5, color="#eb6834", ls="--", lw=0.8)
ax[1].set_ylim(0.40, 0.52)
ax[1].set_ylabel("Amplitud (A)")
ax[1].legend(fontsize=7, frameon=False, loc="lower left")
ax[2].plot(tm, m, color="#30302e", lw=0.6, alpha=0.5)
ax[2].plot(tm, em, color="#30302e", lw=1.6, label="Amplitud de m")
for y in (0.85, -0.85):
    ax[2].axhline(y, color="#8a8984", ls=":", lw=0.8)
ax[2].set_ylabel("m")
ax[2].set_xlabel("Tiempo (ms)")
ax[2].legend(fontsize=7, frameon=False, loc="lower left")
for a in ax:
    a.axvline(tm[k0], color="#8a8984", lw=0.9, ls="--")
    a.grid(True, color="#e4e3df", lw=0.5)
fig.tight_layout()
salida = ruta.with_name(ruta.stem + "_cambio_carga.png")
fig.savefig(salida, dpi=150)
print("grafica:", salida)
