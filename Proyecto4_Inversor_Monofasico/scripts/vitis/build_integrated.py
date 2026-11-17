"""Construye BSP y dos aplicaciones: diagnostico conjunto y controlador PR.

Uso: vitis -s build_integrated.py hardware.xsa workspace_nuevo
No descarga programas a la tarjeta ni calibra el sensor.
"""
import argparse
import json
import os
import shutil
import sys
from pathlib import Path

sys.dont_write_bytecode = True
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
from check_elf import inspect_elf
from check_interrupt_abi import inspect_interrupt_abi
from prepare_local_bsp import prepare_local_bsp, digest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("xsa", type=Path)
    parser.add_argument("workspace", type=Path)
    parser.add_argument("--incluir-laboratorio", action="store_true",
                        help="Incluye el ensayo PR limitado a bus de 3 V")
    parser.add_argument("--vitis-root", type=Path, default=os.environ.get("XILINX_VITIS"))
    args = parser.parse_args()
    if args.vitis_root is None or not args.xsa.is_file():
        raise ValueError("Indique XSA existente y --vitis-root o XILINX_VITIS")
    vitis_root = args.vitis_root.resolve()
    root = Path(__file__).resolve().parents[2]
    workspace = args.workspace.resolve()
    if workspace.exists():
        raise ValueError("Utilice un workspace nuevo")
    if workspace == root.parent or root.parent in workspace.parents:
        raise ValueError("El workspace debe estar fuera de las fuentes")
    dependency = workspace / ("inversor_platform/mbv/standalone_mbv/bsp/libsrc/build_configs/gen_bsp/libsrc/standalone/src/"
                              "CMakeFiles/xilstandalone.dir/riscv/riscv_invalidate_icache_range.S.obj.d")
    if os.name == "nt" and len(str(dependency)) >= 260:
        raise ValueError("La ruta excede el limite del compilador en Windows; utilice un workspace mas corto")
    import vitis
    client = vitis.create_client()
    try:
        client.set_workspace(path=str(workspace))
        backport = prepare_local_bsp(vitis_root / "data/embeddedsw/lib/bsp/standalone_v9_5",
                                     workspace / "local_bsp_repo")
        client.set_embedded_sw_repo(level="LOCAL", path=str(workspace / "local_bsp_repo"))
        platform = client.create_platform_component(name="inversor_platform",
            hw_design=str(args.xsa.resolve()), cpu="mbv", os="standalone",
            domain_name="standalone_mbv", compiler="gcc", generate_dtb=False)
        if platform.build() != 0:
            raise RuntimeError("Fallo la construccion del BSP")
        bsp = workspace / "inversor_platform/mbv/standalone_mbv/bsp"
        if digest(bsp / "libsrc/standalone/src/riscv/trap_handler.S") != backport["patched_sha256"]:
            raise RuntimeError("Vitis no selecciono el BSP local con trap alineado")
        header = (bsp / "include/xparameters.h").read_text(encoding="utf-8")
        for macro, expected in {"PWM_SYSTEM_AXI_0_BASEADDR": "0x44000000",
                                "ADC_SYSTEM_AXI_0_BASEADDR": "0x44a00000"}.items():
            import re
            match = re.search(r"^#define\s+XPAR_" + macro + r"\s+(0x[0-9a-fA-F]+)", header, re.M)
            if not match or int(match[1], 16) != int(expected, 16):
                raise RuntimeError("El XSA no coincide con el mapa: " + macro)
        xpfm = workspace / "inversor_platform/export/inversor_platform/inversor_platform.xpfm"
        emb = root / "software/embedded"
        aplicaciones = [("diagnostico_integrado", emb / "integration/main.c"),
                        ("control_inversor", emb / "main.c")]
        if args.incluir_laboratorio:
            aplicaciones.append(("lazo_laboratorio", emb / "integration/lazo_laboratorio.c"))
        for name, main_source in aplicaciones:
            staging = workspace / (name + "_sources")
            staging.mkdir()
            # Archivos planos: los nombres de los headers de los subsistemas son unicos.
            for folder in ("control", "uart", "drivers"):
                for source in (emb / folder).rglob("*"):
                    if source.suffix in (".c", ".h"):
                        if (staging / source.name).exists():
                            raise ValueError("Nombre de fuente duplicado: " + source.name)
                        shutil.copy2(source, staging / source.name)
            shutil.copy2(main_source, staging / "main.c")
            shutil.copy2(emb / "integration/lscript.ld", staging / "lscript.ld")
            config_text = (emb / "diagnostic/UserConfig.cmake").read_text(encoding="utf-8")
            config_text = config_text.replace("set(USER_COMPILE_OPTIMIZATION_LEVEL -O0)",
                                               "set(USER_COMPILE_OPTIMIZATION_LEVEL -Os)")
            config_text = config_text.replace('set(USER_COMPILE_GARBAGE "")',
                                               'set(USER_COMPILE_GARBAGE "YES")')
            config_text = config_text.replace('set(USER_COMPILE_OTHER_FLAGS )',
                'set(USER_COMPILE_OTHER_FLAGS "-DPLATAFORMA_CON_INTC=1 -DREGISTRO_N_BUF=512u -DK_REG=2u -fstack-usage")')
            config_text = config_text.replace('--cref,--print-memory-usage',
                                               '--cref,--print-memory-usage,--gc-sections')
            (staging / "UserConfig.cmake").write_text(config_text, encoding="utf-8")
            if name == "lazo_laboratorio":
                config = staging / "UserConfig.cmake"
                config.write_text(config.read_text(encoding="utf-8").replace(
                    "-DREGISTRO_N_BUF=512u -DK_REG=2u",
                    "-DREGISTRO_N_BUF=256u -DK_REG=4u"), encoding="utf-8")
            app = client.create_app_component(name=name, platform=str(xpfm),
                domain="standalone_mbv", template="empty_application")
            app.import_files(from_loc=str(staging),
                files=[p.name for p in staging.iterdir()], dest_dir_in_cmp="src")
            if app.build() != 0:
                raise RuntimeError("Fallo la aplicacion " + name)
            elf = workspace / name / "build" / (name + ".elf")
            report = inspect_elf(elf)
            profile = {"control_inversor": "pr", "lazo_laboratorio": "laboratorio",
                       "diagnostico_integrado": "diagnostico"}[name]
            abi, _ = inspect_interrupt_abi(elf, vitis_root / "gnu/riscv/nt/bin",
                                         profile=profile, heap_bytes=0, stack_bytes=2048)
            report["abi"] = abi
            sources = {str(p.relative_to(root)): digest(p) for p in emb.rglob("*")
                       if p.suffix in (".c", ".h", ".ld")}
            manifest = {"hardware_xsa_sha256": digest(args.xsa), "source_sha256": sources,
                        "application": name, "backport": backport,
                        "physical_execution": "PENDIENTE"}
            (workspace / (name + "_inputs.json")).write_text(json.dumps(manifest, indent=2), encoding="utf-8")
            (workspace / (name + "_elf.json")).write_text(json.dumps(report, indent=2), encoding="utf-8")
            print(name, json.dumps(report), flush=True)
        print("CONSTRUCCION_INTEGRADA_PASS: BSP, aplicaciones y auditorias estaticas", flush=True)
    finally:
        vitis.dispose()


if __name__ == "__main__":
    main()
