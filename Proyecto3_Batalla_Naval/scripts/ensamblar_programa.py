"""Genera la ROM del juego con el subconjunto RV32I implementado por el CPU."""

import argparse
import ast
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = ["constantes.s", "main.s", "control_estado.s", "colocacion.s",
           "turnos.s", "victoria.s", "uart.s", "salidas.s"]
ROM_WORDS = 2048
ABI = "zero ra sp gp tp t0 t1 t2 s0 s1 a0 a1 a2 a3 a4 a5 a6 a7 s2 s3 s4 s5 s6 s7 s8 s9 s10 s11 t3 t4 t5 t6".split()
REGISTERS = {name: index for index, name in enumerate(ABI)}
REGISTERS.update({f"x{index}": index for index in range(32)})
REGISTERS["fp"] = 8
R_OPS = {"add": (0, 0), "sub": (0, 32), "sll": (1, 0), "slt": (2, 0),
         "sltu": (3, 0), "xor": (4, 0), "srl": (5, 0), "sra": (5, 32),
         "or": (6, 0), "and": (7, 0)}
I_OPS = {"addi": 0, "slti": 2, "sltiu": 3, "xori": 4, "ori": 6, "andi": 7}
# El decodificador implementa estos cuatro saltos del subconjunto RV32I.
BRANCHES = {"beq": 0, "bne": 1, "blt": 4, "bge": 5}


def expression(text, symbols):
    """Evalúa únicamente enteros, caracteres, símbolos y operadores constantes."""
    def evaluate(node):
        if isinstance(node, ast.Constant):
            if type(node.value) is int:
                return node.value
            if isinstance(node.value, str) and len(node.value) == 1:
                return ord(node.value)
        if isinstance(node, ast.Name) and node.id in symbols:
            return symbols[node.id]
        if isinstance(node, ast.UnaryOp):
            value = evaluate(node.operand)
            if isinstance(node.op, ast.USub): return -value
            if isinstance(node.op, ast.UAdd): return value
            if isinstance(node.op, ast.Invert): return ~value
        if isinstance(node, ast.BinOp):
            a, b = evaluate(node.left), evaluate(node.right)
            if isinstance(node.op, ast.Add): return a + b
            if isinstance(node.op, ast.Sub): return a - b
            if isinstance(node.op, ast.LShift): return a << b
            if isinstance(node.op, ast.RShift): return a >> b
            if isinstance(node.op, ast.BitOr): return a | b
            if isinstance(node.op, ast.BitAnd): return a & b
            if isinstance(node.op, ast.BitXor): return a ^ b
        raise ValueError(f"Expresión no admitida: {text}")
    return evaluate(ast.parse(text, mode="eval").body)


def signed(value, bits):
    if not -(1 << (bits - 1)) <= value < (1 << (bits - 1)):
        raise ValueError(f"Inmediato {value} fuera del rango de {bits} bits")
    return value & ((1 << bits) - 1)


def li_value(text, symbols):
    value = expression(text, symbols)
    if not -(1 << 31) <= value < (1 << 32):
        raise ValueError("Constante fuera de 32 bits")
    return value if value < (1 << 31) else value - (1 << 32)


def expand(op, args, symbols):
    if op == "li":
        value = li_value(args[1], symbols)
        if -2048 <= value <= 2047:
            return [("addi", [args[0], "zero", str(value)])]
        high = (value + 0x800) >> 12
        return [("lui", [args[0], str(high & 0xFFFFF)]),
                ("addi", [args[0], args[0], str(value - (high << 12))])]
    if op == "mv": return [("addi", [args[0], args[1], "0"])]
    if op == "not": return [("xori", [args[0], args[1], "-1"])]
    if op == "neg": return [("sub", [args[0], "zero", args[1]])]
    if op == "nop": return [("addi", ["zero", "zero", "0"])]
    if op == "ret": return [("jalr", ["zero", "0(ra)"])]
    if op in ("call", "j"):
        return [("jal", ["ra" if op == "call" else "zero", args[0]])]
    if op in ("beqz", "bnez"):
        return [("beq" if op == "beqz" else "bne", [args[0], "zero", args[1]])]
    return [(op, args)]


def encode(op, args, pc, symbols):
    reg = lambda text: REGISTERS[text]
    val = lambda text: expression(text, symbols)
    if op in R_OPS:
        rd, rs1, rs2 = map(reg, args)
        funct3, funct7 = R_OPS[op]
        return funct7 << 25 | rs2 << 20 | rs1 << 15 | funct3 << 12 | rd << 7 | 0x33
    if op in I_OPS or op in ("slli", "srli", "srai"):
        rd, rs1 = map(reg, args[:2])
        if op in I_OPS:
            imm, funct3 = signed(val(args[2]), 12), I_OPS[op]
        else:
            amount = val(args[2])
            if not 0 <= amount < 32: raise ValueError("Desplazamiento fuera de 0..31")
            imm = amount | (0x400 if op == "srai" else 0)
            funct3 = 1 if op == "slli" else 5
        return imm << 20 | rs1 << 15 | funct3 << 12 | rd << 7 | 0x13
    if op in ("lw", "sw", "jalr"):
        offset, base = args[1].rstrip(")").rsplit("(", 1)
        imm, rs1, rd = signed(val(offset), 12), reg(base), reg(args[0])
        if op == "sw":
            return (imm >> 5) << 25 | rd << 20 | rs1 << 15 | 2 << 12 | (imm & 31) << 7 | 0x23
        return imm << 20 | rs1 << 15 | (2 << 12 if op == "lw" else 0) | rd << 7 | (0x03 if op == "lw" else 0x67)
    if op in ("lui", "auipc"):
        imm = val(args[1])
        if not 0 <= imm <= 0xFFFFF: raise ValueError("Inmediato U fuera de 20 bits")
        return imm << 12 | reg(args[0]) << 7 | (0x37 if op == "lui" else 0x17)
    if op in BRANCHES or op == "jal":
        offset = val(args[-1]) - pc
        if offset % 4: raise ValueError("Destino no alineado a 4 bytes")
        imm = signed(offset, 21 if op == "jal" else 13)
        if op == "jal":
            return ((imm >> 20) & 1) << 31 | ((imm >> 1) & 0x3FF) << 21 | ((imm >> 11) & 1) << 20 | ((imm >> 12) & 255) << 12 | reg(args[0]) << 7 | 0x6F
        return ((imm >> 12) & 1) << 31 | ((imm >> 5) & 63) << 25 | reg(args[1]) << 20 | reg(args[0]) << 15 | BRANCHES[op] << 12 | ((imm >> 1) & 15) << 8 | ((imm >> 11) & 1) << 7 | 0x63
    raise ValueError(f"Instrucción no implementada por el CPU: {op}")


def assemble(directory=None):
    directory = directory or ROOT / "src/software_riscv"
    symbols, instructions = {}, []
    for filename in SOURCES:
        for number, raw in enumerate((directory / filename).read_text(encoding="utf-8").splitlines(), 1):
            line = raw.split("#", 1)[0].strip()
            if not line: continue
            location = f"{filename}:{number}"
            try:
                if line.endswith(":"):
                    label = line[:-1]
                    if label in symbols: raise ValueError(f"Símbolo duplicado: {label}")
                    symbols[label] = 4 * len(instructions)
                    continue
                if line.startswith(".equ "):
                    name, value = map(str.strip, line[5:].split(",", 1))
                    if name in symbols: raise ValueError(f"Símbolo duplicado: {name}")
                    symbols[name] = expression(value, symbols)
                    continue
                parts = line.split(None, 1)
                args = [part.strip() for part in parts[1].split(",")] if len(parts) > 1 else []
                instructions.extend((op, operands, location) for op, operands in expand(parts[0], args, symbols))
            except (ValueError, KeyError, SyntaxError, IndexError) as exc:
                raise ValueError(f"{location}: {exc}") from exc
    if len(instructions) > ROM_WORDS:
        raise ValueError(f"El programa excede las {ROM_WORDS} palabras de ROM")
    if symbols.get("inicio") != 0:
        raise ValueError("La etiqueta inicio debe estar en la dirección 0")
    words = []
    for index, (op, args, location) in enumerate(instructions):
        try:
            words.append(encode(op, args, index * 4, symbols))
        except (ValueError, KeyError, IndexError) as exc:
            raise ValueError(f"{location}: {exc}") from exc
    return words + [0x13] * (ROM_WORDS - len(words)), len(words)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Compara con el HEX existente sin escribirlo")
    parser.add_argument("--output", type=Path, default=ROOT / "src/software_riscv/program.hex")
    args = parser.parse_args()
    try:
        words, used = assemble()
        if args.check:
            existing = [int(line, 16) for line in args.output.read_text(encoding="ascii").split()]
            if existing != words:
                raise ValueError("El HEX no corresponde a las fuentes ensamblador")
        else:
            args.output.write_text("".join(f"{word:08X}\n" for word in words), encoding="ascii")
        print(f"ROM verificada: {used}/{ROM_WORDS} palabras utilizadas.")
        return 0
    except (ValueError, OSError) as exc:
        parser.exit(1, f"ERROR: {exc}\n")


if __name__ == "__main__":
    raise SystemExit(main())
