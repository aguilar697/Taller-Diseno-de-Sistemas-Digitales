"""Crea el proyecto Basys 3 y genera un bitstream con comprobación de tiempo y DRC."""

import argparse
from datetime import datetime
from pathlib import Path
import shutil

from ensamblar_programa import assemble
from vivado_common import ROOT, find_bin, stage_project, invoke


IMPLEMENT = r'''
set_param general.maxThreads 4
source scripts/crear_proyecto.tcl
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {[get_property PROGRESS [get_runs synth_1]] ne "100%"} {error "La síntesis no finalizó"}
open_run synth_1
set latches [get_cells -hier -quiet -filter {PRIMITIVE_TYPE =~ REGISTER.LATCH.*}]
set f [open latches.txt w]
puts $f "LATCHES [llength $latches]"
close $f
if {[llength $latches]} {error "Se detectaron latches en el diseño"}
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "La implementación no finalizó"}
open_run impl_1
report_timing_summary -max_paths 10 -file timing.rpt
report_utilization -file utilizacion.rpt
report_drc -file drc.rpt
set violations [get_drc_violations -quiet]
if {[llength $violations]} {error "La implementación tiene infracciones DRC"}
foreach delay {max min} {
    set paths [get_timing_paths -delay_type $delay -max_paths 1]
    if {![llength $paths] || [get_property SLACK $paths] < 0} {
        error "No se cumple el análisis temporal $delay"
    }
}
write_bitstream -force batalla_naval.bit
close_project
exit
'''


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--vivado-bin", type=Path)
    parser.add_argument("--project-only", action="store_true", help="Crea el .xpr sin ejecutar síntesis ni implementación")
    args = parser.parse_args()
    output = None
    try:
        words, used = assemble()
        if words != [int(x, 16) for x in (ROOT / "src/software_riscv/program.hex").read_text().split()]:
            raise RuntimeError("El HEX no corresponde al ensamblador; ejecute ensamblar_programa.py")
        bin_dir = find_bin(args.vivado_bin)
        work = stage_project()
        shutil.copy2(work / "src/software_riscv/program.hex", work / "program.hex")
        print(f"ROM: {used}/2048 palabras. Trabajo: {work}", flush=True)
        script = work / "ejecutar.tcl"
        script.write_text("source scripts/crear_proyecto.tcl\nclose_project\nexit\n" if args.project_only else IMPLEMENT, encoding="utf-8")
        output = ROOT / "build/vivado" / datetime.now().strftime("%Y%m%d_%H%M%S_%f")
        output.mkdir(parents=True)
        log = output / "vivado.log"
        invoke(bin_dir, "vivado", ["-mode", "batch", "-nojournal", "-nolog", "-source", script.as_posix()], work, log)
        for filename in ("timing.rpt", "utilizacion.rpt", "drc.rpt", "latches.txt", "batalla_naval.bit", "manifest.json"):
            if (work / filename).is_file(): shutil.copy2(work / filename, output / filename)
        project = work / "build/proyecto_vivado/batalla_naval.xpr"
        print(f"Proyecto para abrir en Vivado: {project}")
        if not args.project_only:
            if not (output / "batalla_naval.bit").is_file(): raise RuntimeError("No se generó el bitstream")
            print(f"Implementación aprobada. Bitstream y reportes: {output}")
        return 0
    except (RuntimeError, ValueError, OSError) as exc:
        if output: print(f"Reportes de esta ejecución: {output}")
        parser.exit(1, f"ERROR: {exc}\n")


if __name__ == "__main__":
    raise SystemExit(main())
