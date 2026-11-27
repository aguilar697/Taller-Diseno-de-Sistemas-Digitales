"""Genera los documentos de Potencia en PDF mediante LaTeX."""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess


PROYECTO = Path(__file__).resolve().parents[1]
FUENTES = PROYECTO / "docs/informe/potencia"
BUILD = PROYECTO / "build/informes_potencia"
RESULTADOS = PROYECTO / "docs/informe/resultados/potencia/lazo_funcional.json"


def numero(valor: float, cifras: int = 3) -> str:
    """Redondea para presentación sin reducir la precisión de los resultados fuente."""
    from decimal import Decimal

    redondeado = format(Decimal(format(valor, f".{cifras}g")), "f")
    return redondeado.replace(".", "{,}")


def tablas(datos: dict) -> str:
    lineas = [
        r"\par",
        r"La Tabla~\ref{tab:nominal} reúne la fundamental, el error de amplitud y el desfase "
        r"de los seis puntos nominales simulados con la copia funcional.",
        r"\begin{table}[H]",
        r"\caption{Seguimiento simulado de la copia funcional}",
        r"\label{tab:nominal}\centering\small",
        r"\begin{tabular}{@{}ccccc@{}}\toprule",
        r"$V_{dc}$ & $I_{\mathrm{ref},pk}$ & $I_{1,pk}$ & $|E_A|$ & $\phi$\\",
        r"(V) & (A) & (mA) & (\%) & ($^\circ$)\\\midrule",
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
            numero(v["Iref"], 3),
            numero(1000 * caso["fundamental_a_pico"]),
            numero(abs(caso["error_amplitud_porcentaje"])),
            numero(caso["fase_grados"]),
        ]
        lineas.append(" & ".join(valores) + r"\\")
    lineas += [
        r"\bottomrule\end{tabular}\end{table}\par",
        r"La Tabla~\ref{tab:transitorios} resume los cambios de referencia y de carga "
        r"simulados a 12 V. Se reportan el seguimiento final y la máxima modulación "
        r"del registro para comprobar el margen disponible durante la transición.",
        r"\begin{table}[H]",
        r"\caption{Simulación de transitorios a 12 V}",
        r"\label{tab:transitorios}\centering\small",
        r"\begin{tabular}{@{}lccc@{}}\toprule",
        r"Ensayo & $I_{1,pk}$ final & $|E_A|$ final & $\max |m|$\\",
        r" & (mA) & (\%) & \\\midrule",
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
            numero(1000 * caso["fundamental_a_pico"]),
            numero(abs(caso["error_amplitud_porcentaje"])),
            numero(caso["modulacion_max_abs"], 3),
        ]
        lineas.append(" & ".join(valores) + r"\\")
    lineas += [
        r"\bottomrule\end{tabular}\end{table}\par",
        "La fundamental final se calcula entre 400 y 500 ms. "
        "El máximo de modulación corresponde al registro completo; "
        "no es una medida del tiempo de establecimiento.",
    ]
    return "\n".join(lineas) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--modelos-simulados", type=Path, default=PROYECTO / "modelos/plecs",
                        help="Directorio de los modelos con que se generó el JSON de resultados.")
    args = parser.parse_args()
    compilador = shutil.which("pdflatex")
    if not compilador:
        raise SystemExit("Se requiere pdflatex con IEEEtran, babel-spanish y booktabs.")
    datos = json.loads(RESULTADOS.read_text(encoding="utf-8"))
    for nombre, esperado in datos["modelos_sha256"].items():
        modelo = args.modelos_simulados / f"{nombre}.plecs"
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
    if (FUENTES / "figuras").is_dir():
        shutil.copytree(FUENTES / "figuras", BUILD / "figuras", dirs_exist_ok=True)
    evidencia = PROYECTO / "Potencia/mediciones_lab_osciloscopio/final_82a8226_12V"
    for ensayo in ("regimen", "escalones", "cambio_carga"):
        destino_figuras = BUILD / "figuras/final_12v" / ensayo
        destino_figuras.mkdir(parents=True, exist_ok=True)
        for figura in (evidencia / ensayo).glob("*.png"):
            shutil.copy2(figura, destino_figuras / figura.name)
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
