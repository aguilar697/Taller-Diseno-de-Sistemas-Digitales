"""Synthesize S2 in an isolated temporary directory, then retain reports locally."""
import argparse
import hashlib
from pathlib import Path
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--vivado", help="Path to vivado executable or vivado.bat")
args = parser.parse_args()
vivado = args.vivado or shutil.which("vivado")
if not vivado:
    default = Path("C:/AMDDesignTools/2026.1/Vivado/bin/vivado.bat")
    if default.is_file():
        vivado = str(default)
if not vivado:
    raise SystemExit("Vivado not found; use --vivado")

scratch = Path(tempfile.mkdtemp(prefix="ahorcado_synth_"))
sources = [Path(f"src/design/word_engine/{name}.sv") for name in
           ("word_lfsr", "word_rom", "letter_evaluator", "word_engine")]
sources.append(Path("scripts/synth_word_engine.tcl"))
for relative in sources:
    target = scratch / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(root / relative, target)
print(f"Synthesis workspace: {scratch}", flush=True)
result = subprocess.run([vivado, "-mode", "batch", "-source", "scripts/synth_word_engine.tcl"],
                        cwd=scratch)
out = root / "build/word_engine"
out.mkdir(parents=True, exist_ok=True)
for source in (scratch / "build/word_engine").glob("*"):
    if source.is_file():
        shutil.copyfile(source, out / source.name)
if (scratch / "vivado.log").exists():
    shutil.copyfile(scratch / "vivado.log", out / "vivado.log")
for relative in sources:
    if (root / relative).read_bytes() != (scratch / relative).read_bytes():
        raise SystemExit(f"Source changed during synthesis: {relative}; rerun verification")
manifest = "\n".join(f"{hashlib.sha256((scratch / p).read_bytes()).hexdigest()}  {p.as_posix()}"
                     for p in sources) + "\n"
(out / "source_sha256.txt").write_text(manifest, encoding="ascii")
result.check_returncode()
print(f"Reports saved to {out}; temporary synthesis workspace retained for inspection")
