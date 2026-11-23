"""Trama del 12_ (registro de falla): decodifica el ADC en bruto y muestra lo previo al corte.

Uso: python analizar_falla.py trama.csv
"""
import csv
import sys
from pathlib import Path

import numpy as np

OFFSET, GANANCIA, I_MAX, COD_MIN, COD_MAX = 1776.0, 0.0076383, 1.5, 16, 4079

ruta = Path(sys.argv[1])
lineas = ruta.read_text(encoding="utf-8").splitlines()
print(lineas[0])
filas = list(csv.DictReader([l for l in lineas if not l.startswith("#")]))
t = np.array([float(f["t_s"]) for f in filas])
i_pr = np.array([float(f["i_med_A"]) for f in filas])
raw = np.array([int(round(float(f["i_ref_A"]) * 1000)) for f in filas])
m = np.array([float(f["m"]) for f in filas])
n = np.array([int(f["n"]) for f in filas])
valido = raw >= 0
raw = np.abs(raw)
codigo, errores = raw & 0x0FFF, raw >> 12
i_bruta = (codigo - OFFSET) * GANANCIA

malas = [k for k in range(len(t)) if not COD_MIN <= codigo[k] <= COD_MAX or abs(i_bruta[k]) > I_MAX
         or errores[k] or not valido[k]]
k0 = malas[0] if malas else len(t) - 21
print(f"primera muestra anormal: indice {k0}, t = {t[k0]*1e3:.1f} ms" if malas else "sin muestras anormales")
print(" idx      n  codigo  i_bruta(A)  i_PR(A)       m  err  valida")
for k in range(max(0, k0 - 30), min(len(t), k0 + 22)):
    marca = "  <--" if k in malas else ""
    print(f"{k:4d} {n[k]:6d} {codigo[k]:7d} {i_bruta[k]:+10.3f} {i_pr[k]:+8.3f} {m[k]:+7.3f} {errores[k]:4d} {int(valido[k]):6d}{marca}")

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
fig, ax = plt.subplots(2, 1, figsize=(7, 4.5), sharex=True)
ax[0].plot(t * 1e3, i_bruta, color="#2a78d6", lw=1, label="ADC en bruto")
ax[0].plot(t * 1e3, i_pr, color="#eb6834", lw=1, ls="--", label="Entrada del PR")
ax[0].axhline(I_MAX, color="#8a8984", ls=":"); ax[0].axhline(-I_MAX, color="#8a8984", ls=":")
ax[0].set_ylabel("Corriente (A)"); ax[0].legend(fontsize=7, frameon=False)
ax[1].plot(t * 1e3, m, color="#30302e", lw=1); ax[1].set_ylabel("m"); ax[1].set_xlabel("Tiempo (ms)")
for a in ax:
    a.axvline(t[k0] * 1e3, color="#8a8984", lw=0.8, ls=":")
    a.grid(True, color="#e4e3df", lw=0.5)
fig.tight_layout()
salida = ruta.with_name(ruta.stem + "_falla.png")
fig.savefig(salida, dpi=150)
print("grafica:", salida)
