"""Terminal serial para el juego Ahorcado ejecutado en la FPGA."""

from __future__ import annotations

import argparse
import sys
import threading

try:
    import serial
except ImportError:  # Se informa al usuario desde main().
    serial = None


DEFAULT_BAUDRATE = 115200
SERIAL_TIMEOUT = 0.1


def receive_messages(serial_port, stop_event: threading.Event) -> None:
    """Lee y muestra mensajes ASCII terminados en LF desde la FPGA."""
    pending_data = bytearray()

    while not stop_event.is_set():
        try:
            received_data = serial_port.readline()
        except (serial.SerialException, OSError) as exc:
            if not stop_event.is_set():
                print(f"\nError de lectura serial: {exc}", file=sys.stderr, flush=True)
            stop_event.set()
            return

        if not received_data:
            continue

        pending_data.extend(received_data)

        while b"\n" in pending_data:
            line, _, remaining_data = pending_data.partition(b"\n")
            pending_data = bytearray(remaining_data)
            message = line.decode("ascii", errors="replace")
            print(f"\nRX <- {message}", flush=True)


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Terminal serial para el Proyecto 2 Ahorcado"
    )
    parser.add_argument("port", help="Puerto serial, por ejemplo COM5")
    parser.add_argument(
        "baudrate",
        nargs="?",
        type=int,
        default=DEFAULT_BAUDRATE,
        help=f"Baudrate de la UART (default: {DEFAULT_BAUDRATE})",
    )
    arguments = parser.parse_args()

    if arguments.baudrate <= 0:
        parser.error("el baudrate debe ser mayor que cero")

    return arguments


def main() -> int:
    arguments = parse_arguments()

    if serial is None:
        print(
            "No se encontro pyserial. Instale las dependencias con "
            "'python -m pip install -r requirements.txt'.",
            file=sys.stderr,
        )
        return 1

    try:
        serial_port = serial.Serial(
            port=arguments.port,
            baudrate=arguments.baudrate,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=SERIAL_TIMEOUT,
            write_timeout=1.0,
        )
    except (serial.SerialException, OSError) as exc:
        print(
            f"No se pudo abrir el puerto {arguments.port}: {exc}",
            file=sys.stderr,
        )
        return 1

    stop_event = threading.Event()
    receive_thread = threading.Thread(
        target=receive_messages,
        args=(serial_port, stop_event),
        name="uart-rx",
        daemon=True,
    )

    print("Ahorcado - Terminal Serial")
    print(f"Puerto: {arguments.port}")
    print(f"Baudrate: {arguments.baudrate}")
    print("Escriba una letra A-Z.")
    print("Escriba Q! para salir.")

    receive_thread.start()

    try:
        while not stop_event.is_set():
            try:
                user_input = input("> ").strip()
            except EOFError:
                print("\nEntrada finalizada.")
                break

            if user_input == "Q!":
                break

            letter = user_input.upper()
            if len(letter) != 1 or not ("A" <= letter <= "Z"):
                print("Entrada invalida. Escriba una sola letra A-Z o Q! para salir.")
                continue

            transmitted_byte = letter.encode("ascii")

            try:
                bytes_written = serial_port.write(transmitted_byte)
            except (serial.SerialException, serial.SerialTimeoutException, OSError) as exc:
                print(f"Error de escritura serial: {exc}", file=sys.stderr)
                stop_event.set()
                break

            if bytes_written != 1:
                print(
                    f"Error de escritura serial: se envio {bytes_written} de 1 byte.",
                    file=sys.stderr,
                )
                stop_event.set()
                break

            print(f"TX -> {letter}")

    except KeyboardInterrupt:
        print("\nTerminal cerrada por el usuario.")
    finally:
        stop_event.set()
        receive_thread.join(timeout=SERIAL_TIMEOUT * 2)

        try:
            serial_port.close()
        except (serial.SerialException, OSError) as exc:
            print(f"Error al cerrar el puerto serial: {exc}", file=sys.stderr)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
