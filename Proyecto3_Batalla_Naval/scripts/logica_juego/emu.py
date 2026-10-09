"""Emulador del sistema Batalla Naval para probar el programa ensamblador.

Modela el CPU RV32I multiciclo de la Persona 1 (solo el subconjunto acordado),
la RAM, la memoria de video y los perifericos, respetando el contrato del bus:

  - Direcciones de datos no mapeadas: lectura cero, escritura ignorada.
  - Leer un periferico no consume ni reconoce eventos; eso requiere escritura.
  - VGA: indices de tile 0-299 visibles, 300-511 reservados.
  - UART: el registro CONTROL es el que implemento el equipo en el RTL real
    (bit 0 = TX lista, bit 1 = byte recibido, escribir el bit 1 lo consume).
    Escribir TX_DATA inicia la transmision solo si la TX esta lista; si no,
    el byte se ignora. Hay un unico byte de recepcion, sin FIFO: un byte que
    llega mientras el anterior no fue consumido lo sobrescribe.

Es una herramienta de prueba de mi subsistema (Persona 4), no forma parte del
hardware entregable: sustituye al CPU y a los perifericos que aun no existen
para poder verificar la logica del juego de forma autoverificable.
"""

ROM_BASE, ROM_FIN = 0x00000000, 0x00001FFF
RAM_BASE, RAM_FIN = 0x00002000, 0x00002FFF
UART_CTRL = 0x00010040
UART_TX = 0x00010044
UART_RX = 0x00010048
INPUTS = 0x00010120
DISPLAY = 0x00010130
LED = 0x00010138
BUZZER = 0x00010140
VGA_BASE, VGA_FIN = 0x00011000, 0x000117FF

TILES_VISIBLES = 300
VGA_PALABRAS = 512

# Ciclos por instruccion del CPU multiciclo (nivel 4 del diseno del equipo):
# 6 en general, 8 las cargas (dos ciclos mas de acceso a datos) y 5 los saltos
# condicionales. Con esto el emulador mide el tiempo en ciclos de reloj.
LATENCIA = {0b0110011: 6, 0b0010011: 6, 0b0110111: 6, 0b0010111: 6,
            0b1101111: 6, 0b1100111: 6, 0b0000011: 8, 0b0100011: 6,
            0b1100011: 5}

# A 115200 baudios y 100 MHz un byte (inicio, 8 datos, parada) dura 8680 ciclos.
CICLOS_BYTE_UART = 8680


class Fallo(Exception):
    """Condicion que detiene el CPU hasta reset (equivale al estado FAULT)."""


def _u32(valor):
    return valor & 0xFFFFFFFF


def _s32(valor):
    valor &= 0xFFFFFFFF
    return valor - 0x100000000 if valor & 0x80000000 else valor


class Sistema:
    """CPU + memorias + perifericos simulados."""

    def __init__(self, imagen_rom, ciclos_tx=40, ciclos_rx=CICLOS_BYTE_UART):
        self.rom = list(imagen_rom) + [0x00000013] * (2048 - len(imagen_rom))
        self.ram = [0] * 1024              # 0x2000-0x2FFF
        self.vga = [0] * VGA_PALABRAS
        self.reg = [0] * 32
        self.pc = 0
        self.detenido = False
        self.motivo = None
        self.instrucciones = 0
        self.ciclos = 0                    # ciclos de reloj del CPU
        self.escrituras = 0

        # Perifericos
        self.inputs = 0
        self.display = 0
        self.led = 0
        self.buzzer = 0
        self.ordenes_buzzer = []           # historial: cada escritura es una orden

        # UART. Los tiempos se miden en ciclos de reloj (ver CICLOS_BYTE_UART).
        self.tx_reg = 0
        self.tx_bytes = []                 # bytes efectivamente transmitidos
        self.tx_restante = 0               # ciclos que queda ocupada la TX
        self.tx_ignorados = 0              # TX_DATA escritos con la TX ocupada
        self.ciclos_tx = ciclos_tx
        self.rx_dato = 0                   # ultimo byte recibido
        self.rx_valido = False             # hay un byte sin consumir
        self.rx_pendiente = []             # bytes que la PC aun va a enviar
        self.rx_espera = 0                 # ciclos hasta el proximo byte
        self.rx_perdidos = 0               # bytes sobrescritos sin consumir
        self.ciclos_rx = ciclos_rx

    # ------------------------------------------------------------------
    # API de prueba
    # ------------------------------------------------------------------
    def pulsar(self, mascara):
        """Fija el nivel de los botones (activos en uno)."""
        self.inputs = mascara & 0x7F

    def alimentar_rx(self, datos):
        """La PC empieza a enviar estos bytes, uno cada 'ciclos_rx' ciclos."""
        if not self.rx_pendiente:
            self.rx_espera = self.ciclos_rx
        self.rx_pendiente.extend(b & 0xFF for b in datos)

    def rx_en_curso(self):
        """True mientras la PC todavia tiene bytes por entregar."""
        return bool(self.rx_pendiente)

    def _llega_byte(self):
        """Un byte termina de recibirse: queda en el unico registro de RX."""
        if self.rx_valido:
            self.rx_perdidos += 1          # sin FIFO: el anterior se pierde
        self.rx_dato = self.rx_pendiente.pop(0)
        self.rx_valido = True
        self.rx_espera = self.ciclos_rx

    def tomar_tx(self):
        """Devuelve y limpia los bytes transmitidos hasta ahora."""
        datos = self.tx_bytes
        self.tx_bytes = []
        return datos

    def leer_ram(self, direccion):
        return self.ram[(direccion - RAM_BASE) >> 2]

    def escribir_ram(self, direccion, valor):
        self.ram[(direccion - RAM_BASE) >> 2] = _u32(valor)

    def tile(self, fila, columna):
        return self.vga[fila * 20 + columna]

    # ------------------------------------------------------------------
    # Acceso a memoria de datos (contrato del bus)
    # ------------------------------------------------------------------
    def leer_dato(self, direccion):
        if direccion % 4 != 0:
            raise Fallo("lectura desalineada en 0x%08X" % direccion)

        if RAM_BASE <= direccion <= RAM_FIN:
            return self.ram[(direccion - RAM_BASE) >> 2]

        if VGA_BASE <= direccion <= VGA_FIN:
            indice = (direccion - VGA_BASE) >> 2
            if indice >= TILES_VISIBLES:
                return 0                   # reservado: lectura cero
            return self.vga[indice]

        if direccion == UART_CTRL:
            estado = 0
            if self.tx_restante == 0:
                estado |= 1                # bit 0: TX lista para otro byte
            if self.rx_valido:
                estado |= 2                # bit 1: hay byte recibido
            return estado

        if direccion == UART_RX:
            # Leer NO consume el byte; eso requiere escribir CONTROL bit 1.
            return self.rx_dato

        if direccion == INPUTS:
            return self.inputs
        if direccion == DISPLAY:
            return self.display
        if direccion == LED:
            return self.led
        if direccion == BUZZER:
            return self.buzzer
        if direccion == UART_TX:
            return self.tx_reg

        return 0                           # no mapeado: lectura cero

    def escribir_dato(self, direccion, valor):
        if direccion % 4 != 0:
            raise Fallo("escritura desalineada en 0x%08X" % direccion)
        valor = _u32(valor)
        self.escrituras += 1               # cada sw es una escritura en el bus

        if RAM_BASE <= direccion <= RAM_FIN:
            self.ram[(direccion - RAM_BASE) >> 2] = valor
            return

        if VGA_BASE <= direccion <= VGA_FIN:
            indice = (direccion - VGA_BASE) >> 2
            if indice < TILES_VISIBLES:
                self.vga[indice] = valor
            return                          # reservado: escritura ignorada

        if direccion == UART_CTRL:
            if valor & 2:                   # consumir byte recibido
                self.rx_valido = False
            return

        if direccion == UART_TX:
            if self.tx_restante == 0:       # TX lista: la escritura la inicia
                self.tx_reg = valor & 0xFF
                self.tx_bytes.append(self.tx_reg)
                self.tx_restante = self.ciclos_tx
            else:
                self.tx_ignorados += 1      # TX ocupada: el byte se pierde
            return

        if direccion == DISPLAY:
            self.display = valor
            return
        if direccion == LED:
            self.led = valor & 0x3
            return
        if direccion == BUZZER:
            # Cada escritura es una orden nueva, aunque repita el valor.
            self.buzzer = valor & 0x7
            self.ordenes_buzzer.append(self.buzzer)
            return

        return                              # no mapeado: escritura ignorada

    # ------------------------------------------------------------------
    # Ejecucion
    # ------------------------------------------------------------------
    def paso(self):
        if self.detenido:
            return False

        latencia = self._latencia()
        self.ciclos += latencia

        if self.tx_restante > 0:
            self.tx_restante = max(0, self.tx_restante - latencia)

        if self.rx_pendiente:
            self.rx_espera -= latencia
            if self.rx_espera <= 0:
                self._llega_byte()

        try:
            self._ejecutar()
        except Fallo as e:
            self.detenido = True
            self.motivo = str(e)
            return False
        self.instrucciones += 1
        return True

    def _latencia(self):
        """Ciclos que tardara la instruccion en self.pc."""
        if self.pc % 4 == 0 and ROM_BASE <= self.pc <= ROM_FIN:
            return LATENCIA.get(self.rom[self.pc >> 2] & 0x7F, 6)
        return 6

    def correr(self, limite=200000):
        """Ejecuta hasta 'limite' instrucciones. Devuelve las ejecutadas."""
        ejecutadas = 0
        while ejecutadas < limite and not self.detenido:
            if not self.paso():
                break
            ejecutadas += 1
        return ejecutadas

    def _ejecutar(self):
        if self.pc % 4 != 0:
            raise Fallo("PC desalineado: 0x%08X" % self.pc)
        if not (ROM_BASE <= self.pc <= ROM_FIN):
            raise Fallo("busqueda fuera de ROM: 0x%08X" % self.pc)

        ins = self.rom[self.pc >> 2]
        opcode = ins & 0x7F
        rd = (ins >> 7) & 0x1F
        f3 = (ins >> 12) & 0x7
        rs1 = (ins >> 15) & 0x1F
        rs2 = (ins >> 20) & 0x1F
        f7 = (ins >> 25) & 0x7F
        siguiente = self.pc + 4

        def imm_i():
            v = ins >> 20
            return v - 0x1000 if v & 0x800 else v

        def imm_s():
            v = ((ins >> 25) << 5) | ((ins >> 7) & 0x1F)
            return v - 0x1000 if v & 0x800 else v

        def imm_b():
            v = (((ins >> 31) & 1) << 12) | (((ins >> 7) & 1) << 11) | \
                (((ins >> 25) & 0x3F) << 5) | (((ins >> 8) & 0xF) << 1)
            return v - 0x2000 if v & 0x1000 else v

        def imm_u():
            return _u32(ins & 0xFFFFF000)

        def imm_j():
            v = (((ins >> 31) & 1) << 20) | (((ins >> 12) & 0xFF) << 12) | \
                (((ins >> 20) & 1) << 11) | (((ins >> 21) & 0x3FF) << 1)
            return v - 0x200000 if v & 0x100000 else v

        a = self.reg[rs1]
        b = self.reg[rs2]
        resultado = None

        if opcode == 0b0110011:            # R-tipo
            if f7 == 0b0000000 and f3 == 0b000: resultado = _u32(a + b)
            elif f7 == 0b0100000 and f3 == 0b000: resultado = _u32(a - b)
            elif f7 == 0b0000000 and f3 == 0b001: resultado = _u32(a << (b & 0x1F))
            elif f7 == 0b0000000 and f3 == 0b010: resultado = 1 if _s32(a) < _s32(b) else 0
            elif f7 == 0b0000000 and f3 == 0b011: resultado = 1 if a < b else 0
            elif f7 == 0b0000000 and f3 == 0b100: resultado = a ^ b
            elif f7 == 0b0000000 and f3 == 0b101: resultado = a >> (b & 0x1F)
            elif f7 == 0b0100000 and f3 == 0b101: resultado = _u32(_s32(a) >> (b & 0x1F))
            elif f7 == 0b0000000 and f3 == 0b110: resultado = a | b
            elif f7 == 0b0000000 and f3 == 0b111: resultado = a & b
            else:
                raise Fallo("R-tipo no soportado en 0x%08X (ins=0x%08X)" % (self.pc, ins))

        elif opcode == 0b0010011:          # I-tipo aritmetico
            imm = imm_i()
            if f3 == 0b000: resultado = _u32(a + imm)
            elif f3 == 0b010: resultado = 1 if _s32(a) < imm else 0
            elif f3 == 0b011: resultado = 1 if a < _u32(imm) else 0
            elif f3 == 0b100: resultado = a ^ _u32(imm)
            elif f3 == 0b110: resultado = a | _u32(imm)
            elif f3 == 0b111: resultado = a & _u32(imm)
            elif f3 == 0b001:
                if f7 != 0: raise Fallo("slli con funct7 invalido en 0x%08X" % self.pc)
                resultado = _u32(a << rs2)
            elif f3 == 0b101:
                if f7 == 0b0000000: resultado = a >> rs2
                elif f7 == 0b0100000: resultado = _u32(_s32(a) >> rs2)
                else: raise Fallo("srli/srai con funct7 invalido en 0x%08X" % self.pc)
            else:
                raise Fallo("I-tipo no soportado en 0x%08X" % self.pc)

        elif opcode == 0b0000011:          # lw
            if f3 != 0b010:
                raise Fallo("carga no soportada (solo lw) en 0x%08X" % self.pc)
            resultado = self.leer_dato(_u32(a + imm_i()))

        elif opcode == 0b0100011:          # sw
            if f3 != 0b010:
                raise Fallo("almacenamiento no soportado (solo sw) en 0x%08X" % self.pc)
            self.escribir_dato(_u32(a + imm_s()), b)

        elif opcode == 0b1100011:          # bifurcaciones
            imm = imm_b()
            if f3 == 0b000: tomar = a == b
            elif f3 == 0b001: tomar = a != b
            elif f3 == 0b100: tomar = _s32(a) < _s32(b)
            elif f3 == 0b101: tomar = _s32(a) >= _s32(b)
            else:
                raise Fallo("bifurcacion no soportada (bltu/bgeu no existen) en 0x%08X" % self.pc)
            if tomar:
                destino = _u32(self.pc + imm)
                if not _destino_valido(destino):
                    raise Fallo("destino de bifurcacion invalido: 0x%08X" % destino)
                siguiente = destino

        elif opcode == 0b1101111:          # jal
            destino = _u32(self.pc + imm_j())
            # Como en el CPU del equipo: el destino se valida ANTES de escribir
            # el enlace, asi un salto invalido no modifica rd.
            if not _destino_valido(destino):
                raise Fallo("destino de jal invalido: 0x%08X" % destino)
            resultado = _u32(self.pc + 4)
            siguiente = destino

        elif opcode == 0b1100111:          # jalr
            if f3 != 0:
                raise Fallo("jalr con funct3 invalido en 0x%08X" % self.pc)
            destino = _u32(a + imm_i()) & ~1
            if not _destino_valido(destino):
                raise Fallo("destino de jalr invalido: 0x%08X" % destino)
            resultado = _u32(self.pc + 4)
            siguiente = destino

        elif opcode == 0b0110111:          # lui
            resultado = imm_u()

        elif opcode == 0b0010111:          # auipc
            resultado = _u32(self.pc + imm_u())

        else:
            raise Fallo("opcode 0x%02X no soportado en 0x%08X" % (opcode, self.pc))

        if resultado is not None and rd != 0:
            self.reg[rd] = _u32(resultado)
        self.reg[0] = 0
        self.pc = siguiente


def _destino_valido(destino):
    """Un salto solo puede ir a un inicio de instruccion dentro de la ROM."""
    return destino % 4 == 0 and ROM_BASE <= destino <= ROM_FIN - 3


def cargar_hex(ruta):
    imagen = []
    with open(ruta, "r", encoding="utf-8") as f:
        for linea in f:
            linea = linea.strip()
            if linea:
                imagen.append(int(linea, 16))
    return imagen
