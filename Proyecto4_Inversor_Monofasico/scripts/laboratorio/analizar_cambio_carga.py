"""Trama de cambio de carga: ubica el cambio por el salto de la amplitud de m (envolvente de un
ciclo), mide la caída y la recuperación de la corriente y el error antes y después.

Uso: python analizar_cambio_carga.py trama.csv
"""
import csv
import math
import sys
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

W0 = 2 * math.pi * 50
ruta = Path(sys.argv[1])
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
umbral = (m_antes + m_despues) / 2
cruce = [k for k in range(1, len(em)) if valido[k] and valido[k - 1] and (em[k - 1] - umbral) * (em[k] - umbral) <= 0]
k0 = cruce[0] - n // 2 if cruce else len(t) // 2
k0 = max(k0, 0)
ia, ra = fundamental(slice(0, max(k0 - n // 2, n)))
idp, rd = fundamental(slice(min(k0 + 3 * n, len(t) - 2 * n), len(t)))
caida = np.nanmin(ei[k0:k0 + 3 * n])
final = np.nanmedian(ei[-len(ei) // 4:])
dentro = [k for k in range(k0, len(t)) if not np.isnan(ei[k]) and abs(ei[k] - final) > 0.02 * final]
t_rec = (dentro[-1] - k0) * (t[1] - t[0]) * 1e3 if dentro else 0.0
print(cab)
print(f"cambio de carga en t = {t[k0] * 1e3:.0f} ms (salto de la amplitud de m de {m_antes:.3f} a {m_despues:.3f})")
print(f"antes:   I1 = {ia:.3f} A, error {100 * (ia / ra - 1):+.2f} %")
print(f"despues: I1 = {idp:.3f} A, error {100 * (idp / rd - 1):+.2f} %")
print(f"minimo de la envolvente tras el cambio: {caida:.3f} A ({100 * (caida / ia - 1):+.1f} % respecto de antes)")
print(f"envolvente dentro de +-2 % del valor final a los {t_rec:.0f} ms (ventana de un ciclo)")

tm = t * 1e3
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
    a.axvline(t[k0] * 1e3, color="#8a8984", lw=0.9, ls="--")
    a.grid(True, color="#e4e3df", lw=0.5)
fig.tight_layout()
salida = ruta.with_name(ruta.stem + "_cambio_carga.png")
fig.savefig(salida, dpi=150)
print("grafica:", salida)
