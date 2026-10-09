"""Verifica arranque y rechazos UART con el netlist enrutado y retardos SDF."""

import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re
import shutil
import tempfile

from vivado_common import ROOT, find_bin, invoke


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True,
                        help="Proyecto .xpr con impl_1 enrutada")
    parser.add_argument("--vivado-bin", type=Path)
    args = parser.parse_args()
    project = args.project.resolve()
    if not project.is_file():
        parser.error("No existe el proyecto indicado")
    work = Path(tempfile.mkdtemp(prefix="bn_postimpl_"))
    output = ROOT / "build/postimplementacion" / datetime.now().strftime("%Y%m%d_%H%M%S_%f")
    output.mkdir(parents=True)
    try:
        bin_dir = find_bin(args.vivado_bin)
        # Llaves de Tcl preservan espacios de la ruta. Se rechazan caracteres
        # que terminarían prematuramente el argumento, sin evaluar comandos.
        if any(c in project.as_posix() for c in "{}\n\r"):
            raise ValueError("La ruta del proyecto contiene caracteres no admitidos")
        export = work / "exportar.tcl"
        export.write_text(
            "open_project {" + project.as_posix() + "}\n"
            "open_run impl_1\n"
            "write_sdf -force -process_corner slow circuito.sdf\n"
            "write_verilog -force -mode timesim -sdf_anno true "
            "-sdf_file circuito.sdf circuito.v\n"
            "close_project\nexit\n", encoding="utf-8")
        invoke(bin_dir, "vivado", ["-mode", "batch", "-nojournal", "-nolog",
                                   "-source", export.as_posix()], work, output / "exportacion.log")
        tb = ROOT / "scripts/postimplementacion/basys3_postimplementacion_tb.sv"
        shutil.copy2(tb, work / "prueba.sv")
        glbl = bin_dir.parent / "data/verilog/src/glbl.v"
        invoke(bin_dir, "xvlog", ["circuito.v", glbl.as_posix()], work, output / "netlist_compilacion.log")
        invoke(bin_dir, "xvlog", ["--sv", "prueba.sv"], work, output / "tb_compilacion.log")
        elaboracion = invoke(bin_dir, "xelab", ["basys3_postimplementacion_tb", "glbl", "-L", "simprims_ver",
                                                "-L", "unisims_ver", "-L", "secureip", "-maxdelay",
                                                "-debug", "typical", "-s", "postimpl"], work, output / "elaboracion.log")
        if "SDF backannotation was successful" not in elaboracion:
            raise RuntimeError("No se confirmó la aplicación de retardos SDF")
        # Registrar puertos externos evita almacenar todos los nodos del
        # netlist de puertas durante la espera de arranque del firmware.
        (work / "simular.tcl").write_text(
            "log_wave /basys3_postimplementacion_tb/clk "
            "/basys3_postimplementacion_tb/sw /basys3_postimplementacion_tb/rx "
            "/basys3_postimplementacion_tb/tx /basys3_postimplementacion_tb/led "
            "/basys3_postimplementacion_tb/hs /basys3_postimplementacion_tb/vs\n"
            "for {set tramo 1} {$tramo <= 300} {incr tramo} {\n"
            "    run 100 us\n"
            "    puts \"POSTIMPLEMENTACION: tramo $tramo de 100 us\"\n"
            "    flush stdout\n"
            "    if {[get_value /basys3_postimplementacion_tb/prueba_terminada] eq \"1\"} {break}\n"
            "}\nquit\n", encoding="utf-8")
        log = invoke(bin_dir, "xsim", ["postimpl", "-tclbatch", "simular.tcl"],
                     work, output / "simulacion.log")
        match = re.search(r"PASS basys3_postimplementacion_tb: (\d+) comprobaciones", log)
        if not match or re.search(r"Fatal:|Timing Violation|Timing violation", log):
            raise RuntimeError("La prueba no aprobó o registró una infracción temporal")
        result = {
            "resultado": "PASS", "testbench": "basys3_postimplementacion_tb",
            "comprobaciones": int(match[1]), "process_corner": "slow", "retardos": "max",
            "proyecto": str(project), "trabajo": str(work),
            "alcance": ["arranque", "identificador de barco invalido", "disparo en fase incorrecta"],
            "sha256": {name: hashlib.sha256((work / name).read_bytes()).hexdigest()
                       for name in ("circuito.v", "circuito.sdf", "prueba.sv")},
        }
        (output / "resultado.json").write_text(json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
        print(f"PASS postimplementacion: {match[1]} comprobaciones. Reportes: {output}")
        print(f"Ondas y netlist: {work}")
        return 0
    except (RuntimeError, ValueError, OSError) as exc:
        parser.exit(1, f"ERROR: {exc}\nResultados: {output}\nTrabajo: {work}\n")


if __name__ == "__main__":
    raise SystemExit(main())
