"""Síntesis, implementación y bitstream del sistema completo (basys3_top).

Usa las fuentes de src/design, el IP pixel_clock_wiz, la restricción
src/constraints/basys3_battleship.xdc y src/software_riscv/program.hex.
Copia todo a una carpeta temporal sin espacios, ejecuta Vivado en modo batch
y deja los reportes y el bitstream en build/vivado/.

Uso:  python scripts/implementar_basys3.py
"""

import os
import re
import shutil
import subprocess
import sys
import tempfile

AQUI = os.path.dirname(os.path.abspath(__file__))
EQUIPO = os.path.normpath(os.path.join(AQUI, ".."))
VIVADO = os.path.join(os.environ.get("VIVADO_BIN", r"C:\AMDDesignTools\2026.1\Vivado\bin"), "vivado.bat")
TRABAJO = os.path.join(tempfile.gettempdir(), "bn_equipo_vivado")

SV = [
    "cpu/cpu_pkg.sv", "cpu/alu.sv", "cpu/immediate_generator.sv", "cpu/register_file.sv",
    "cpu/instruction_decoder.sv", "cpu/cpu_control.sv", "cpu/cpu_datapath.sv", "cpu/cpu.sv",
    "memory/program_rom.sv", "memory/data_ram.sv",
    "bus/address_decoder.sv", "bus/data_bus.sv",
    "uart/uart_tx.sv", "uart/uart_rx.sv", "uart/uart_peripheral.sv",
    "outputs/sevenseg_driver.sv", "outputs/sevenseg_peripheral.sv",
    "outputs/led_peripheral.sv", "outputs/buzzer_peripheral.sv",
    "integration/mmio_subsystem_top.sv",
    "inputs/input_sync.sv", "inputs/debounce.sv", "inputs/player1_inputs.sv",
    "vga/pixel_clock.sv", "vga/pixel_reset_sync.sv", "vga/vga_timing.sv",
    "vga/video_memory.sv", "vga/glyph_rom.sv", "vga/tile_renderer.sv",
    "vga/subsystem2_vga_inputs.sv",
    "top/battleship_top.sv", "top/basys3_top.sv",
]

TCL = r"""
set_param general.maxThreads 4
create_project -in_memory -part xc7a35tcpg236-1
read_ip ip/pixel_clock_wiz.xci
set_property generate_synth_checkpoint false [get_files ip/pixel_clock_wiz.xci]
generate_target all [get_files ip/pixel_clock_wiz.xci]
read_verilog -sv {%(sv)s}
read_xdc basys3_battleship.xdc
synth_design -top basys3_top -part xc7a35tcpg236-1
set latches [get_cells -hier -quiet -filter {PRIMITIVE_TYPE =~ REGISTER.LATCH.*}]
set f [open latches.txt w]; puts $f "LATCHES [llength $latches]"; foreach c $latches {puts $f $c}; close $f
opt_design
place_design
route_design
report_timing_summary -max_paths 10 -file timing.rpt
report_utilization -file utilizacion.rpt
report_drc -file drc.rpt
write_bitstream -force batalla_naval.bit
"""


def main():
    if os.path.exists(TRABAJO):
        shutil.rmtree(TRABAJO, ignore_errors=True)
    os.makedirs(os.path.join(TRABAJO, "ip"), exist_ok=True)
    diseno = os.path.join(EQUIPO, "src", "design")
    for f in SV:
        shutil.copyfile(os.path.join(diseno, f), os.path.join(TRABAJO, os.path.basename(f)))
    shutil.copyfile(os.path.join(diseno, "vga", "ip", "pixel_clock_wiz.xci"),
                    os.path.join(TRABAJO, "ip", "pixel_clock_wiz.xci"))
    shutil.copyfile(os.path.join(EQUIPO, "src", "constraints", "basys3_battleship.xdc"),
                    os.path.join(TRABAJO, "basys3_battleship.xdc"))
    shutil.copyfile(os.path.join(EQUIPO, "src", "software_riscv", "program.hex"),
                    os.path.join(TRABAJO, "program.hex"))
    with open(os.path.join(TRABAJO, "implementar.tcl"), "w") as f:
        f.write(TCL % {"sv": " ".join(os.path.basename(x) for x in SV)})

    r = subprocess.run('"%s" -mode batch -nojournal -source implementar.tcl' % VIVADO,
                       shell=True, cwd=TRABAJO, capture_output=True, text=True,
                       encoding="utf-8", errors="replace")
    salida = os.path.join(EQUIPO, "build", "vivado")
    os.makedirs(salida, exist_ok=True)
    with open(os.path.join(salida, "vivado.log"), "w", encoding="utf-8") as f:
        f.write(r.stdout + r.stderr)
    for nombre in ("latches.txt", "utilizacion.rpt", "timing.rpt", "drc.rpt", "batalla_naval.bit"):
        origen = os.path.join(TRABAJO, nombre)
        if os.path.exists(origen):
            shutil.copyfile(origen, os.path.join(salida, nombre))

    print("Vivado termino con codigo %d" % r.returncode)
    for linea in [l for l in (r.stdout + r.stderr).splitlines() if l.startswith(("ERROR", "CRITICAL WARNING"))][:20]:
        print("  " + linea)
    ruta = os.path.join(salida, "timing.rpt")
    if os.path.exists(ruta):
        texto = open(ruta).read()
        m = re.search(r"WNS\(ns\)\s+TNS\(ns\).*?\n.*?\n\s*([-\d.]+)\s+([-\d.]+)\s+\d+\s+\d+\s+([-\d.]+)", texto)
        if m:
            print("  WNS %s ns   WHS %s ns" % (m.group(1), m.group(3)))
        print("  timing cumplido: %s" % ("All user specified timing constraints are met" in texto))
    ruta = os.path.join(salida, "latches.txt")
    if os.path.exists(ruta):
        print("  " + open(ruta).readline().strip())
    ruta = os.path.join(salida, "utilizacion.rpt")
    if os.path.exists(ruta):
        texto = open(ruta).read()
        for clave in ("Slice LUTs", "Slice Registers", "Block RAM Tile", "MMCME2_ADV"):
            m = re.search(r"\|\s*%s\*?\s*\|\s*([\d.]+)\s*\|" % re.escape(clave), texto)
            if m:
                print("  %-16s %s" % (clave, m.group(1)))
    ruta = os.path.join(salida, "drc.rpt")
    if os.path.exists(ruta):
        m = re.search(r"Checks found:\s*(\d+)", open(ruta).read())
        if m:
            print("  DRC: %s incidencias" % m.group(1))
    bit = os.path.exists(os.path.join(salida, "batalla_naval.bit"))
    print("  bitstream: %s" % bit)
    return 0 if (r.returncode == 0 and bit) else 1


if __name__ == "__main__":
    sys.exit(main())
