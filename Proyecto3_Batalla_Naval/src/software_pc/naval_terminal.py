"""Terminal serial del Jugador 2 para Batalla Naval."""

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

EXPECTED_LENGTHS = {
    TYPE_PLACE_SHIP: 4,
    TYPE_SHOT: 2,
    TYPE_PLACE_RESULT: 3,
    TYPE_BATTLE_START: 0,
    TYPE_TURN: 1,
    TYPE_SHOT_RESULT: 3,
    TYPE_INCOMING_SHOT: 3,
    TYPE_GAME_OVER: 3,
}

SHIP_LENGTHS = {0: 4, 1: 3, 2: 2}
PLACE_REASONS = {
    0: "OK",
    1: "overlap",
    2: "out_of_bounds",
    3: "invalid_data",
}
SHOT_RESULTS = {0: "miss", 1: "hit", 2: "sunk", 3: "repeated"}


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

    def __init__(self) -> None:
        self._state = self.WAIT_SOF
        self._message_type = 0
        self._expected_length = 0
        self._payload = bytearray()

    def reset(self) -> None:
        self._state = self.WAIT_SOF
        self._message_type = 0
        self._expected_length = 0
        self._payload.clear()

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
        frames = []
        for value in data:
            frame = self.feed_byte(value)
            if frame is not None:
                frames.append(frame)
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


def send_place_ship(
    connection: SerialConnection, ship_id: int, row: int, col: int,
    orientation: int
) -> None:
    connection.send(TYPE_PLACE_SHIP, (ship_id, row, col, orientation))


def send_shot(connection: SerialConnection, row: int, col: int) -> None:
    connection.send(TYPE_SHOT, (row, col))


def print_boards(state: GameState) -> None:
    print("\n      TABLERO PROPIO                 TABLERO RIVAL")
    print("    " + " ".join(map(str, range(8))) + "         " + " ".join(map(str, range(8))))
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


def handle_frame(frame: Frame, state: GameState) -> None:
    payload = frame.payload

    if frame.message_type == TYPE_BATTLE_START:
        print("\nLa batalla ha comenzado.")
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
        winner, p1_shots, p2_shots = payload
        state.game_over = True
        print("\nFin de la partida")
        print(f"Ganador: Jugador {winner}")
        print(f"Disparos J1: {p1_shots}")
        print(f"Disparos J2: {p2_shots}")


def placement_phase(connection: SerialConnection, state: GameState) -> None:
    print("\nFase de colocación del Jugador 2")
    for ship_id, length in SHIP_LENGTHS.items():
        accepted = False
        while not accepted:
            print_boards(state)
            print(f"Barco {ship_id} (longitud {length})")
            row = _read_coordinate("Fila inicial")
            col = _read_coordinate("Columna inicial")
            orientation = _read_orientation()
            send_place_ship(connection, ship_id, row, col, orientation)

            while True:
                frame = connection.receive()
                if frame.message_type != TYPE_PLACE_RESULT:
                    handle_frame(frame, state)
                    continue
                result_ship, result_accepted, reason = frame.payload
                if result_ship != ship_id:
                    print(f"Respuesta de colocación inesperada para barco {result_ship}.")
                    continue
                accepted = result_accepted == 1
                if accepted:
                    _mark_accepted_ship(state, ship_id, row, col, orientation)
                    print("Colocación aceptada por la FPGA.")
                else:
                    print(f"Colocación rechazada: {PLACE_REASONS.get(reason, 'razón desconocida')}.")
                break


def battle_phase(connection: SerialConnection, state: GameState) -> None:
    print("\nEsperando eventos de batalla...")
    while not state.game_over:
        frame = connection.receive()
        handle_frame(frame, state)
        print_boards(state)

        if frame.message_type == TYPE_TURN and state.current_turn == 2:
            row = _read_coordinate("Fila del disparo")
            col = _read_coordinate("Columna del disparo")
            send_shot(connection, row, col)
            # Bloquea nuevos disparos hasta que la FPGA anuncie otro TURN.
            state.current_turn = 0


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
        placement_phase(connection, state)
        battle_phase(connection, state)
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
