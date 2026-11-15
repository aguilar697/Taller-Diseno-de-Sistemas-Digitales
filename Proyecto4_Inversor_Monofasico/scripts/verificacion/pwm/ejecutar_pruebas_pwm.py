"""Compila y ejecuta los TB PWM desde fuentes; conserva comandos, huellas y logs."""
import argparse
from datetime import datetime
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys


ROOT = Path(__file__).resolve().parents[3]
DESIGN = ROOT / "src/design/pwm"
TB = ROOT / "src/testbench/pwm"
FUNCTIONAL = ("tb_pwm_deadtime", "tb_pwm_core", "tb_pwm_axi", "tb_pwm_adc")
TOPS = FUNCTIONAL + ("tb_pwm_timing",)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--simulador", choices=("iverilog", "xsim"), default="iverilog")
    parser.add_argument("--vivado-home", default=os.environ.get("VIVADO_HOME"))
    parser.add_argument("--tests", nargs="+", choices=TOPS, default=list(FUNCTIONAL))
    parser.add_argument("--netlist-dir", type=Path,
                        help="Directorio con pwm_timesim.v y pwm_timesim.sdf para XSim")
    parser.add_argument("--error-forzado", action="store_true")
    parser.add_argument("--nombre", default=datetime.now().strftime("%Y%m%d_%H%M%S"))
    args = parser.parse_args()
    if not re.fullmatch(r"[A-Za-z0-9_-]+", args.nombre):
        parser.error("El nombre solo admite letras, numeros, guion y guion bajo")
    if args.error_forzado and args.tests != ["tb_pwm_axi"]:
        parser.error("El error forzado requiere --tests tb_pwm_axi")
    if args.netlist_dir and (args.simulador != "xsim" or args.tests != ["tb_pwm_timing"]):
        parser.error("La netlist requiere --simulador xsim --tests tb_pwm_timing")
    work = ROOT / "build/pwm" / args.nombre
    work.mkdir(parents=True, exist_ok=False)
    if args.simulador == "xsim":
        if not args.vivado_home:
            parser.error("Indique --vivado-home o VIVADO_HOME")
        bindir = Path(args.vivado_home) / "bin"
        suffix = ".bat" if os.name == "nt" else ""
        programs = {n: str(bindir / (n + suffix)) for n in ("xvlog", "xelab", "xsim")}
    else:
        programs = {n: shutil.which(n) for n in ("iverilog", "vvp")}
    for program in programs.values():
        if not program or not Path(program).is_file():
            parser.error("No se encontro un ejecutable del simulador")
    summary = []
    for top in args.tests:
        target = work / top
        target.mkdir()
        sources = [DESIGN / (n + ".sv") for n in
                   ("pwm_deadtime", "pwm_core", "pwm_axi_lite", "pwm_system_axi")]
        if top == "tb_pwm_adc":
            sources.append(ROOT / "src/design/adc/adc_control.sv")
        sources.append(TB / (top + ".sv"))
        if args.netlist_dir:
            for name in ("pwm_timesim.v", "pwm_timesim.sdf"):
                shutil.copyfile(args.netlist_dir / name, target / name)
            sources = [target / "pwm_timesim.v",
                       Path(args.vivado_home) / "data/verilog/src/glbl.v", TB / (top + ".sv")]
        inputs = sources + [TB / "pwm_axi_tb.svh", Path(__file__).resolve()]
        if args.netlist_dir:
            inputs.append(target / "pwm_timesim.sdf")
        hashes = {str(p.relative_to(ROOT)) if p.is_relative_to(ROOT) else p.name:
                  hashlib.sha256(p.read_bytes()).hexdigest() for p in inputs}
        (target / "fuentes.json").write_text(json.dumps(hashes, indent=2), encoding="utf-8")
        if args.simulador == "iverilog":
            commands = [
                [programs["iverilog"], "-g2012", "-I", str(TB), "-s", top,
                 "-o", "test.vvp", *map(str, sources)],
                [programs["vvp"], "test.vvp"] + (["+INJECT_ERROR"] if args.error_forzado else []),
            ]
        else:
            if args.netlist_dir:
                # El archivo evita que los scripts .bat separen el signo '='.
                (target / "sdf_options.txt").write_text(
                    "--sdfmax /tb_pwm_timing/dut=pwm_timesim.sdf\n", encoding="ascii")
            timing_options = (["-L", "simprims_ver", "-L", "secureip",
                               "-f", "sdf_options.txt"]
                              if args.netlist_dir else [])
            commands = [
                [programs["xvlog"], "--sv", "-i", str(TB),
                 *(["-d", "PWM_TIMING_SDF"] if args.netlist_dir else []),
                 *map(str, sources), "-log", "compile.log"],
                [programs["xelab"], "--debug", "typical", "--snapshot", top,
                 "work." + top, *(["work.glbl"] if args.netlist_dir else []),
                 *timing_options, "-log", "elaborate.log"],
                [programs["xsim"], top, "-runall", "-log", "simulate.log"] +
                (["-testplusarg", "INJECT_ERROR"] if args.error_forzado else []),
            ]
        (target / "comandos.json").write_text(json.dumps(commands, indent=2), encoding="utf-8")
        outputs = []
        failed = False
        for i, command in enumerate(commands):
            result = subprocess.run(command, cwd=target, capture_output=True,
                                    text=True, errors="replace", timeout=240)
            output = result.stdout + result.stderr
            (target / f"paso_{i}.txt").write_text(output, encoding="utf-8")
            outputs.append(output)
            if i < len(commands)-1 and result.returncode:
                failed = True
                break
        log = "\n".join(outputs)
        if (target / "simulate.log").exists():
            log += (target / "simulate.log").read_text(encoding="utf-8", errors="replace")
        passed = (not failed and result.returncode == 0 and "TEST PASSED" in log
                  and not re.search(r"(?im)^\s*(Fatal:|FATAL:|ERROR:|Error:)", log))
        if args.netlist_dir:
            passed = (passed and "PWM_SDF_MAXIMUM_ENABLED" in log and
                      "SDF backannotation was successful" in log and
                      not re.search(r"(?i)without back annotation|SDF.*(error|cannot)|timing violation|\$setuphold", log))
        detected = (not failed and args.error_forzado and "PWM_OVERLAP_DETECTED" in log
                    and "TEST PASSED" not in log)
        state = "EXPECTED_FAILURE" if detected else "PASS" if passed and not args.error_forzado else "FAIL"
        count = re.search(r"TEST PASSED .*?checks=(\d+)", log)
        summary.append({"top": top, "resultado": state, "comprobaciones": int(count[1]) if count else None,
                        "simulador": args.simulador, "codigo_salida": result.returncode,
                        "fuentes": hashes})
        (work / "resumen.json").write_text(json.dumps(summary, indent=2), encoding="utf-8")
        print(f"{top}: {state}" + (f" ({count[1]} comprobaciones)" if count else ""), flush=True)
        if state == "FAIL":
            print(log[-5000:], file=sys.stderr)
            return 1
    print(f"Resultados: {work}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
