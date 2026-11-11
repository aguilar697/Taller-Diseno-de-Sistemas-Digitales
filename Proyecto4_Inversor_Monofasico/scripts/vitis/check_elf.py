"""Verifica ELF32 RISC-V, ABI float simple y memoria compartida de 32 KiB.

Uso: python -B check_elf.py diagnostic.elf
No ejecuta el programa ni necesita paquetes externos.
"""
import argparse
import json
import struct
from pathlib import Path


def inspect_elf(path):
    data = Path(path).read_bytes()
    if data[:7] != b"\x7fELF\x01\x01\x01":
        raise ValueError("Se requiere ELF32 little-endian")
    header = struct.unpack_from("<16sHHIIIIIHHHHHH", data)
    _, _, machine, _, entry, phoff, shoff, flags, _, phsize, phnum, shsize, shnum, strindex = header
    if machine != 243 or flags & 6 != 2:
        raise ValueError("Se requiere RISC-V con ABI de punto flotante simple")
    if entry != 0 or flags & 1:
        raise ValueError("Arranque esperado en 0, sin extension C/RVC")
    sections = [struct.unpack_from("<IIIIIIIIII", data, shoff + i * shsize) for i in range(shnum)]
    strings = sections[strindex]
    names = data[strings[4]:strings[4] + strings[5]]

    def get_string(table, offset):
        return table[offset:table.index(b"\0", offset)].decode("ascii")

    allocated = []
    for section in sections:
        name = get_string(names, section[0])
        _, _, attr, addr, _, size, _, _, _, _ = section
        if attr & 2 and size:
            if addr + size > 0x8000:
                raise ValueError(f"Seccion fuera de BRAM: {name}")
            allocated.append({"section": name, "address": addr, "bytes": size})
    for i in range(phnum):
        kind, _, vaddr, paddr, filesz, memsz, _, _ = struct.unpack_from("<IIIIIIII", data, phoff + i * phsize)
        if kind == 1 and (filesz > memsz or max(vaddr, paddr) + memsz > 0x8000):
            raise ValueError("Segmento LOAD fuera de BRAM o inconsistente")
    symbols = {}
    for section in sections:
        if section[1] != 2:
            continue
        strtab = sections[section[6]]
        table = data[strtab[4]:strtab[4] + strtab[5]]
        for pos in range(section[4], section[4] + section[5], section[9]):
            name, value, _, _, _, _ = struct.unpack_from("<IIIBBH", data, pos)
            symbols[get_string(table, name)] = value
    for symbol in ("_boot", "_stack", "_stack_end", "_heap_start", "_heap_end", "_end"):
        if symbol not in symbols:
            raise ValueError(f"Simbolo de linker ausente: {symbol}")
    if symbols["_boot"] != entry or symbols["_stack"] % 16:
        raise ValueError("Entrada o alineacion de pila incorrecta")
    if not (symbols["_heap_start"] <= symbols["_heap_end"] <= symbols["_stack_end"] < symbols["_stack"] <= 0x8000):
        raise ValueError("Heap/pila superpuestos o fuera de rango")
    reserved = max([s["address"] + s["bytes"] for s in allocated] + [symbols["_end"]])
    if reserved > 0x8000:
        raise ValueError("Memoria total fuera de 32 KiB")
    return {"entry": entry, "abi": "ilp32f", "reserved_bytes": reserved,
            "free_bytes": 0x8000 - reserved, "sections": allocated,
            "stack_top": symbols["_stack"], "status": "VALIDACION_ESTATICA_PASS"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("elf", type=Path)
    args = parser.parse_args()
    print(json.dumps(inspect_elf(args.elf), indent=2))
