"""Ejecuta pruebas RTL y una partida completa en XSim sin herramientas externas."""

import argparse
from datetime import datetime
import json
from pathlib import Path
import re
import shutil
import sys

from ensamblar_programa import assemble
from vivado_common import ROOT, find_bin, stage_project, invoke


def check_game(work):
    actual = (work / "tramas.txt").read_text().splitlines()
    expected = (ROOT / "src/testbench/integration/tramas_esperadas.txt").read_text().splitlines()
    if actual != expected:
        raise RuntimeError("Las tramas del juego no corresponden al guion esperado")
    sys.path.insert(0, str(ROOT / "src/software_pc"))
    from naval_terminal import FrameParser, valid_notification
    parser = FrameParser()
    for row in actual:
        values = list(map(int, row.split()))
        frames = parser.feed(bytes([0xA5, values[0], len(values) - 1, *values[1:]]))
        if len(frames) != 1 or not valid_notification(frames[0]):
            raise RuntimeError(f"Notificación incompatible con la terminal: {row}")
    memory = {}
    indicators = {}
    for row in (work / "estado_sistema.txt").read_text().splitlines():
        fields = row.split()
        if fields[0] == "M": memory[int(fields[1], 16)] = fields[2].lower()
        elif fields[0] in ("LED", "DISPLAY"): indicators[fields[0]] = int(fields[1], 16)
    # Estado esperado antes de GAME_RST: J1 gana con nueve impactos, J2 falla ocho veces.
    for player in (1, 2):
        board = [0] * 64
        for ship, length in enumerate((4, 3, 2)):
            for offset in range(length):
                row, col = (offset, 2 * ship) if player == 1 else (2 * ship, offset)
                board[8 * row + col] = 1 if player == 1 else 3
        if player == 1: board[56:64] = [2] * 8
        for index, value in enumerate(board):
            address = (0x2000 if player == 1 else 0x2100) + 4 * index
            if memory[address] != f"{value:08x}": raise RuntimeError(f"Tablero incorrecto en {address:08x}")
    expected_state = {0x2200: 2, 0x2204: 1, 0x2208: 1, 0x220C: 1,
                      0x2210: 1, 0x2214: 0, 0x2218: 9, 0x221C: 8,
                      0x22F4: 3, 0x22F8: 0, 0x22FC: 1}
    for address, value in expected_state.items():
        if memory[address] != f"{value:08x}": raise RuntimeError(f"Estado incorrecto en {address:08x}")
    if indicators != {"LED": 2, "DISPLAY": 1}: raise RuntimeError("LED o marcador incorrecto")
    return {"tramas": len(actual), "palabras_ram": 128 + len(expected_state), "indicadores": 2}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all", action="store_true", help="Incluye todos los testbenches unitarios")
    parser.add_argument("--vivado-bin", type=Path)
    args = parser.parse_args()
    output = None
    try:
        words, _ = assemble()
        if words != [int(x, 16) for x in (ROOT / "src/software_riscv/program.hex").read_text().split()]:
            raise RuntimeError("El HEX no corresponde a las fuentes ensamblador")
        bin_dir = find_bin(args.vivado_bin)
        work = stage_project()
        output = ROOT / "build/simulacion" / datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        output.mkdir(parents=True)
        for source in (work / "src/software_riscv/program.hex", work / "src/testbench/memory/program_rom_tb.hex", work / "src/testbench/integration/guion.txt"):
            shutil.copy2(source, work / source.name)
        design = sorted((work / "src/design").rglob("*.sv"))
        test_files = sorted((work / "src/testbench").rglob("*.sv"))
        packages = [work / "src/design/cpu/cpu_pkg.sv", work / "src/testbench/cpu/cpu_tb_pkg.sv"]
        files = packages + [p for p in design + test_files if p not in packages]
        (work / "compilar.txt").write_text('--sv\n--work xil_defaultlib\n--define BN_FUNCTIONAL_CLOCK\n' +
            '\n'.join('"' + p.as_posix() + '"' for p in files) + '\n', encoding="utf-8")
        print("Compilando RTL y testbenches. Reloj VGA: modelo funcional de 25 MHz.", flush=True)
        invoke(bin_dir, "xvlog", ["-f", (work / "compilar.txt").as_posix()], work, output / "compilacion.log")
        (work / "simular.tcl").write_text("run all\nquit\n", encoding="utf-8")
        names = []
        for path in test_files:
            if path.name == "pixel_clock_wiz_sim.sv": continue
            match = re.search(r"^\s*module\s+(\w+)", path.read_text(encoding="utf-8"), re.M)
            if match and (args.all or match[1] == "tb_battleship_system"): names.append(match[1])
        results = []
        for name in names:
            print(f"Ejecutando {name}...", flush=True)
            snapshot = name + "_test"
            invoke(bin_dir, "xelab", ["xil_defaultlib." + name, "--snapshot", snapshot, "--mt", "2"], work, output / (name + "_elab.log"))
            log = invoke(bin_dir, "xsim", [snapshot, "-tclbatch", (work / "simular.tcl").as_posix()], work, output / (name + ".log"))
            if re.search(r"FATAL|Fatal:|Error:|\[FAIL\]|TEST FAILED|FALLO:", log, re.I) or not re.search(r"PASS|TODAS LAS PRUEBAS PASARON", log):
                raise RuntimeError(f"{name} no aprobó. Consulte {output / (name + '.log')}")
            results.append({"testbench": name, "resultado": "PASS"})
            print(f"PASS {name}", flush=True)
        game = check_game(work)
        for filename in ("tramas.txt", "buzzer.txt", "estado_sistema.txt", "manifest.json", "foto_batalla.txt", "foto_resultado.txt"):
            if (work / filename).is_file(): shutil.copy2(work / filename, output / filename)
        (output / "resumen.json").write_text(json.dumps({"pruebas": results, "juego": game}, indent=2), encoding="utf-8")
        print(f"PASS: {len(results)} testbenches, {game['tramas']} tramas y {game['palabras_ram']} palabras de estado. Resultados: {output}")
        return 0
    except (RuntimeError, ValueError, OSError) as exc:
        if output: print(f"Resultados de esta ejecución: {output}")
        parser.exit(1, f"ERROR: {exc}\n")


if __name__ == "__main__":
    raise SystemExit(main())
