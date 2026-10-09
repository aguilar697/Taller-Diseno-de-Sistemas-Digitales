"""Prueba autoverificable del ensamblador y del emulador.

Verifica que las herramientas de prueba son correctas antes de confiar en
ellas para validar el programa del juego: si el ensamblador codifica mal o el
emulador ejecuta mal, cualquier prueba posterior seria enganosa.
"""

import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, AQUI)

import asm
import emu


def ensamblar_texto(texto):
    a = asm.Ensamblador()
    a.analizar([("prueba.s", texto)])
    a.resolver()
    palabras = a.codificar_todo()
    imagen = [asm.NOP] * asm.ROM_PALABRAS
    for pc, palabra, _ctx, _txt in palabras:
        imagen[pc >> 2] = palabra
    return imagen, a


def correr(texto, pasos=2000, **kwargs):
    imagen, _ = ensamblar_texto(texto)
    s = emu.Sistema(imagen, **kwargs)
    s.correr(pasos)
    return s


class Resultados:
    def __init__(self):
        self.ok = 0
        self.fallos = []

    def check(self, condicion, mensaje):
        if condicion:
            self.ok += 1
        else:
            self.fallos.append(mensaje)

    def igual(self, obtenido, esperado, mensaje):
        self.check(obtenido == esperado,
                   "%s: se esperaba %r, se obtuvo %r" % (mensaje, esperado, obtenido))


def pruebas(r):
    # --- Codificacion contra valores conocidos de la especificacion RV32I ---
    imagen, _ = ensamblar_texto("add x1, x2, x3")
    r.igual(imagen[0], 0x003100B3, "codificacion de add x1,x2,x3")

    imagen, _ = ensamblar_texto("addi x5, x0, -1")
    r.igual(imagen[0], 0xFFF00293, "codificacion de addi x5,x0,-1")

    imagen, _ = ensamblar_texto("lw x7, 8(x9)")
    r.igual(imagen[0], 0x0084A383, "codificacion de lw x7,8(x9)")

    imagen, _ = ensamblar_texto("sw x7, 12(x9)")
    r.igual(imagen[0], 0x0074A623, "codificacion de sw x7,12(x9)")

    imagen, _ = ensamblar_texto("lui x3, 0x12345")
    r.igual(imagen[0], 0x123451B7, "codificacion de lui x3,0x12345")

    # --- Aritmetica basica y registro x0 ---
    s = correr("""
        li   t0, 100
        li   t1, 23
        add  t2, t0, t1
        sub  t3, t0, t1
        li   x0, 55
        li   a0, 0x2000
        sw   t2, 0(a0)
        sw   t3, 4(a0)
        sw   x0, 8(a0)
    fin: j fin
    """)
    r.igual(s.leer_ram(0x2000), 123, "suma 100+23")
    r.igual(s.leer_ram(0x2004), 77, "resta 100-23")
    r.igual(s.leer_ram(0x2008), 0, "x0 siempre vale cero")

    # --- li con valores grandes (lui+addi, con correccion de signo) ---
    for valor in (0x00011000, 0x7FFFFFFF, 0x000007FF, 0x00000800, 0xFFF):
        s = correr("""
            li   t0, %d
            li   a0, 0x2000
            sw   t0, 0(a0)
        fin: j fin
        """ % valor)
        r.igual(s.leer_ram(0x2000), valor & 0xFFFFFFFF, "li de 0x%X" % valor)

    # --- Bifurcaciones con signo ---
    s = correr("""
        li   a0, 0x2000
        li   t0, -5
        li   t1, 3
        blt  t0, t1, menor
        li   t2, 0
        j    guardar
    menor:
        li   t2, 1
    guardar:
        sw   t2, 0(a0)
    fin: j fin
    """)
    r.igual(s.leer_ram(0x2000), 1, "blt con negativo")

    # --- Comparacion sin signo (sltu), necesaria porque no existe bltu ---
    s = correr("""
        li   a0, 0x2000
        li   t0, -1
        li   t1, 1
        sltu t2, t0, t1
        sw   t2, 0(a0)
    fin: j fin
    """)
    r.igual(s.leer_ram(0x2000), 0, "sltu trata -1 como valor grande sin signo")

    # --- Llamadas y pila ---
    s = correr("""
        li   sp, 0x3000
        li   a0, 7
        call doble
        li   t0, 0x2000
        sw   a0, 0(t0)
    fin: j fin

    doble:
        addi sp, sp, -16
        sw   ra, 12(sp)
        add  a0, a0, a0
        lw   ra, 12(sp)
        addi sp, sp, 16
        ret
    """)
    r.igual(s.leer_ram(0x2000), 14, "llamada con pila devuelve 7*2")

    # --- Bucle con contador ---
    s = correr("""
        li   a0, 0x2000
        li   t0, 0
        li   t1, 0
        li   t2, 10
    bucle:
        add  t1, t1, t0
        addi t0, t0, 1
        blt  t0, t2, bucle
        sw   t1, 0(a0)
    fin: j fin
    """)
    r.igual(s.leer_ram(0x2000), 45, "suma 0..9 en bucle")

    # --- Perifericos: escritura de LED, display y buzzer ---
    s = correr("""
        li   t0, 0x10138
        li   t1, 1
        sw   t1, 0(t0)
        li   t0, 0x10130
        li   t1, 0x0507
        sw   t1, 0(t0)
        li   t0, 0x10140
        li   t1, 3
        sw   t1, 0(t0)
        sw   t1, 0(t0)
    fin: j fin
    """)
    r.igual(s.led, 1, "escritura de LED")
    r.igual(s.display, 0x0507, "escritura de display")
    r.igual(s.ordenes_buzzer, [3, 3], "cada escritura de buzzer es una orden nueva")

    # --- VGA: tiles visibles y region reservada ---
    s = correr("""
        li   t0, 0x11000
        li   t1, 0x2A
        sw   t1, 0(t0)
        li   t0, 0x11000
        li   t2, 1200
        add  t0, t0, t2
        sw   t1, 0(t0)
        li   t0, 0x11000
        li   t2, 1196
        add  t0, t0, t2
        sw   t1, 0(t0)
    fin: j fin
    """)
    r.igual(s.vga[0], 0x2A, "escritura de tile 0")
    r.igual(s.vga[299], 0x2A, "escritura de tile 299 (ultimo visible)")
    r.igual(len(s.vga), 512, "memoria de video de 512 palabras")
    s2 = correr("""
        li   t0, 0x11000
        li   t2, 1200
        add  t0, t0, t2
        li   t1, 0x2A
        sw   t1, 0(t0)
        lw   t3, 0(t0)
        li   a0, 0x2000
        sw   t3, 0(a0)
    fin: j fin
    """)
    r.igual(s2.leer_ram(0x2000), 0, "tile reservado (indice 300) lee cero")

    # --- Direcciones no mapeadas ---
    s = correr("""
        li   t0, 0x20000
        li   t1, 0x1234
        sw   t1, 0(t0)
        lw   t2, 0(t0)
        li   a0, 0x2000
        sw   t2, 0(a0)
    fin: j fin
    """)
    r.igual(s.leer_ram(0x2000), 0, "direccion no mapeada devuelve cero")

    # --- UART: transmision (contrato del periferico real del equipo) ---
    s = correr("""
        li   s0, 0x10040
        li   s1, 0x10044
        li   a0, 0x2000
        lw   t0, 0(s0)
        sw   t0, 0(a0)
        li   t1, 0x5A
        sw   t1, 0(s1)
        lw   t0, 0(s0)
        sw   t0, 4(a0)
        li   t1, 0x6B
        sw   t1, 0(s1)
    fin: j fin
    """, ciclos_tx=50)
    r.igual(s.tomar_tx(), [0x5A], "escribir TX_DATA con la TX lista transmite el byte")
    r.igual(s.leer_ram(0x2000) & 1, 1, "CONTROL bit 0 = 1 con la TX lista")
    r.igual(s.leer_ram(0x2004) & 1, 0, "CONTROL bit 0 = 0 mientras transmite")
    r.igual(s.tx_ignorados, 1, "un byte escrito con la TX ocupada se descarta")

    s = correr("""
        li   s0, 0x10040
        li   s2, 0x10048
        li   a0, 0x2000
    espera:
        lw   t0, 0(s0)
        andi t0, t0, 2
        beqz t0, espera
        lw   t1, 0(s2)
        sw   t1, 0(a0)
        lw   t2, 0(s2)
        sw   t2, 4(a0)
        li   t3, 2
        sw   t3, 0(s0)
        lw   t4, 0(s0)
        andi t4, t4, 2
        sw   t4, 8(a0)
    fin: j fin
    """)
    s.alimentar_rx([0x99])
    s.detenido = False
    s.pc = 0
    s.correr(5000)
    r.igual(s.leer_ram(0x2000), 0x99, "lectura de byte recibido")
    r.igual(s.leer_ram(0x2004), 0x99, "leer RX no consume el byte")
    r.igual(s.leer_ram(0x2008), 0, "escribir CONTROL bit1 consume el byte")

    # --- UART: sin FIFO, un byte nuevo pisa al que no se consumio ---
    s = correr("""
    fin: j fin
    """)
    s.ciclos_rx = 10
    s.alimentar_rx([0x11, 0x22])
    s.detenido = False
    s.pc = 0
    s.correr(100)
    r.igual(s.rx_dato, 0x22, "el registro de RX guarda solo el ultimo byte")
    r.igual(s.rx_perdidos, 1, "el byte no consumido se pierde (no hay FIFO)")

    # --- Deteccion de instrucciones no soportadas ---
    try:
        ensamblar_texto("mul x1, x2, x3")
        r.check(False, "el ensamblador debe rechazar 'mul'")
    except asm.ErrorEnsamblador:
        r.check(True, "")

    try:
        ensamblar_texto("bltu x1, x2, 0")
        r.check(False, "el ensamblador debe rechazar 'bltu'")
    except asm.ErrorEnsamblador:
        r.check(True, "")

    try:
        ensamblar_texto("lb x1, 0(x2)")
        r.check(False, "el ensamblador debe rechazar 'lb'")
    except asm.ErrorEnsamblador:
        r.check(True, "")

    # --- El emulador detiene el CPU ante acceso desalineado ---
    s = correr("""
        li   t0, 0x2002
        lw   t1, 0(t0)
    fin: j fin
    """)
    r.check(s.detenido and "desalineada" in (s.motivo or ""),
            "acceso desalineado debe detener el CPU, motivo=%r" % s.motivo)


def main():
    r = Resultados()
    pruebas(r)
    print("=" * 60)
    if r.fallos:
        for f in r.fallos:
            print("FALLO: %s" % f)
        print("RESULTADO: %d correctas, %d fallos" % (r.ok, len(r.fallos)))
        print("=" * 60)
        return 1
    print("HERRAMIENTAS OK: %d comprobaciones, 0 fallos" % r.ok)
    print("=" * 60)
    return 0


if __name__ == "__main__":
    sys.exit(main())
