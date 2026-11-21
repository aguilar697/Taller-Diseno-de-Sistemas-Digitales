"""Tabla de resultados de todas las tramas exportadas, con la predicción del PR discreto en PLECS.

Usa el decodificador y el análisis de software/pc/receptor.py.
Uso: python scripts/laboratorio/resumen_ensayos.py CARPETA_CON_BIN
Escribe CARPETA/resultados.md.
"""
import sys
from pathlib import Path

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "software" / "pc"))
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
import receptor  # noqa: E402

# Potencia/02_simulacion_y_resultados.md: PR discreto, 7,2 ohm y 10 mH
PLECS = {12: {0.2: (0.193541, -0.899), 0.5: (0.483850, -0.899), 1.0: (0.967687, -0.899)},
         24: {0.2: (0.196722, -0.452), 0.5: (0.491804, -0.452), 1.0: (0.983605, -0.452)}}


def plecs(bus, amplitud):
    p = PLECS[bus].get(round(amplitud, 1))
    return f"{p[0]:.4f} A / {p[1]:+.2f}°" if p else "—"


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    carpeta = Path(sys.argv[1])
    filas = ["| Ensayo | Estado | Causa | Ref. pico | Fundamental | Error | ≤10 % | Desfase | "
             "PLECS 12 V | PLECS 24 V | ISR máx. | Conv. perdidas |",
             "|---|---|---|---:|---:|---:|---|---:|---|---|---:|---:|"]
    for archivo in sorted(carpeta.glob("*.bin")):
        t = receptor.decodificar(archivo.read_bytes())
        base = (f"| {archivo.stem} | {receptor.ESTADOS.get(t['estado'], '?')} | "
                f"{receptor.describir_causa(t['causa'])} |")
        isr = f"{t['t_isr_max'] / 100:.2f} µs | {t['perdidas']} |"
        try:
            r = receptor.analizar(t, max(1, round(t["f_sw"] / 10000)))
        except receptor.TramaInvalida:
            filas.append(f"{base} {t['amplitud_ma'] / 1000:.1f} A | — | — | — | — | — | — | {isr}")
            continue
        filas.append(f"{base} {r['amp_ref']:.3f} A | {r['amp_med']:.4f} A | {100 * r['error']:+.2f} % | "
                     f"{'sí' if r['cumple'] else 'no'} | {r['desfase']:+.2f}° | "
                     f"{plecs(12, r['amp_ref'])} | {plecs(24, r['amp_ref'])} | {isr}")
    texto = "\n".join(filas) + "\n"
    (carpeta / "resultados.md").write_text(texto, encoding="utf-8")
    print(texto)


if __name__ == "__main__":
    main()
