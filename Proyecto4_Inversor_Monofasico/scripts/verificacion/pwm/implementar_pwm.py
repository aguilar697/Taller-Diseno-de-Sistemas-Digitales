"""Implementa el PWM en un directorio temporal y conserva los resultados en build/."""
import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[3]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vivado-home", default=os.environ.get("VIVADO_HOME"), required=False)
    parser.add_argument("--nombre", default=datetime.now().strftime("%Y%m%d_%H%M%S"))
    args = parser.parse_args()
    if not args.vivado_home or not re.fullmatch(r"[A-Za-z0-9_-]+", args.nombre):
        parser.error("Indique --vivado-home y un nombre nuevo sin espacios")
    executable = Path(args.vivado_home) / "bin" / ("vivado.bat" if os.name == "nt" else "vivado")
    if not executable.is_file():
        parser.error("No se encontro Vivado")
    output = ROOT / "build/pwm" / args.nombre
    output.mkdir(parents=True, exist_ok=False)
    # Vivado puede interrumpir la síntesis si el directorio de trabajo contiene
    # caracteres no ASCII. Solo se copian las fuentes necesarias a un área temporal.
    with tempfile.TemporaryDirectory(prefix="pwm_impl_") as temporary:
        stage = Path(temporary)
        if not str(stage).isascii():
            parser.error("Configure TEMP en una ruta ASCII para esta herramienta")
        sources = [ROOT / "src/design/pwm" / (name + ".sv") for name in
                   ("pwm_deadtime", "pwm_core", "pwm_axi_lite", "pwm_system_axi")]
        sources.append(Path(__file__).with_suffix(".tcl"))
        hashes = {}
        for source in sources:
            relative = source.relative_to(ROOT)
            target = stage / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source, target)
            hashes[str(relative)] = hashlib.sha256(source.read_bytes()).hexdigest()
        (output / "fuentes.json").write_text(json.dumps(hashes, indent=2), encoding="utf-8")
        command = [str(executable), "-mode", "batch", "-nojournal", "-log", "vivado.log",
                   "-source", "scripts/verificacion/pwm/implementar_pwm.tcl", "-tclargs", "resultados"]
        (output / "comando.json").write_text(json.dumps(command, indent=2), encoding="utf-8")
        result = subprocess.run(command, cwd=stage, capture_output=True, text=True,
                                errors="replace", timeout=1800)
        log = result.stdout + result.stderr
        (output / "consola.txt").write_text(log, encoding="utf-8")
        if (stage / "vivado.log").exists():
            shutil.copyfile(stage / "vivado.log", output / "vivado.log")
        if (stage / "resultados").exists():
            shutil.copytree(stage / "resultados", output / "resultados")
        passed = result.returncode == 0 and "PWM_IMPLEMENTATION_PASSED" in log
        (output / "estado.json").write_text(json.dumps({"resultado": "PASS" if passed else "FAIL",
            "codigo_salida": result.returncode, "fuentes": hashes}, indent=2), encoding="utf-8")
        print(log[-3500:])
        print(f"Resultados: {output}")
        return 0 if passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
