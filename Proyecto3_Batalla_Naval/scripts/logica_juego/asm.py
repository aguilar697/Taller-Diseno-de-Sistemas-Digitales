"""Ensamblador RV32I para el subconjunto soportado por el CPU del equipo.

Genera program.hex (una palabra hexadecimal de 8 digitos por linea, 2048
lineas, relleno con 00000013 = NOP), tal como lo espera la ROM.

Solo acepta las instrucciones acordadas con la Persona 1. Cualquier otra se
rechaza con error, para garantizar que el programa nunca use algo que el CPU
no implementa. Las pseudoinstrucciones se permiten unicamente si se expanden
a instrucciones de esa lista.

Estrategia: se resuelven direcciones por pasadas iterativas hasta punto fijo,
porque 'li' ocupa una o dos palabras segun el valor del simbolo, que puede
definirse mas adelante en el archivo.
"""

import re
import sys

# Instrucciones que el CPU implementa. Nada fuera de esta lista es valido.
SOPORTADAS = {
    "lw", "sw",
    "sll", "slli", "srl", "srli", "sra", "srai",
    "add", "sub", "and", "xor", "or",
    "addi", "andi", "xori", "ori",
    "beq", "bne", "blt", "bge",
    "slt", "slti", "sltu", "sltiu",
    "jal", "jalr", "lui", "auipc",
}

REGISTROS = {"x%d" % i: i for i in range(32)}
REGISTROS.update({
    "zero": 0, "ra": 1, "sp": 2, "gp": 3, "tp": 4,
    "t0": 5, "t1": 6, "t2": 7,
    "s0": 8, "fp": 8, "s1": 9,
    "a0": 10, "a1": 11, "a2": 12, "a3": 13,
    "a4": 14, "a5": 15, "a6": 16, "a7": 17,
    "s2": 18, "s3": 19, "s4": 20, "s5": 21, "s6": 22,
    "s7": 23, "s8": 24, "s9": 25, "s10": 26, "s11": 27,
    "t3": 28, "t4": 29, "t5": 30, "t6": 31,
})

R_TIPO = {
    "add":  (0b0000000, 0b000), "sub":  (0b0100000, 0b000),
    "sll":  (0b0000000, 0b001), "slt":  (0b0000000, 0b010),
    "sltu": (0b0000000, 0b011), "xor":  (0b0000000, 0b100),
    "srl":  (0b0000000, 0b101), "sra":  (0b0100000, 0b101),
    "or":   (0b0000000, 0b110), "and":  (0b0000000, 0b111),
}
I_TIPO = {"addi": 0b000, "slti": 0b010, "sltiu": 0b011,
          "xori": 0b100, "ori": 0b110, "andi": 0b111}
SHIFT_I = {"slli": (0b0000000, 0b001), "srli": (0b0000000, 0b101),
           "srai": (0b0100000, 0b101)}
B_TIPO = {"beq": 0b000, "bne": 0b001, "blt": 0b100, "bge": 0b101}

ROM_PALABRAS = 2048
NOP = 0x00000013


class ErrorEnsamblador(Exception):
    pass


def _reg(texto, ctx):
    nombre = texto.strip().lower()
    if nombre not in REGISTROS:
        raise ErrorEnsamblador("%s: registro invalido '%s'" % (ctx, texto))
    return REGISTROS[nombre]


def _cabe_con_signo(valor, bits):
    limite = 1 << (bits - 1)
    return -limite <= valor < limite


def _campo(valor, alto, bajo):
    return (valor >> bajo) & ((1 << (alto - bajo + 1)) - 1)


def _sig12(valor):
    valor &= 0xFFF
    return valor - 0x1000 if valor & 0x800 else valor


def partir_mem(operando, ctx):
    """Separa 'imm(rs1)' en (texto_imm, indice_registro)."""
    m = re.match(r"^\s*(.*?)\s*\(\s*([A-Za-z0-9]+)\s*\)\s*$", operando)
    if not m:
        raise ErrorEnsamblador("%s: se esperaba imm(reg), se recibio '%s'" % (ctx, operando))
    return (m.group(1) or "0"), _reg(m.group(2), ctx)


# ----------------------------------------------------------------------
# Codificadores por formato
# ----------------------------------------------------------------------
def cod_r(nombre, rd, rs1, rs2):
    f7, f3 = R_TIPO[nombre]
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0b0110011


def cod_i(f3, opcode, rd, rs1, imm):
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | opcode


def cod_shift(nombre, rd, rs1, shamt):
    f7, f3 = SHIFT_I[nombre]
    return (f7 << 25) | ((shamt & 0x1F) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | 0b0010011


def cod_s(f3, opcode, rs1, rs2, imm):
    return (_campo(imm, 11, 5) << 25) | (rs2 << 20) | (rs1 << 15) | \
           (f3 << 12) | (_campo(imm, 4, 0) << 7) | opcode


def cod_b(nombre, rs1, rs2, imm):
    f3 = B_TIPO[nombre]
    return (_campo(imm, 12, 12) << 31) | (_campo(imm, 10, 5) << 25) | \
           (rs2 << 20) | (rs1 << 15) | (f3 << 12) | \
           (_campo(imm, 4, 1) << 8) | (_campo(imm, 11, 11) << 7) | 0b1100011


def cod_u(opcode, rd, imm):
    return ((imm & 0xFFFFF) << 12) | (rd << 7) | opcode


def cod_j(rd, imm):
    return (_campo(imm, 20, 20) << 31) | (_campo(imm, 10, 1) << 21) | \
           (_campo(imm, 11, 11) << 20) | (_campo(imm, 19, 12) << 12) | \
           (rd << 7) | 0b1101111


# ----------------------------------------------------------------------
class Item:
    """Una instruccion real ya expandida, pendiente de ubicar y codificar."""
    __slots__ = ("mnem", "ops", "ctx", "pc", "palabras")

    def __init__(self, mnem, ops, ctx):
        self.mnem = mnem
        self.ops = ops
        self.ctx = ctx
        self.pc = 0
        self.palabras = 1   # estimacion inicial


class Ensamblador:
    def __init__(self):
        self.equs = {}        # definidos con .equ (constantes puras)
        self.etiquetas = {}   # etiqueta -> direccion
        self.items = []
        self.marcas = []      # (indice_item, nombre_etiqueta)
        self.listado = []

    # ------------------------------------------------------------------
    def expandir(self, mnem, ops, ctx):
        """Pseudoinstrucciones -> instrucciones reales soportadas."""
        tabla_simple = {
            "nop":  lambda o: [("addi", ["x0", "x0", "0"])],
            "mv":   lambda o: [("addi", [o[0], o[1], "0"])],
            "not":  lambda o: [("xori", [o[0], o[1], "-1"])],
            "neg":  lambda o: [("sub",  [o[0], "x0", o[1]])],
            "seqz": lambda o: [("sltiu", [o[0], o[1], "1"])],
            "snez": lambda o: [("sltu", [o[0], "x0", o[1]])],
            "j":    lambda o: [("jal",  ["x0", o[0]])],
            "jr":   lambda o: [("jalr", ["x0", o[0], "0"])],
            "ret":  lambda o: [("jalr", ["x0", "ra", "0"])],
            "call": lambda o: [("jal",  ["ra", o[0]])],
            "beqz": lambda o: [("beq",  [o[0], "x0", o[1]])],
            "bnez": lambda o: [("bne",  [o[0], "x0", o[1]])],
            "bltz": lambda o: [("blt",  [o[0], "x0", o[1]])],
            "bgtz": lambda o: [("blt",  ["x0", o[0], o[1]])],
            "bgez": lambda o: [("bge",  [o[0], "x0", o[1]])],
            "blez": lambda o: [("bge",  ["x0", o[0], o[1]])],
            "bgt":  lambda o: [("blt",  [o[1], o[0], o[2]])],
            "ble":  lambda o: [("bge",  [o[1], o[0], o[2]])],
        }
        if mnem in tabla_simple:
            return tabla_simple[mnem](ops)
        if mnem in ("li", "la"):
            return [("li", ops)]
        if mnem not in SOPORTADAS:
            raise ErrorEnsamblador(
                "%s: instruccion '%s' no soportada por el CPU" % (ctx, mnem))
        return [(mnem, ops)]

    # ------------------------------------------------------------------
    def analizar(self, fuentes):
        """Convierte el texto en items y registra donde cae cada etiqueta."""
        for archivo, texto in fuentes:
            for nlinea, cruda in enumerate(texto.splitlines(), start=1):
                ctx = "%s:%d" % (archivo, nlinea)
                linea = cruda.split("#")[0].strip()
                if not linea:
                    continue

                while True:
                    m = re.match(r"^([A-Za-z_.][A-Za-z0-9_.]*)\s*:\s*(.*)$", linea)
                    if not m:
                        break
                    nombre = m.group(1)
                    if nombre in self.etiquetas or nombre in self.equs:
                        raise ErrorEnsamblador("%s: simbolo duplicado '%s'" % (ctx, nombre))
                    self.etiquetas[nombre] = 0
                    self.marcas.append((len(self.items), nombre))
                    linea = m.group(2).strip()
                if not linea:
                    continue

                m = re.match(r"^\.equ\s+([A-Za-z_][A-Za-z0-9_]*)\s*,\s*(.+)$", linea, re.I)
                if m:
                    nombre = m.group(1)
                    if nombre in self.equs or nombre in self.etiquetas:
                        raise ErrorEnsamblador("%s: simbolo duplicado '%s'" % (ctx, nombre))
                    self.equs[nombre] = self.evaluar(m.group(2), ctx)
                    continue

                partes = linea.split(None, 1)
                mnem = partes[0].lower()
                resto = partes[1] if len(partes) > 1 else ""
                ops = [o.strip() for o in resto.split(",")] if resto.strip() else []
                for real_mnem, real_ops in self.expandir(mnem, ops, ctx):
                    self.items.append(Item(real_mnem, real_ops, ctx))

    # ------------------------------------------------------------------
    def simbolos(self):
        tabla = dict(self.equs)
        tabla.update(self.etiquetas)
        return tabla

    def evaluar(self, texto, ctx):
        texto = texto.strip()
        if not texto:
            raise ErrorEnsamblador("%s: expresion vacia" % ctx)
        tabla = self.simbolos()

        # Literales de caracter: 'A' -> 65. Permite construir texto para la
        # VGA sin tablas en ROM (la ROM no es legible por el bus de datos).
        def caracter(m):
            return str(ord(m.group(1)))
        texto = re.sub(r"'(.)'", caracter, texto)

        def sustituir(m):
            nombre = m.group(0)
            if nombre in tabla:
                return "(%d)" % tabla[nombre]
            raise ErrorEnsamblador("%s: simbolo desconocido '%s'" % (ctx, nombre))

        # El lookbehind evita tocar la 'x' de un literal como 0x1234.
        expr = re.sub(r"(?<![0-9A-Za-z_.])[A-Za-z_][A-Za-z0-9_.]*", sustituir, texto)
        try:
            valor = eval(expr, {"__builtins__": {}}, {})
        except ErrorEnsamblador:
            raise
        except Exception as e:
            raise ErrorEnsamblador("%s: no se pudo evaluar '%s' (%s)" % (ctx, texto, e))
        if not isinstance(valor, int):
            raise ErrorEnsamblador("%s: '%s' no es un entero" % (ctx, texto))
        return valor

    # ------------------------------------------------------------------
    def ubicar(self):
        """Asigna PC a cada item y actualiza etiquetas. Devuelve True si cambio."""
        cambio = False
        pc = 0
        marcas_por_item = {}
        for indice, nombre in self.marcas:
            marcas_por_item.setdefault(indice, []).append(nombre)

        for i, item in enumerate(self.items):
            for nombre in marcas_por_item.get(i, []):
                if self.etiquetas[nombre] != pc:
                    self.etiquetas[nombre] = pc
                    cambio = True
            item.pc = pc
            pc += 4 * item.palabras
        # Etiquetas al final del programa.
        for nombre in marcas_por_item.get(len(self.items), []):
            if self.etiquetas[nombre] != pc:
                self.etiquetas[nombre] = pc
                cambio = True
        self.fin = pc
        return cambio

    def ajustar_tamanos(self):
        """Recalcula cuantas palabras ocupa cada 'li'. True si algo cambio."""
        cambio = False
        for item in self.items:
            if item.mnem != "li":
                continue
            try:
                valor = self.evaluar(item.ops[1], item.ctx)
                nuevo = 1 if _cabe_con_signo(valor, 12) else 2
            except ErrorEnsamblador:
                nuevo = 2   # aun no se conoce: se asume el caso grande
            if nuevo != item.palabras:
                item.palabras = nuevo
                cambio = True
        return cambio

    def resolver(self):
        for _ in range(10):
            self.ubicar()
            if not self.ajustar_tamanos():
                self.ubicar()
                return
        raise ErrorEnsamblador("no se estabilizaron los tamanos de instruccion")

    # ------------------------------------------------------------------
    def codificar_todo(self):
        salida = []
        for item in self.items:
            if item.mnem == "li":
                rd = _reg(item.ops[0], item.ctx)
                valor = self.evaluar(item.ops[1], item.ctx)
                if item.palabras == 1:
                    if not _cabe_con_signo(valor, 12):
                        raise ErrorEnsamblador("%s: li %d no cabe en una palabra" % (item.ctx, valor))
                    salida.append((item.pc, cod_i(0b000, 0b0010011, rd, 0, valor),
                                   item.ctx, "li %s, %d" % (item.ops[0], valor)))
                else:
                    bajo = _sig12(valor)
                    alto = (valor - bajo) >> 12
                    salida.append((item.pc, cod_u(0b0110111, rd, alto), item.ctx,
                                   "lui %s, 0x%05X" % (item.ops[0], alto & 0xFFFFF)))
                    salida.append((item.pc + 4, cod_i(0b000, 0b0010011, rd, rd, bajo),
                                   item.ctx, "addi %s, %s, %d" % (item.ops[0], item.ops[0], bajo)))
                continue
            salida.append((item.pc, self.codificar(item), item.ctx,
                           "%s %s" % (item.mnem, ", ".join(item.ops))))
        self.listado = salida
        return salida

    def codificar(self, item):
        mnem, ops, ctx, pc = item.mnem, item.ops, item.ctx, item.pc

        if mnem in R_TIPO:
            return cod_r(mnem, _reg(ops[0], ctx), _reg(ops[1], ctx), _reg(ops[2], ctx))

        if mnem in I_TIPO:
            imm = self.evaluar(ops[2], ctx)
            if not _cabe_con_signo(imm, 12):
                raise ErrorEnsamblador("%s: inmediato %d no cabe en 12 bits" % (ctx, imm))
            return cod_i(I_TIPO[mnem], 0b0010011, _reg(ops[0], ctx), _reg(ops[1], ctx), imm)

        if mnem in SHIFT_I:
            shamt = self.evaluar(ops[2], ctx)
            if not 0 <= shamt <= 31:
                raise ErrorEnsamblador("%s: desplazamiento %d fuera de 0..31" % (ctx, shamt))
            return cod_shift(mnem, _reg(ops[0], ctx), _reg(ops[1], ctx), shamt)

        if mnem == "lw":
            imm_txt, rs1 = partir_mem(ops[1], ctx)
            imm = self.evaluar(imm_txt, ctx)
            if not _cabe_con_signo(imm, 12):
                raise ErrorEnsamblador("%s: desplazamiento %d de lw no cabe en 12 bits" % (ctx, imm))
            return cod_i(0b010, 0b0000011, _reg(ops[0], ctx), rs1, imm)

        if mnem == "sw":
            imm_txt, rs1 = partir_mem(ops[1], ctx)
            imm = self.evaluar(imm_txt, ctx)
            if not _cabe_con_signo(imm, 12):
                raise ErrorEnsamblador("%s: desplazamiento %d de sw no cabe en 12 bits" % (ctx, imm))
            return cod_s(0b010, 0b0100011, rs1, _reg(ops[0], ctx), imm)

        if mnem in B_TIPO:
            destino = self.evaluar(ops[2], ctx)
            desp = destino - pc
            if desp % 4 != 0:
                raise ErrorEnsamblador("%s: destino de bifurcacion desalineado" % ctx)
            if not _cabe_con_signo(desp, 13):
                raise ErrorEnsamblador(
                    "%s: bifurcacion de %d bytes fuera de alcance (max +-4 KiB)" % (ctx, desp))
            return cod_b(mnem, _reg(ops[0], ctx), _reg(ops[1], ctx), desp)

        if mnem == "jal":
            rd, destino_txt = (1, ops[0]) if len(ops) == 1 else (_reg(ops[0], ctx), ops[1])
            desp = self.evaluar(destino_txt, ctx) - pc
            if not _cabe_con_signo(desp, 21):
                raise ErrorEnsamblador("%s: jal fuera de alcance (%d bytes)" % (ctx, desp))
            return cod_j(rd, desp)

        if mnem == "jalr":
            if len(ops) == 1:
                return cod_i(0b000, 0b1100111, 1, _reg(ops[0], ctx), 0)
            if len(ops) == 2 and "(" in ops[1]:
                imm_txt, rs1 = partir_mem(ops[1], ctx)
                return cod_i(0b000, 0b1100111, _reg(ops[0], ctx), rs1, self.evaluar(imm_txt, ctx))
            if len(ops) == 2:
                return cod_i(0b000, 0b1100111, _reg(ops[0], ctx), _reg(ops[1], ctx), 0)
            imm = self.evaluar(ops[2], ctx)
            if not _cabe_con_signo(imm, 12):
                raise ErrorEnsamblador("%s: inmediato de jalr no cabe en 12 bits" % ctx)
            return cod_i(0b000, 0b1100111, _reg(ops[0], ctx), _reg(ops[1], ctx), imm)

        if mnem in ("lui", "auipc"):
            valor = self.evaluar(ops[1], ctx)
            if not 0 <= (valor & 0xFFFFF) <= 0xFFFFF:
                raise ErrorEnsamblador("%s: inmediato U invalido" % ctx)
            return cod_u(0b0110111 if mnem == "lui" else 0b0010111, _reg(ops[0], ctx), valor)

        raise ErrorEnsamblador("%s: instruccion '%s' no soportada" % (ctx, mnem))


# ----------------------------------------------------------------------
def ensamblar(rutas):
    fuentes = []
    for ruta in rutas:
        with open(ruta, "r", encoding="utf-8") as f:
            nombre = ruta.replace("\\", "/").split("/")[-1]
            fuentes.append((nombre, f.read()))

    asm = Ensamblador()
    asm.analizar(fuentes)
    asm.resolver()
    palabras = asm.codificar_todo()

    imagen = [NOP] * ROM_PALABRAS
    for pc, palabra, ctx, _txt in palabras:
        indice = pc // 4
        if indice >= ROM_PALABRAS:
            raise ErrorEnsamblador("el programa excede las %d palabras de ROM (%s)"
                                   % (ROM_PALABRAS, ctx))
        imagen[indice] = palabra & 0xFFFFFFFF
    return imagen, asm


def escribir_hex(imagen, ruta):
    with open(ruta, "w", encoding="utf-8") as f:
        for palabra in imagen:
            f.write("%08X\n" % palabra)


def escribir_listado(asm, ruta):
    with open(ruta, "w", encoding="utf-8") as f:
        f.write("# PC        PALABRA   INSTRUCCION                        ORIGEN\n")
        for pc, palabra, ctx, texto in asm.listado:
            f.write("%08X  %08X  %-34s %s\n" % (pc, palabra & 0xFFFFFFFF, texto, ctx))
        f.write("\n# Simbolos\n")
        for nombre, valor in sorted(asm.simbolos().items()):
            f.write("# %-28s 0x%08X  (%d)\n" % (nombre, valor & 0xFFFFFFFF, valor))


def main(argv):
    if len(argv) < 3:
        print("uso: asm.py salida.hex fuente1.s [fuente2.s ...]")
        return 2
    salida, fuentes = argv[1], argv[2:]
    try:
        imagen, asm = ensamblar(fuentes)
    except ErrorEnsamblador as e:
        print("ERROR: %s" % e)
        return 1
    escribir_hex(imagen, salida)
    escribir_listado(asm, salida.rsplit(".", 1)[0] + ".lst")
    usadas = len(asm.listado)
    print("OK: %d instrucciones, %d/%d palabras de ROM (%.1f%%)"
          % (usadas, usadas, ROM_PALABRAS, 100.0 * usadas / ROM_PALABRAS))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
