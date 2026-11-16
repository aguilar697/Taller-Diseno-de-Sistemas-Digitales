"""Compila PR con BSP local 9.5 y linker validado, sin editar fuentes ajenas.

Vitis 2026.1: vitis -s build_pr_exploratory.py <xsa> <workspace_externo_nuevo>
Solo compilacion/enlazado: no demuestra ejecucion ni cierre del lazo de control.
"""
import argparse
import os
import hashlib
import json
import re
import sys
from pathlib import Path

sys.dont_write_bytecode = True
from check_elf import inspect_elf
from check_interrupt_abi import inspect_interrupt_abi
from prepare_local_bsp import prepare_local_bsp, digest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("xsa", type=Path)
    parser.add_argument("workspace", type=Path)
    parser.add_argument("--vitis-root", type=Path, default=os.environ.get("XILINX_VITIS"))
    args = parser.parse_args()
    root = Path(__file__).resolve().parents[2]
    workspace = args.workspace.resolve()
    if workspace == root.parent or root.parent in workspace.parents:
        raise ValueError("El workspace debe estar fuera del repositorio")
    if workspace.exists() or not args.xsa.is_file():
        raise ValueError("Se requiere XSA existente y workspace nuevo")
    if args.vitis_root is None:
        raise ValueError("Defina XILINX_VITIS o --vitis-root para Vitis 2026.1")
    vitis_root = Path(args.vitis_root).resolve()
    local_repo = workspace / "local_bsp_repo"
    import vitis
    client = vitis.create_client()
    try:
        client.set_workspace(path=str(workspace))
        backport = prepare_local_bsp(vitis_root / "data/embeddedsw/lib/bsp/standalone_v9_5", local_repo)
        client.set_embedded_sw_repo(level="LOCAL", path=str(local_repo))
        print("PROCESSOR_OS_LIST:", client.get_processor_os_list(xsa=str(args.xsa.resolve())), flush=True)
        platform = client.create_platform_component(
            name="mbv_platform", hw_design=str(args.xsa.resolve()), cpu="mbv",
            os="standalone", domain_name="standalone_mbv", compiler="gcc", generate_dtb=False)
        result = platform.build()
        print("PLATFORM_BUILD:", result, flush=True)
        if result != 0:
            raise RuntimeError("No se construyo la plataforma/BSP")
        generated = workspace / "mbv_platform/mbv/standalone_mbv/bsp/libsrc/standalone/src/riscv/trap_handler.S"
        if digest(generated) != backport["patched_sha256"]:
            raise RuntimeError("Vitis no selecciono el manejador del BSP local")
        headers = list((workspace / "mbv_platform").glob("**/bsp/include/xparameters.h"))
        if not headers:
            raise RuntimeError("Falta xparameters.h generado")
        header = headers[0].read_text(encoding="utf-8")
        bindings = {}
        for public, generated in {
            "GPIO_ENTRADAS_BASE": "XPAR_GPIO_INPUTS_BASEADDR",
            "GPIO_SALIDAS_BASE": "XPAR_GPIO_OUTPUTS_BASEADDR",
            "UART_BASE": "XPAR_UART_BASEADDR",
            "TIMER_BASE": "XPAR_TIMER_BASEADDR",
            "ADC_BASE": "XPAR_ADC_SYSTEM_AXI_0_BASEADDR",
            "PWM_BASE": "XPAR_PWM_SYSTEM_AXI_0_BASEADDR",
        }.items():
            match = re.search(r"^#define\s+" + generated + r"\s+(0x[0-9a-fA-F]+|[0-9]+)\b", header, re.M)
            if not match:
                raise RuntimeError(f"Macro no exportada por el hardware: {generated}")
            bindings[public] = int(match[1], 0)
        if not re.search(r"^#define\s+XPAR_FABRIC_TIMER_INTR\s+0\b", header, re.M):
            raise RuntimeError("El ID Timer ya no coincide con la entrada 0 usada por plataforma.c")
        for public, instance, expected in (
            ("PWM_BASE", "PWM_SYSTEM_AXI_0", 0x44000000),
            ("ADC_BASE", "ADC_SYSTEM_AXI_0", 0x44A00000),
        ):
            high = re.search(r"^#define\s+XPAR_" + instance +
                             r"_HIGHADDR\s+(0x[0-9a-fA-F]+|[0-9]+)\b", header, re.M)
            if bindings[public] != expected or not high or int(high[1], 0) != expected + 0xFFF:
                raise RuntimeError(f"Ventana AXI distinta de la validada: {instance}")
        xpfm = workspace / "mbv_platform/export/mbv_platform/mbv_platform.xpfm"
        app = client.create_app_component(name="pr_exploratory", platform=str(xpfm),
                                          domain="standalone_mbv", template="empty_application")
        embedded = root / "software/embedded"
        hashes = {}
        compile_sources = []
        for relative in ("control", "drivers", "drivers/adc", "drivers/pwm", "drivers/plataforma", "uart"):
            folder = embedded / relative
            names = sorted(p.name for p in folder.iterdir() if p.suffix in (".c", ".h"))
            app.import_files(from_loc=str(folder), files=names, dest_dir_in_cmp="src/" + relative)
            for name in names:
                file = folder / name
                hashes[str(file.relative_to(root))] = hashlib.sha256(file.read_bytes()).hexdigest()
                if file.suffix == ".c":
                    compile_sources.append(relative + "/" + name)
        app.import_files(from_loc=str(embedded), files=["main.c"], dest_dir_in_cmp="src")
        hashes["software/embedded/main.c"] = hashlib.sha256((embedded / "main.c").read_bytes()).hexdigest()
        # Solo configuracion de NUESTRA copia de construccion: no tocar C/H ajenos.
        src = workspace / "pr_exploratory/src"
        for relative, source_hash in hashes.items():
            imported = src / Path(relative).relative_to("software/embedded")
            if hashlib.sha256(imported.read_bytes()).hexdigest() != source_hash:
                raise RuntimeError(f"La copia no coincide con su fuente: {relative}")
        template = embedded / "diagnostic"
        linker = Path(__file__).with_name("pr_lscript.ld")
        (src / "lscript.ld").write_bytes(linker.read_bytes())
        config = (template / "UserConfig.cmake").read_text(encoding="utf-8")
        includes = "\n".join('"${CMAKE_SOURCE_DIR}/' + p + '"' for p in
                             ("control", "drivers", "drivers/adc", "drivers/pwm", "drivers/plataforma", "uart"))
        config = config.replace("set(USER_INCLUDE_DIRECTORIES\n)", "set(USER_INCLUDE_DIRECTORIES\n" + includes + "\n)")
        config = config.replace("set(USER_COMPILE_SOURCES\n)", "set(USER_COMPILE_SOURCES\n" +
                                "\n".join('"${CMAKE_SOURCE_DIR}/' + p + '"' for p in compile_sources) + "\n)")
        definitions = ["PLATAFORMA_CON_INTC=1"] + [f"{key}=0x{value:08X}u" for key, value in bindings.items()]
        if not re.search(r"#define\s+REGISTRO_N_BUF\s+1024u\b", (src / "control/registro.h").read_text()):
            raise RuntimeError("Cambio el buffer de 1024 muestras")
        config = config.replace('set(USER_COMPILE_DEFINITIONS\n""\n)',
                                "set(USER_COMPILE_DEFINITIONS\n" + "\n".join(definitions) + "\n)")
        config = config.replace("set(USER_COMPILE_OPTIMIZATION_LEVEL -O0)",
                                "set(USER_COMPILE_OPTIMIZATION_LEVEL -Os)")
        config = config.replace('set(USER_COMPILE_GARBAGE "")',
                                'set(USER_COMPILE_GARBAGE "YES")')
        config = config.replace("--cref,--print-memory-usage", "--cref,--print-memory-usage,--gc-sections")
        (src / "UserConfig.cmake").write_text(config, encoding="utf-8")
        if len(compile_sources) + 1 != 18:
            raise RuntimeError("Cambio el conjunto de 18 fuentes PR; revisar antes de continuar")
        manifest = {"bindings": bindings, "source_sha256": hashes,
                    "pwm_present": True, "optimization": "-Os", "execution": "NO_REALIZADA",
                    "linker_sha256": digest(linker), "backport": backport}
        (workspace / "pr_build_inputs.json").write_text(json.dumps(manifest, indent=2), encoding="utf-8")
        result = app.build()
        print("PR_APP_BUILD:", result, flush=True)
        if result != 0:
            raise RuntimeError("Fallo compilacion/enlazado PR: conservar logs; no modificar fuentes ajenas")
        build = workspace / "pr_exploratory/build"
        cache = (build / "CMakeCache.txt").read_text(encoding="utf-8")
        for flag in ("-march=rv32imf_zicsr_zifencei_zicbom", "-mabi=ilp32f"):
            if flag not in cache:
                raise ValueError(f"Opcion de arquitectura ausente: {flag}")
        report = inspect_elf(build / "pr_exploratory.elf")
        abi, assembly = inspect_interrupt_abi(build / "pr_exploratory.elf", vitis_root / "gnu/riscv/nt/bin")
        (workspace / "interrupt_abi.json").write_text(json.dumps(abi, indent=2), encoding="utf-8")
        (workspace / "pr_disassembly.txt").write_text(assembly, encoding="utf-8")
        # Verificar la configuracion efectiva, no solo el retorno del lanzador.
        effective = cache + "\n" + "\n".join(p.read_text(errors="replace") for pattern in
                    ("flags.make", "build.ninja", "compile_commands.json") for p in build.rglob(pattern))
        for flag in ("-Os", "-ffunction-sections", "-fdata-sections"):
            if flag not in effective:
                raise RuntimeError(f"No se verifica la opcion de compilacion {flag}")
        for relative, expected in hashes.items():
            if digest(root / relative) != expected or digest(src / Path(relative).relative_to("software/embedded")) != expected:
                raise RuntimeError(f"Fuente original/importada modificada: {relative}")
        (workspace / "pr_elf_validation.json").write_text(json.dumps(report, indent=2), encoding="utf-8")
        print(json.dumps(report, indent=2), flush=True)
        print("PWM y ADC presentes; compilacion no valida interrupciones, sincronizacion ni lazo en hardware.", flush=True)
    finally:
        vitis.dispose()


if __name__ == "__main__":
    main()
