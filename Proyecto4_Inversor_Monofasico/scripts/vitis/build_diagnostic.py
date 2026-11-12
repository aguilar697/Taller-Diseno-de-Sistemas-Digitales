"""Vitis 2026.1: vitis -s build_diagnostic.py <hardware.xsa> <workspace_nuevo>.

Genera plataforma/BSP sin parches AMD, compila el diagnostico y comprueba ELF.
Todos los productos deben permanecer fuera del repositorio.
"""
import argparse
import json
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from check_elf import inspect_elf


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("xsa", type=Path)
    parser.add_argument("workspace", type=Path)
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    workspace = args.workspace.resolve()
    if workspace == root.parent or root.parent in workspace.parents:
        raise ValueError("El workspace debe estar fuera del repositorio")
    if workspace.exists():
        raise ValueError("Use un workspace nuevo; no se sobrescriben resultados")
    if not args.xsa.is_file():
        raise FileNotFoundError(args.xsa)
    import vitis
    client = vitis.create_client()
    try:
        client.set_workspace(path=str(workspace))
        platform = client.create_platform_component(
            name="mbv_platform", hw_design=str(args.xsa.resolve()), cpu="mbv",
            os="standalone", domain_name="standalone_mbv", compiler="gcc", generate_dtb=False)
        platform_result = platform.build()
        print("PLATFORM_BUILD:", platform_result, flush=True)
        if platform_result != 0:
            raise RuntimeError(f"Fallo al construir plataforma: {platform_result}")
        xpfm = workspace / "mbv_platform/export/mbv_platform/mbv_platform.xpfm"
        app = client.create_app_component(name="diagnostic", platform=str(xpfm),
                                          domain="standalone_mbv", template="empty_application")
        app.import_files(from_loc=str(root / "software/embedded/diagnostic"),
                         files=["main.c", "lscript.ld", "UserConfig.cmake"], dest_dir_in_cmp="src")
        app_result = app.build()
        print("APP_BUILD:", app_result, flush=True)
        if app_result != 0:
            raise RuntimeError(f"Fallo al construir aplicacion: {app_result}")
        build = workspace / "diagnostic/build"
        cache = (build / "CMakeCache.txt").read_text(encoding="utf-8")
        for flag in ("-march=rv32imf_zicsr_zifencei_zicbom", "-mabi=ilp32f"):
            if flag not in cache:
                raise ValueError(f"Opcion de arquitectura ausente: {flag}")
        report = inspect_elf(build / "diagnostic.elf")
        print(json.dumps(report, indent=2), flush=True)
        # Resultado generado, no fuente: permite conservar el informe fuera de Git.
        (workspace / "elf_validation.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
        print("No se ha descargado ni ejecutado el ELF en hardware.", flush=True)
    finally:
        vitis.dispose()


if __name__ == "__main__":
    main()
