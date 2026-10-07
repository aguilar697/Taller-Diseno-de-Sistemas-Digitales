"""Terminal serial del Jugador 2 para Batalla Naval.

Protocolo: el definido en docs/diseno/nivel_3_logica_juego.md, sección 4.6.
"""

from __future__ import annotations

import argparse
from dataclasses import dataclass, field
from queue import Empty, Queue
import threading
import time
from typing import Iterable, Optional

try:
    import serial
    from serial.tools import list_ports
except ImportError:  # Permite ejecutar las pruebas del protocolo sin pyserial.
    serial = None
    list_ports = None


SOF = 0xA5

TYPE_PLACE_SHIP = 0x10
TYPE_SHOT = 0x11
TYPE_PLACE_RESULT = 0x80
TYPE_BATTLE_START = 0x81
TYPE_TURN = 0x82
TYPE_SHOT_RESULT = 0x83
TYPE_INCOMING_SHOT = 0x84
TYPE_GAME_OVER = 0x85
TYPE_PLACEMENT_START = 0x86
TYPE_ERROR = 0x87

EXPECTED_LENGTHS = {
    TYPE_PLACE_SHIP: 4,
    TYPE_SHOT: 2,
    TYPE_PLACE_RESULT: 3,
    TYPE_BATTLE_START: 1,
    TYPE_TURN: 1,
    TYPE_SHOT_RESULT: 3,
    TYPE_INCOMING_SHOT: 3,
    TYPE_GAME_OVER: 7,
    TYPE_PLACEMENT_START: 2,
    TYPE_ERROR: 2,
}

SHIP_LENGTHS = {0: 4, 1: 3, 2: 2}
PLACE_REASONS = {
    0: "OK",
    1: "se traslapa con otro barco",
    2: "se sale del tablero",
    3: "identificador de barco inválido",
    4: "ese barco ya estaba colocado",
    5: "orientación inválida",
}
ERROR_REASONS = {
    1: "mensaje inválido",
    2: "no corresponde a la fase actual",
    3: "no es su turno",
    4: "esa casilla ya fue disparada",
    5: "coordenada inválida",
}
ERROR_WRONG_TURN = 3
ERROR_REPEATED_SHOT = 4
ERROR_INVALID_COORDINATE = 5
SHOT_RESULTS = {0: "agua", 1: "impacto", 2: "hundido"}


@dataclass(frozen=True)
class Frame:
    message_type: int
    payload: bytes


def build_frame(message_type: int, payload: Iterable[int] | bytes = b"") -> bytes:
    """Construye una trama y valida TYPE y LENGTH."""
    if message_type not in EXPECTED_LENGTHS:
        raise ValueError(f"TYPE no válido: 0x{message_type:02X}")

    payload_bytes = bytes(payload)
    expected_length = EXPECTED_LENGTHS[message_type]
    if len(payload_bytes) != expected_length:
        raise ValueError(
            f"LENGTH inválido para TYPE 0x{message_type:02X}: "
            f"{len(payload_bytes)} != {expected_length}"
        )

    return bytes((SOF, message_type, expected_length)) + payload_bytes


class FrameParser:
    """Parser incremental de SOF, TYPE, LENGTH y PAYLOAD."""

    WAIT_SOF = 0
    READ_TYPE = 1
    READ_LENGTH = 2
    READ_PAYLOAD = 3
    # Una trama normal tarda mucho menos; este margen tolera pausas del USB.
    INTER_BYTE_TIMEOUT = 0.5

    def __init__(self) -> None:
        self._state = self.WAIT_SOF
        self._message_type = 0
        self._expected_length = 0
        self._payload = bytearray()
        self._last_data_time: Optional[float] = None

    def reset(self) -> None:
        self._state = self.WAIT_SOF
        self._message_type = 0
        self._expected_length = 0
        self._payload.clear()
        self._last_data_time = None

    def _restart_if_sof(self, value: int) -> None:
        self.reset()
        if value == SOF:
            self._state = self.READ_TYPE

    def feed_byte(self, value: int) -> Optional[Frame]:
        value &= 0xFF

        if self._state == self.WAIT_SOF:
            if value == SOF:
                self._state = self.READ_TYPE
            return None

        if self._state == self.READ_TYPE:
            if value not in EXPECTED_LENGTHS:
                self._restart_if_sof(value)
                return None
            self._message_type = value
            self._state = self.READ_LENGTH
            return None

        if self._state == self.READ_LENGTH:
            expected = EXPECTED_LENGTHS[self._message_type]
            if value != expected:
                self._restart_if_sof(value)
                return None
            self._expected_length = value
            self._payload.clear()
            if value == 0:
                frame = Frame(self._message_type, b"")
                self.reset()
                return frame
            self._state = self.READ_PAYLOAD
            return None

        self._payload.append(value)
        if len(self._payload) == self._expected_length:
            frame = Frame(self._message_type, bytes(self._payload))
            self.reset()
            return frame
        return None

    def feed(self, data: bytes | bytearray) -> list[Frame]:
        now = time.monotonic()
        # Un reset puede cortar una trama antes de transmitir todo el payload.
        # Tras un intervalo sin datos, la próxima trama debe empezar en SOF.
        if (self._last_data_time is not None and
                now - self._last_data_time >= self.INTER_BYTE_TIMEOUT):
            self.reset()
        frames = []
        for value in data:
            frame = self.feed_byte(value)
            if frame is not None:
                frames.append(frame)
        if data and self._state != self.WAIT_SOF:
            self._last_data_time = now
        return frames


class SerialConnection:
    """Conexión 115200 8N1 con recepción continua en un hilo daemon."""

    def __init__(self, port: str, baudrate: int = 115200) -> None:
        self.port_name = port
        self.baudrate = baudrate
        self._port = None
        self._parser = FrameParser()
        self._frames: Queue[Frame] = Queue()
        self._stop_event = threading.Event()
        self._reader: Optional[threading.Thread] = None
        self._read_error: Optional[Exception] = None

    @staticmethod
    def available_ports() -> list[str]:
        if list_ports is None:
            return []
        return [port.device for port in list_ports.comports()]

    def open(self) -> None:
        if serial is None:
            raise RuntimeError("pyserial no está instalado")
        self._port = serial.Serial(
            port=self.port_name,
            baudrate=self.baudrate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.1,
            write_timeout=1.0,
        )
        self._stop_event.clear()
        self._read_error = None
        self._reader = threading.Thread(target=self._read_loop, daemon=True)
        self._reader.start()

    def close(self) -> None:
        self._stop_event.set()
        if self._reader is not None:
            self._reader.join(timeout=0.5)
        if self._port is not None and self._port.is_open:
            self._port.close()

    def _read_loop(self) -> None:
        try:
            while not self._stop_event.is_set():
                count = max(1, self._port.in_waiting)
                data = self._port.read(count)
                for frame in self._parser.feed(data):
                    self._frames.put(frame)
        except Exception as exc:  # El hilo comunica el error al hilo principal.
            self._read_error = exc
            self._stop_event.set()

    def send(self, message_type: int, payload: Iterable[int] | bytes = b"") -> None:
        if self._port is None or not self._port.is_open:
            raise RuntimeError("El puerto serial no está abierto")
        frame = build_frame(message_type, payload)
        written = self._port.write(frame)
        if written != len(frame):
            raise IOError("No se pudo transmitir la trama completa")
        self._port.flush()

    def pending(self) -> Iterable[Frame]:
        """Extrae una trama por vez; interrumpir el recorrido conserva las demás."""
        if self._read_error is not None:
            raise IOError(f"Error de recepción serial: {self._read_error}")
        while True:
            try:
                yield self._frames.get_nowait()
            except Empty:
                return

    def receive(self, timeout: Optional[float] = None) -> Frame:
        deadline = None if timeout is None else time.monotonic() + timeout
        while True:
            if self._read_error is not None:
                raise IOError(f"Error de recepción serial: {self._read_error}")
            wait_time = 0.1
            if deadline is not None:
                wait_time = min(wait_time, max(0.0, deadline - time.monotonic()))
                if wait_time == 0.0:
                    raise TimeoutError("Tiempo de espera de trama agotado")
            try:
                return self._frames.get(timeout=wait_time)
            except Empty:
                continue


@dataclass
class GameState:
    own_board: list[list[str]] = field(
        default_factory=lambda: [["~"] * 8 for _ in range(8)]
    )
    enemy_board: list[list[str]] = field(
        default_factory=lambda: [["?"] * 8 for _ in range(8)]
    )
    current_turn: int = 0
    game_over: bool = False
    # PLACEMENT_START llegó en mitad de una partida: J1 la reinició (GAME_RST).
    new_game: bool = False
    # La FPGA rechazó el último disparo sin gastar el turno: hay que repetirlo.
    retry_shot: bool = False
    p1_wins: int = 0
    p2_wins: int = 0
    # Distingue el anuncio inicial de un reinicio de una partida ya iniciada.
    placement_started: bool = False

    def reset_boards(self) -> None:
        self.own_board = [["~"] * 8 for _ in range(8)]
        self.enemy_board = [["?"] * 8 for _ in range(8)]
        self.current_turn = 0
        self.game_over = False
        self.retry_shot = False


class NewGame(Exception):
    """J1 reinició la partida desde la FPGA."""


def send_place_ship(
    connection: SerialConnection, ship_id: int, row: int, col: int,
    orientation: int
) -> None:
    connection.send(TYPE_PLACE_SHIP, (ship_id, row, col, orientation))


def send_shot(connection: SerialConnection, row: int, col: int) -> None:
    connection.send(TYPE_SHOT, (row, col))


def print_boards(state: GameState) -> None:
    print("\n      TABLERO PROPIO                 TABLERO RIVAL")
    numbers = " ".join(map(str, range(8)))
    print(f"{'':4}{numbers}{'':11}{numbers}")
    for row in range(8):
        own = " ".join(state.own_board[row])
        enemy = " ".join(state.enemy_board[row])
        print(f"{row} | {own}       {row} | {enemy}")


def _read_coordinate(label: str) -> int:
    while True:
        raw = input(f"{label} (0-7): ").strip()
        try:
            value = int(raw)
        except ValueError:
            print("Entrada inválida. Ingrese un número entre 0 y 7.")
            continue
        if 0 <= value <= 7:
            return value
        print("Valor fuera de rango.")


def _read_orientation() -> int:
    while True:
        value = input("Orientación H/V: ").strip().upper()
        if value == "H":
            return 0
        if value == "V":
            return 1
        print("Orientación inválida.")


def _mark_accepted_ship(
    state: GameState, ship_id: int, row: int, col: int, orientation: int
) -> None:
    length = SHIP_LENGTHS[ship_id]
    for offset in range(length):
        target_row = row + (offset if orientation == 1 else 0)
        target_col = col + (offset if orientation == 0 else 0)
        if 0 <= target_row < 8 and 0 <= target_col < 8:
            state.own_board[target_row][target_col] = "S"


def valid_notification(frame: Frame) -> bool:
    """Valida los campos de una notificación antes de modificar los tableros."""
    kind, payload = frame.message_type, frame.payload
    if len(payload) != EXPECTED_LENGTHS.get(kind):
        return False
    if kind == TYPE_PLACE_RESULT:
        ship, accepted, reason = payload
        # La FPGA devuelve el identificador original cuando rechaza un barco.
        if accepted == 0 and reason == 3:
            return True
        return ship in SHIP_LENGTHS and (
            (accepted == 1 and reason == 0) or
            (accepted == 0 and reason in (1, 2, 3, 4, 5))
        )
    if kind in (TYPE_BATTLE_START, TYPE_TURN):
        return payload[0] in (1, 2)
    if kind in (TYPE_SHOT_RESULT, TYPE_INCOMING_SHOT):
        row, col, result = payload
        return row < 8 and col < 8 and result in SHOT_RESULTS
    if kind == TYPE_GAME_OVER:
        winner, shots1, shots2, sunk1, sunk2, wins1, wins2 = payload
        return (winner in (1, 2) and shots1 <= 64 and shots2 <= 64 and
                sunk1 <= 3 and sunk2 <= 3 and wins1 <= 99 and wins2 <= 99)
    if kind == TYPE_PLACEMENT_START:
        return all(wins <= 99 for wins in payload)
    if kind == TYPE_ERROR:
        rejected, reason = payload
        return reason in ERROR_REASONS and (
            reason == 1 or rejected in (TYPE_PLACE_SHIP, TYPE_SHOT)
        )
    return False


def handle_frame(frame: Frame, state: GameState) -> bool:
    if not valid_notification(frame):
        print("Notificación inválida: se descartó sin modificar el estado.")
        return False
    payload = frame.payload

    if frame.message_type == TYPE_PLACEMENT_START:
        state.p1_wins, state.p2_wins = payload
        print(f"\nNueva partida. Marcador J1 {state.p1_wins} - J2 {state.p2_wins}.")
        state.new_game = state.placement_started
        state.placement_started = True
    elif frame.message_type == TYPE_BATTLE_START:
        print(f"\nLa batalla ha comenzado. Empieza el Jugador {payload[0]}.")
    elif frame.message_type == TYPE_TURN:
        state.current_turn = payload[0]
        print(f"Turno del Jugador {state.current_turn}.")
    elif frame.message_type == TYPE_SHOT_RESULT:
        row, col, result = payload
        if result == 0:
            state.enemy_board[row][col] = "o"
        elif result == 1:
            state.enemy_board[row][col] = "X"
        elif result == 2:
            state.enemy_board[row][col] = "#"
        print(f"Resultado del disparo ({row}, {col}): {SHOT_RESULTS.get(result, 'desconocido')}")
    elif frame.message_type == TYPE_INCOMING_SHOT:
        row, col, result = payload
        state.own_board[row][col] = "o" if result == 0 else ("#" if result == 2 else "X")
        print(f"Disparo recibido en ({row}, {col}): {SHOT_RESULTS.get(result, 'desconocido')}")
    elif frame.message_type == TYPE_GAME_OVER:
        winner, p1_shots, p2_shots, p1_sunk, p2_sunk, p1_wins, p2_wins = payload
        state.game_over = True
        state.p1_wins, state.p2_wins = p1_wins, p2_wins
        print("\nFin de la partida")
        print(f"Ganador: Jugador {winner}")
        print(f"Disparos J1: {p1_shots}   Disparos J2: {p2_shots}")
        print(f"Barcos hundidos por J1: {p1_sunk}   por J2: {p2_sunk}")
        print(f"Marcador: J1 {p1_wins} - J2 {p2_wins}")
    elif frame.message_type == TYPE_ERROR:
        rejected_type, reason = payload
        print(f"La FPGA rechazó la solicitud: {ERROR_REASONS.get(reason, 'razón desconocida')}.")
        if rejected_type == TYPE_SHOT and reason in (ERROR_REPEATED_SHOT, ERROR_INVALID_COORDINATE):
            # El disparo no gastó el turno: el jugador debe volver a disparar.
            state.retry_shot = True
    return True


def check_pending_events(connection: SerialConnection, state: GameState) -> None:
    """Procesa avisos recibidos mientras se ingresaban datos por teclado."""
    for frame in connection.pending():
        handle_frame(frame, state)
        if state.new_game:
            raise NewGame()


def placement_phase(connection: SerialConnection, state: GameState) -> None:
    print("\nFase de colocación del Jugador 2")
    for ship_id, length in SHIP_LENGTHS.items():
        accepted = False
        while not accepted:
            check_pending_events(connection, state)
            print_boards(state)
            print(f"Barco {ship_id} (longitud {length})")
            row = _read_coordinate("Fila inicial")
            col = _read_coordinate("Columna inicial")
            orientation = _read_orientation()
            check_pending_events(connection, state)
            send_place_ship(connection, ship_id, row, col, orientation)

            while True:
                frame = connection.receive()
                if not valid_notification(frame):
                    handle_frame(frame, state)
                    continue
                if frame.message_type == TYPE_ERROR and frame.payload[0] == TYPE_PLACE_SHIP:
                    # Toda solicitud recibe respuesta: un ERROR también la cierra.
                    handle_frame(frame, state)
                    break
                if frame.message_type != TYPE_PLACE_RESULT:
                    handle_frame(frame, state)
                    if state.new_game:
                        raise NewGame()
                    continue
                result_ship, result_accepted, reason = frame.payload
                if result_ship != ship_id:
                    print(f"Respuesta de colocación inesperada para barco {result_ship}.")
                    continue
                accepted = result_accepted == 1
                if accepted:
                    state.placement_started = True
                    _mark_accepted_ship(state, ship_id, row, col, orientation)
                    print("Colocación aceptada por la FPGA.")
                else:
                    print(f"Colocación rechazada: {PLACE_REASONS.get(reason, 'razón desconocida')}.")
                break


def _shoot(connection: SerialConnection, state: GameState) -> None:
    row = _read_coordinate("Fila del disparo")
    col = _read_coordinate("Columna del disparo")
    check_pending_events(connection, state)
    send_shot(connection, row, col)
    # Bloquea nuevos disparos hasta que la FPGA anuncie otro TURN o rechace
    # este disparo sin gastar el turno.
    state.current_turn = 0
    state.retry_shot = False


def battle_phase(connection: SerialConnection, state: GameState) -> None:
    print("\nEsperando eventos de batalla...")
    while not state.game_over:
        frame = connection.receive()
        if not handle_frame(frame, state):
            continue
        if state.new_game:
            raise NewGame()
        print_boards(state)

        if frame.message_type == TYPE_TURN and state.current_turn == 2:
            _shoot(connection, state)
        elif state.retry_shot:
            _shoot(connection, state)


def wait_new_game(connection: SerialConnection, state: GameState) -> None:
    print("\nEsperando una nueva partida (GAME_RST en la FPGA). Ctrl+C para salir.")
    while not state.new_game:
        handle_frame(connection.receive(), state)


def wait_initial_placement(connection: SerialConnection, state: GameState) -> None:
    """Sincroniza la sesión antes de transmitir la primera colocación."""
    print("Esperando inicio de partida. Si la FPGA ya está encendida, pulse BTNC (GAME_RST).")
    while True:
        frame = connection.receive()
        if not handle_frame(frame, state):
            continue
        if frame.message_type == TYPE_PLACEMENT_START:
            return


def _select_port(requested_port: Optional[str]) -> str:
    if requested_port:
        return requested_port

    ports = SerialConnection.available_ports()
    if ports:
        print("Puertos seriales disponibles:")
        for index, port in enumerate(ports, start=1):
            print(f"  {index}. {port}")
        while True:
            selection = input("Seleccione un puerto: ").strip()
            try:
                index = int(selection) - 1
            except ValueError:
                print("Selección inválida.")
                continue
            if 0 <= index < len(ports):
                return ports[index]
            print("Selección fuera de rango.")

    return input("Puerto serial (por ejemplo COM6): ").strip()


def main() -> int:
    parser = argparse.ArgumentParser(description="Terminal de Batalla Naval para el Jugador 2")
    parser.add_argument("port", nargs="?", help="Puerto serial, por ejemplo COM6")
    parser.add_argument("--baudrate", type=int, default=115200)
    args = parser.parse_args()

    connection = SerialConnection(_select_port(args.port), args.baudrate)
    state = GameState()
    try:
        connection.open()
        print(f"Conectado a {connection.port_name} a {connection.baudrate} baud, 8N1.")
        wait_initial_placement(connection, state)
        # Cada vuelta es una partida. J1 puede reiniciarla con GAME_RST en
        # cualquier momento; la FPGA lo anuncia con PLACEMENT_START.
        while True:
            # Se conserva la identificación del inicio; solo se limpian los tableros.
            state.new_game = False
            state.reset_boards()
            try:
                placement_phase(connection, state)
                battle_phase(connection, state)
                wait_new_game(connection, state)
            except NewGame:
                print("J1 reinició la partida.")
    except KeyboardInterrupt:
        print("\nAplicación interrumpida por el usuario.")
    except Exception as exc:
        print(f"Error: {exc}")
        return 1
    finally:
        connection.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
