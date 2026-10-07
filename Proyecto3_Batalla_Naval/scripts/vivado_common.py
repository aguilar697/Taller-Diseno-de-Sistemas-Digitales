"""Preparación de fuentes y ejecución de herramientas Vivado en rutas temporales."""

from pathlib import Path
import hashlib
import json
import os
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def find_bin(requested=None):
    candidates = []
    if requested or os.environ.get("VIVADO_BIN"):
        candidates.append(Path(requested or os.environ["VIVADO_BIN"]))
    else:
        for name in ("vivado.bat", "vivado"):
            executable = shutil.which(name)
            if executable: candidates.append(Path(executable).parent)
        if os.name == "nt":
            for base in (Path("C:/AMDDesignTools"), Path("C:/Xilinx/Vivado")):
                candidates += sorted(base.glob("*/Vivado/bin"), reverse=True)
                candidates += sorted(base.glob("*/bin"), reverse=True)
    for candidate in candidates:
        if (candidate / ("vivado.bat" if os.name == "nt" else "vivado")).is_file():
            return candidate.resolve()
    raise RuntimeError("No se encontró Vivado. Configure VIVADO_BIN con la carpeta bin de su instalación.")


def stage_project():
    # mkdtemp crea una carpeta exclusiva; no se borran proyectos existentes.
    work = Path(tempfile.mkdtemp(prefix="bn_vivado_"))
    manifest = {}
    files = sorted((ROOT / "src/design").rglob("*.sv"))
    files += list((ROOT / "src/design/vga/ip").glob("*.xci"))
    files += [ROOT / "src/constraints/basys3_battleship.xdc",
              ROOT / "src/software_riscv/program.hex",
              ROOT / "scripts/crear_proyecto.tcl"]
    files += sorted((ROOT / "src/testbench").rglob("*.sv"))
    files += [ROOT / "src/testbench/memory/program_rom_tb.hex",
              ROOT / "src/testbench/integration/guion.txt",
              ROOT / "src/testbench/integration/tramas_esperadas.txt"]
    for source in files:
        relative = source.relative_to(ROOT)
        target = work / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(source, target)
        manifest[relative.as_posix()] = hashlib.sha256(source.read_bytes()).hexdigest()
    (work / "manifest.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return work


def invoke(bin_dir, tool, args, work, log):
    executable = bin_dir / (tool + ".bat" if os.name == "nt" else tool)
    command = [str(executable), *map(str, args)]
    if os.name == "nt": command = [os.environ["COMSPEC"], "/d", "/c", *command]
    with log.open("w", encoding="utf-8") as output:
        result = subprocess.run(command, cwd=work, stdout=output, stderr=subprocess.STDOUT)
    text = log.read_text(encoding="utf-8", errors="replace")
    if result.returncode or "ERROR:" in text:
        raise RuntimeError(f"{tool} falló. Consulte {log}\n{text[-1800:]}")
    return text
