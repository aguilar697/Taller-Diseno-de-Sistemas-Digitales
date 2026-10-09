"""Arnes compartido por las pruebas del programa de Batalla Naval.

Ensambla el programa, lo ejecuta en el emulador y ofrece operaciones de alto
nivel (pulsar un boton, enviar una trama, leer los mensajes emitidos) para que
cada prueba se lea como una partida y no como manipulacion de registros.
"""

import os
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.normpath(os.path.join(AQUI, "..", ".."))
sys.path.insert(0, AQUI)
# Fuentes del programa: las del repositorio, o las de la carpeta indicada en
# BN_FUENTES (se usa para el ensayo del error forzado sobre una copia).
DIR_FUENTES = os.environ.get("BN_FUENTES") or os.path.join(RAIZ, "src", "software_riscv")

import asm
import emu

FUENTES = ["constantes.s", "main.s", "control_estado.s", "colocacion.s",
           "turnos.s", "victoria.s", "uart.s", "salidas.s"]

SOF = 0xA5
T_PLACE, T_SHOT = 0x10, 0x11
T_PLACE_RESULT, T_BATTLE_START, T_TURN = 0x80, 0x81, 0x82
T_SHOT_RESULT, T_INCOMING_SHOT, T_GAME_OVER = 0x83, 0x84, 0x85
T_PLACEMENT_START, T_ERROR = 0x86, 0x87

NOMBRE_TIPO = {
    T_PLACE: "PLACE", T_SHOT: "SHOT",
    T_PLACE_RESULT: "PLACE_RESULT", T_BATTLE_START: "BATTLE_START",
    T_TURN: "TURN", T_SHOT_RESULT: "SHOT_RESULT",
    T_INCOMING_SHOT: "INCOMING_SHOT", T_GAME_OVER: "GAME_OVER",
    T_PLACEMENT_START: "PLACEMENT_START", T_ERROR: "ERROR",
}

BTN_UP, BTN_DOWN, BTN_LEFT, BTN_RIGHT = 1, 2, 4, 8
BTN_SEL, BTN_OK, BTN_RST = 16, 32, 64

FASE_COLOC, FASE_BATALLA, FASE_RESULT = 0, 1, 2
AGUA, BARCO, FALLO, HIT = 0, 1, 2, 3
RES_MISS, RES_HIT, RES_SUNK = 0, 1, 2
ORIENT_H, ORIENT_V = 0, 1

_cache = {}


def construir():
    """Ensambla el programa una sola vez por ejecucion de pruebas."""
    if "imagen" not in _cache:
        rutas = [os.path.join(DIR_FUENTES, f) for f in FUENTES]
        imagen, ensamblador = asm.ensamblar(rutas)
        _cache["imagen"] = imagen
        _cache["simbolos"] = ensamblador.simbolos()
    return _cache["imagen"], _cache["simbolos"]


class Juego:
    """Una partida en curso dentro del emulador."""

    def __init__(self, ciclos_tx=4, ciclos_rx=emu.CICLOS_BYTE_UART):
        imagen, simbolos = construir()
        self.sim = emu.Sistema(imagen, ciclos_tx=ciclos_tx, ciclos_rx=ciclos_rx)
        self.simbolos = simbolos
        self.pc_bucle = simbolos["bucle_servicio"]
        self.tramas = []
        self._pendiente = []
        # Duracion, en ciclos de reloj, de la vuelta mas larga del ciclo de
        # servicio desde que se puso en cero (ver _vueltas_exactas).
        self.vuelta_max = 0
        self._inicio_vuelta = 0
        # Arranque: ejecuta la inicializacion y deja salir el PLACEMENT_START
        # inicial, para que toda prueba parta del mismo estado observable.
        self.correr_vueltas(12)

    # ------------------------------------------------------------------
    def correr_vueltas(self, vueltas=1, limite=4000000):
        """Ejecuta N pasadas por el ciclo de servicio y luego deja asentar.

        Asentar significa esperar a que la PC termine de entregar los bytes
        que envio, a que el programa los consuma, a que termine el
        redibujado de la pantalla (que se hace por pasos, uno por vuelta) y a
        que salga todo lo encolado para transmitir. Asi, al volver, el efecto
        de la accion anterior ya es observable completo.
        """
        self._vueltas_exactas(vueltas, limite)
        self._asentar()
        self._recoger_tx()

    def _quieto(self):
        sim = self.sim
        return (not sim.rx_en_curso() and not sim.rx_valido
                and self.var("VGA_DIRTY") == 0
                and self.var("TX_COUNT") == 0 and sim.tx_restante == 0)

    def _asentar(self, maximo=60000):
        vueltas = 0
        while not self._quieto():
            self._vueltas_exactas(1)
            vueltas += 1
            if vueltas > maximo:
                raise AssertionError("el sistema no se asento en %d vueltas" % maximo)

    def _vueltas_exactas(self, vueltas=1, limite=4000000):
        """Ejecuta exactamente N pasadas por el ciclo de servicio."""
        vistas = 0
        pasos = 0
        while vistas < vueltas and pasos < limite:
            if self.sim.detenido:
                raise AssertionError("el CPU se detuvo: %s" % self.sim.motivo)
            if not self.sim.paso():
                raise AssertionError("el CPU se detuvo: %s" % self.sim.motivo)
            pasos += 1
            if self.sim.pc == self.pc_bucle:
                vistas += 1
                duracion = self.sim.ciclos - self._inicio_vuelta
                self.vuelta_max = max(self.vuelta_max, duracion)
                self._inicio_vuelta = self.sim.ciclos
        if vistas < vueltas:
            raise AssertionError("no se completaron %d vueltas del ciclo" % vueltas)

    def _recoger_tx(self):
        self._pendiente.extend(self.sim.tomar_tx())
        # Descompone el flujo de bytes en tramas completas.
        while True:
            if SOF not in self._pendiente:
                break
            inicio = self._pendiente.index(SOF)
            del self._pendiente[:inicio]
            if len(self._pendiente) < 3:
                break
            tipo = self._pendiente[1]
            largo = self._pendiente[2]
            if len(self._pendiente) < 3 + largo:
                break
            payload = self._pendiente[3:3 + largo]
            self.tramas.append((tipo, payload))
            del self._pendiente[:3 + largo]

    # ------------------------------------------------------------------
    # Entradas de J1
    # ------------------------------------------------------------------
    def pulsar(self, mascara, vueltas=2):
        """Pulsa y suelta: el programa reacciona al flanco ascendente."""
        self.sim.pulsar(mascara)
        self.correr_vueltas(vueltas)
        self.sim.pulsar(0)
        self.correr_vueltas(vueltas)

    def mover(self, mascara, veces=1):
        for _ in range(veces):
            self.pulsar(mascara)

    # ------------------------------------------------------------------
    # Entradas de J2 (PC por UART)
    # ------------------------------------------------------------------
    def enviar_trama(self, tipo, payload, vueltas=None):
        datos = [SOF, tipo, len(payload)] + list(payload)
        self.sim.alimentar_rx(datos)
        # La PC entrega un byte cada sim.ciclos_rx ciclos; correr_vueltas
        # espera a que lleguen todos y a que el programa responda.
        self.correr_vueltas(vueltas or 5)

    def enviar_place(self, ship_id, fila, col, orient):
        self.enviar_trama(T_PLACE, [ship_id, fila, col, orient])

    def enviar_shot(self, fila, col):
        self.enviar_trama(T_SHOT, [fila, col])

    # ------------------------------------------------------------------
    # Consultas de estado
    # ------------------------------------------------------------------
    def var(self, nombre):
        return self.sim.leer_ram(self.simbolos[nombre])

    def casilla(self, jugador, fila, col):
        base = self.simbolos["BOARD_J1" if jugador == 1 else "BOARD_J2"]
        return self.sim.leer_ram(base + 4 * (fila * 8 + col))

    def barco(self, jugador, ship_id, campo):
        base = self.simbolos["SHIPS_BASE"] + 32 * ((jugador - 1) * 3 + ship_id)
        return self.sim.leer_ram(base + self.simbolos[campo])

    def tile(self, fila, col):
        return self.sim.vga[fila * 20 + col]

    def color_tile(self, fila, col):
        return self.tile(fila, col) & 0x7

    def tile_tablero(self, cual, fila, col):
        """cual: 'propio' (J1) o 'rival' (J2), en coordenadas de tablero."""
        col_base = self.simbolos["TAB_COL_PROPIO" if cual == "propio"
                                 else "TAB_COL_RIVAL"]
        return self.color_tile(self.simbolos["TAB_FILA"] + fila, col_base + col)

    def tramas_de(self, tipo):
        return [p for t, p in self.tramas if t == tipo]

    def ultima_trama(self, tipo):
        lista = self.tramas_de(tipo)
        return lista[-1] if lista else None

    def drenar(self, vueltas=25):
        """Deja salir lo que quede en la cola de transmision y en pantalla."""
        self.correr_vueltas(vueltas)
        return self

    def limpiar_tramas(self):
        """Descarta las tramas ya observadas.

        Se drena primero: la cola de transmision envia un byte por vuelta,
        asi que sin drenar quedarian bytes en vuelo que apareceran despues y
        se confundirian con la respuesta de la siguiente accion.
        """
        self.drenar()
        self.tramas = []

    def resumen_tramas(self):
        return [(NOMBRE_TIPO.get(t, hex(t)), p) for t, p in self.tramas]

    # ------------------------------------------------------------------
    # Secuencias de uso frecuente
    # ------------------------------------------------------------------
    def colocar_flota_j2(self, posiciones=None):
        """Coloca los 3 barcos de J2 por UART."""
        posiciones = posiciones or [(0, 0, ORIENT_H), (2, 0, ORIENT_H),
                                    (4, 0, ORIENT_H)]
        for ship_id, (fila, col, orient) in enumerate(posiciones):
            self.enviar_place(ship_id, fila, col, orient)

    def colocar_flota_j1(self):
        """Coloca los 3 barcos de J1 con los botones, en filas 0, 2 y 4."""
        self.pulsar(BTN_OK)                  # barco 0 en (0,0) horizontal
        self.mover(BTN_DOWN, 2)
        self.pulsar(BTN_OK)                  # barco 1 en (2,0)
        self.mover(BTN_DOWN, 2)
        self.pulsar(BTN_OK)                  # barco 2 en (4,0)


class Resultados:
    """Acumulador de comprobaciones con reporte de aciertos y fallos."""

    def __init__(self, titulo):
        self.titulo = titulo
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

    def reportar(self):
        print("=" * 66)
        print("BLOQUE: %s" % self.titulo)
        for f in self.fallos:
            print("  FALLO: %s" % f)
        if self.fallos:
            print("  RESULTADO: %d correctas, %d FALLOS" % (self.ok, len(self.fallos)))
        else:
            print("  RESULTADO: %d comprobaciones, 0 fallos" % self.ok)
        print("=" * 66)
        return 1 if self.fallos else 0
