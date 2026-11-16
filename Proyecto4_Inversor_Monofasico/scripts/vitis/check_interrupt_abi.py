"""Auditoria estatica estricta del trap RV32IMF Standalone 9.5 parcheado.

Requiere objdump/nm/readelf de la misma herramienta. No ejecuta instrucciones
ni demuestra suficiencia dinamica de pila o funcionamiento de interrupciones.
"""
import argparse
import json
import re
import subprocess
from pathlib import Path
from check_elf import inspect_elf


def inspect_interrupt_abi(elf, toolchain):
    def run(tool, *args):
        exe = Path(toolchain) / ("riscv64-unknown-elf-" + tool + ".exe")
        return subprocess.run([str(exe), *args, str(elf)], check=True,
                              capture_output=True, text=True).stdout
    memory = inspect_elf(elf)
    nm = run("nm", "-n")
    symbols = {m[3]: int(m[1], 16) for line in nm.splitlines()
               if (m := re.match(r"([0-9a-f]+)\s+(\w)\s+(\S+)", line))}
    required = ("_trap_handler", "RISCV_ExceptionVectorTable", "RISCV_InterruptVectorTable",
                "Xil_RegMtvecInit", "Xil_ExceptionInit", "Xil_ExceptionRegisterHandler",
                "XIntc_InterruptHandler", "XIntc_DeviceInterruptHandler", "app_isr",
                "pr_calcular", "pr_actualizar", "adc_leer", "pwm_configurar",
                "pwm_escribir_referencia", "gpio_medicion", "uart_escribir", "exportacion_paso")
    missing = [name for name in required if name not in symbols]
    if missing or run("nm", "-u").strip():
        raise ValueError(f"Simbolos funcionales ausentes/indefinidos: {missing}")
    attrs = run("readelf", "-A")
    if 'Tag_RISCV_stack_align: 16-bytes' not in attrs or not re.search(r'rv32i[^"\n]*_m[^"\n]*_f', attrs):
        raise ValueError("Atributos RV32IMF/alineacion no comprobados")
    if symbols["_trap_handler"] % 4 or any(symbols[n] % 4 for n in required[1:3]):
        raise ValueError("Trap o tablas desalineados")
    if symbols["_heap_end"] - symbols["_heap_start"] != 2048 or symbols["_stack"] - symbols["_stack_end"] != 1024:
        raise ValueError("Las reservas de heap/pila cambiaron")
    asm = run("objdump", "-d")
    try:
        handler = asm.split("<_trap_handler>:", 1)[1].split("<handle_load_misalign>:", 1)[0]
    except IndexError as exc:
        raise ValueError("No se reconoce el manejador Standalone 9.5") from exc
    if "sp,sp,-272" not in handler or "sp,sp,272" not in handler or handler.count("jalr") != 1 or "mret" not in handler:
        raise ValueError("Marco o llamada/retorno de trap inesperado")
    steps = [int(n) for n in re.findall(r"\baddi\s+sp,sp,(-?\d+)", handler)]
    if steps != [-272, 272]:
        raise ValueError("No puede probarse alineacion antes de la llamada C")
    if not handler.index("sp,sp,-272") < handler.index("jalr") < handler.index("sp,sp,272"):
        raise ValueError("La llamada C no esta dentro del marco asignado")
    # Rechazar ajustes de SP que este auditor limitado no modela.
    for line in handler.splitlines():
        instruction = re.match(r"\s*[0-9a-f]+:\s+[0-9a-f]+\s+(\w+)\s+sp(?:,|\s|$)", line)
        if instruction and instruction[1] != "addi":
            raise ValueError("Escritura SP no modelada")
    for store, load, count in (("fsw", "flw", 32), ("sw", "lw", 31)):
        saved = re.findall(r"\b" + store + r"\s+(\w+),(\d+)\(sp\)", handler)
        restored = re.findall(r"\b" + load + r"\s+(\w+),(\d+)\(sp\)", handler)
        if len(saved) != count or sorted(saved) != sorted(restored):
            raise ValueError(f"Contexto {store}/{load} no simetrico")
        if store == "fsw" and sorted(int(slot) for _, slot in saved) != list(range(128, 256, 4)):
            raise ValueError("Slots FPU inesperados")
        if store == "fsw" and len({reg for reg, _ in saved}) != 32:
            raise ValueError("Registros FPU duplicados/ausentes")
        if store == "sw" and sorted(int(slot) for _, slot in saved) != [4, *range(12, 128, 4), 256]:
            raise ValueError("Slots enteros/FCSR inesperados")
    if not ("frcsr" in handler and "fscsr" in handler and "256(sp)" in handler):
        raise ValueError("No se demuestra preservacion FCSR")
    runtime = asm.split("Disassembly of section .text:", 1)[1]
    if any(int(n) % 16 for n in re.findall(r"\baddi\s+sp,sp,(-?\d+)", runtime)):
        raise ValueError("Ajuste de pila runtime no alineado")
    return {"status": "ABI_ESTATICA_PASS", "memory": memory,
            "trap_frame_bytes": 272, "fpu_registers_preserved": 32,
            "functional_execution": "NO_REALIZADA", "stack_high_water": "PENDIENTE"}, asm


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("elf", type=Path)
    parser.add_argument("--toolchain", required=True, type=Path)
    args = parser.parse_args()
    report, _ = inspect_interrupt_abi(args.elf, args.toolchain)
    print(json.dumps(report, indent=2))
