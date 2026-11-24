"""Gráfica de cada trama exportada (.bin del receptor): corriente medida, referencia y modulación.

Usa el decodificador y el análisis de software/pc/receptor.py.
Uso: python scripts/laboratorio/graficar_ensayos.py CARPETA_CON_BIN
Escribe CARPETA/<ensayo>.png junto a cada .bin.
"""
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "software" / "pc"))
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
import matplotlib  # noqa: E402
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import receptor  # noqa: E402


def graficar(archivo):
    trama = receptor.decodificar(archivo.read_bytes())
    estado = receptor.ESTADOS.get(trama["estado"], "?")
    t_reg = trama["k_reg"] * trama["ts_ns"] * 1e-9
    t = [k * t_reg * 1000 for k in range(trama["n"])]
    try:
        r = receptor.analizar(trama, max(1, round(trama["f_sw"] / 10000)))
        resumen = (f"fundamental {r['amp_med']:.4f} A / ref {r['amp_ref']:.4f} A · "
                   f"error {100 * r['error']:+.2f} % · desfase {r['desfase']:+.2f}°")
    except receptor.TramaInvalida:
        resumen = f"sin análisis · causa de falla: {receptor.describir_causa(trama['causa'])}"
    fig, (a1, a2) = plt.subplots(2, 1, figsize=(10, 6.5), sharex=True,
                                 gridspec_kw={"height_ratios": [3, 1.3]})
    a1.plot(t, trama["i_ref"], label="i_ref", linewidth=1.4)
    a1.plot(t, trama["i_med"], label="i_med", linewidth=1.0)
    a1.set_ylabel("corriente (A)")
    a1.grid(True)
    a1.legend(loc="upper right")
    a1.set_title(f"{archivo.stem} · {estado} · {trama['f_sw'] / 1000:g} kHz · "
                 f"amplitud {trama['amplitud_ma']} mA\n{resumen}", fontsize=10)
    a2.plot(t, trama["m"], color="tab:green", linewidth=1.0)
    for limite in (0.85, -0.85):
        a2.axhline(limite, color="tab:red", linestyle="--", linewidth=0.8)
    a2.set_ylabel("m")
    a2.set_xlabel("t (ms)")
    a2.grid(True)
    fig.tight_layout()
    fig.savefig(archivo.with_suffix(".png"), dpi=130)
    plt.close(fig)
    return f"{archivo.stem}: {estado}, {resumen}"


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    for archivo in sorted(Path(sys.argv[1]).glob("*.bin")):
        print(graficar(archivo))


if __name__ == "__main__":
    main()
