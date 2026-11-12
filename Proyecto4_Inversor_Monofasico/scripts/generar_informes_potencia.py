"""Genera los borradores de Potencia en PDF mediante LaTeX."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil
import subprocess


PROYECTO = Path(__file__).resolve().parents[1]
FUENTES = PROYECTO / "docs/informe/potencia"
BUILD = PROYECTO / "build/informes_potencia"
RESULTADOS = PROYECTO / "docs/informe/resultados/potencia/lazo_funcional.json"


def numero(valor: float, decimales: int = 3) -> str:
    return f"{valor:.{decimales}f}".replace(".", "{,}")


def tablas(datos: dict) -> str:
    lineas = [
        r"\par",
        r"\begin{table}[ht]",
        r"\caption{Seguimiento simulado de la copia funcional}",
        r"\label{tab:nominal}\centering\small",
        r"\begin{tabular}{@{}ccccc@{}}\toprule",
        r"$V_{dc}$ & $I_{\mathrm{ref},pk}$ & $I_{1,pk}$ & $|E_A|$ & $\phi$\\",
        r"(V) & (A) & (A) & (\%) & ($^\circ$)\\\midrule",
    ]
    nominales = [
        c for c in datos["casos"]
        if c["modelo"] == "proyecto4_funcional"
        and c["ensayo"].startswith("nominal_")
    ]
    if len(nominales) != 6:
        raise ValueError("Se esperaban seis ensayos nominales funcionales.")
    for caso in nominales:
        v = caso["variables"]
        valores = [
            str(v["Vbus"]),
            numero(v["Iref"], 1),
            numero(caso["fundamental_a_pico"], 4),
            numero(abs(caso["error_amplitud_porcentaje"]), 2),
            numero(caso["fase_grados"], 2),
        ]
        lineas.append(" & ".join(valores) + r"\\")
    lineas += [
        r"\bottomrule\end{tabular}\end{table}\par",
        r"\begin{table}[ht]",
        r"\caption{Simulación de transitorios a 12 V}",
        r"\label{tab:transitorios}\centering\small",
        r"\begin{tabular}{@{}lccc@{}}\toprule",
        r"Ensayo & $I_{1,pk}$ final & $|E_A|$ final & $\max |m|$\\",
        r" & (A) & (\%) & \\\midrule",
    ]
    nombres = {
        "referencia_02_05": r"$0{,}2\to0{,}5$ A",
        "referencia_05_10": r"$0{,}5\to1{,}0$ A",
        "carga_66_99": r"$6{,}6\to9{,}9\ \Omega$",
    }
    for caso in datos["casos"]:
        if caso["modelo"] != "proyecto4_funcional":
            continue
        if caso["ensayo"] not in nombres:
            continue
        valores = [
            nombres[caso["ensayo"]],
            numero(caso["fundamental_a_pico"], 4),
            numero(abs(caso["error_amplitud_porcentaje"]), 2),
            numero(caso["modulacion_max_abs"], 3),
        ]
        lineas.append(" & ".join(valores) + r"\\")
    lineas += [
        r"\bottomrule\end{tabular}\end{table}\par",
        "La fundamental final se calcula entre 0,4 y 0,5 s. "
        "El máximo de modulación corresponde al registro completo; "
        "no es una medida del tiempo de establecimiento.",
    ]
    return "\n".join(lineas) + "\n"


def main() -> None:
    compilador = shutil.which("pdflatex")
    if not compilador:
        raise SystemExit("Se requiere pdflatex con IEEEtran, babel-spanish y booktabs.")
    datos = json.loads(RESULTADOS.read_text(encoding="utf-8"))
    for nombre, esperado in datos["modelos_sha256"].items():
        modelo = PROYECTO / f"modelos/plecs/{nombre}.plecs"
        actual = hashlib.sha256(modelo.read_bytes()).hexdigest()
        if actual != esperado:
            raise SystemExit(
                f"El modelo {nombre} cambió. Actualice sus resultados antes de publicar."
            )
    BUILD.mkdir(parents=True, exist_ok=True)
    (BUILD / "datos_simulacion.tex").write_text(tablas(datos), encoding="utf-8")
    # Compilar copias mantiene los archivos auxiliares fuera de la documentación.
    for fuente in FUENTES.glob("*.tex"):
        shutil.copy2(fuente, BUILD / fuente.name)
    for nombre in ("diseno_potencia", "informe_potencia"):
        for _ in range(2):
            ejecucion = subprocess.run(
                [compilador, "-interaction=nonstopmode", "-halt-on-error", f"{nombre}.tex"],
                cwd=BUILD, capture_output=True, text=True, errors="replace",
            )
            if ejecucion.returncode:
                raise SystemExit(
                    f"Falló la compilación de {nombre}. Consulte {BUILD / (nombre + '.log')}"
                    "\n" + ejecucion.stdout[-3000:]
                )
        destino = FUENTES / f"{nombre}.pdf"
        shutil.copy2(BUILD / destino.name, destino)
        print(destino.relative_to(PROYECTO))


if __name__ == "__main__":
    main()
