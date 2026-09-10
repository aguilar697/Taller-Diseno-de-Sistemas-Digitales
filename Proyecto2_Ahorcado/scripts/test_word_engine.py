"""Run the self-checking SystemVerilog testbench with Icarus Verilog."""
import argparse
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--icarus-bin", type=Path, help="Directory containing iverilog and vvp")
args = parser.parse_args()


def executable(name):
    if args.icarus_bin:
        path = args.icarus_bin / (name + (".exe" if sys.platform == "win32" else ""))
        if path.is_file():
            return str(path)
    found = shutil.which(name)
    if found:
        return found
    default = Path("C:/iverilog/bin") / f"{name}.exe"
    if sys.platform == "win32" and default.is_file():
        return str(default)
    raise SystemExit(f"Cannot find {name}; use --icarus-bin")


subprocess.run([sys.executable, "scripts/generate_word_rom.py", "--check"], cwd=root, check=True)
out = root / "build/word_engine"
out.mkdir(parents=True, exist_ok=True)
sources = [f"src/design/word_engine/{name}.sv" for name in
           ("word_lfsr", "word_rom", "letter_evaluator", "word_engine")]
sources.append("src/testbench/word_engine/word_engine_tb.sv")
compiled = "build/word_engine/word_engine_tb.vvp"
subprocess.run([executable("iverilog"), "-g2012", "-Wall", "-s", "word_engine_tb",
                "-o", compiled, *sources], cwd=root, check=True)
result = subprocess.run([executable("vvp"), compiled], cwd=root, text=True,
                        capture_output=True, timeout=60)
print(result.stdout, end="")
print(result.stderr, end="", file=sys.stderr)
(out / "simulation_result.txt").write_text(result.stdout + result.stderr, encoding="utf-8")
result.check_returncode()
