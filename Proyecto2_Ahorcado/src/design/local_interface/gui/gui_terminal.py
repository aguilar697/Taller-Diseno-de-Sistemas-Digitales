import io
import os
import string
import threading

import PySimpleGUI as sg
import serial
import serial.tools.list_ports
from PIL import Image


BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CABEZA_PATH = os.path.join(BASE_DIR, "cabeza.png")

BAUD_RATE = 115200
READ_TIMEOUT = 0.1
WRITE_TIMEOUT = 1.0
ALPHABET = tuple(string.ascii_uppercase)
MAX_ERRORS = 6


def load_head_image_data():
    """Carga y redimensiona la cabeza en memoria sin modificar cabeza.png."""
    if not os.path.exists(CABEZA_PATH):
        return None

    try:
        with Image.open(CABEZA_PATH) as image:
            resized = image.convert("RGBA").resize((60, 60), Image.Resampling.LANCZOS)
            image_buffer = io.BytesIO()
            resized.save(image_buffer, format="PNG")
            return image_buffer.getvalue()
    except (OSError, ValueError) as error:
        print(f"Error al procesar la imagen: {error}")
        return None


HEAD_IMAGE_DATA = load_head_image_data()


def draw_gallows(graph):
    graph.erase()
    graph.draw_line((50, 40), (300, 40), color="black", width=4)
    graph.draw_line((100, 40), (100, 400), color="black", width=4)
    graph.draw_line((100, 400), (225, 400), color="black", width=4)
    graph.draw_line((225, 400), (225, 340), color="black", width=3)


def draw_head(graph, _color="black"):
    if HEAD_IMAGE_DATA is not None:
        graph.draw_image(data=HEAD_IMAGE_DATA, location=(195, 340))
    else:
        graph.draw_circle((225, 310), 30, line_color="black", line_width=3)


HANGMAN_PICS = (
    draw_head,
    lambda graph, color="black": graph.draw_line(
        (225, 280), (225, 170), color=color, width=3
    ),
    lambda graph, color="black": graph.draw_line(
        (225, 250), (180, 200), color=color, width=3
    ),
    lambda graph, color="black": graph.draw_line(
        (225, 250), (270, 200), color=color, width=3
    ),
    lambda graph, color="black": graph.draw_line(
        (225, 170), (180, 110), color=color, width=3
    ),
    lambda graph, color="black": graph.draw_line(
        (225, 170), (270, 110), color=color, width=3
    ),
)


def update_hangman_visuals(graph, errors, game_over=False):
    """Dibuja los errores a partir del valor de intentos recibido de la FPGA."""
    draw_gallows(graph)
    color = "red" if game_over else "black"
    errors = max(0, min(errors, len(HANGMAN_PICS)))
    for picture in HANGMAN_PICS[:errors]:
        picture(graph, color)


def format_pattern(pattern):
    return " ".join(pattern) if pattern else ""


def find_ports():
    return [port.device for port in serial.tools.list_ports.comports()]


def serial_reader(serial_port, window, stop_event):
    """Recibe líneas LF en un hilo y las entrega al bucle gráfico principal."""
    while not stop_event.is_set():
        try:
            raw_line = serial_port.readline()
        except (serial.SerialException, OSError):
            if not stop_event.is_set():
                try:
                    window.write_event_value(
                        "-SERIAL-ERROR-", "Se perdió la conexión con la FPGA."
                    )
                except Exception:
                    pass
            return

        if not raw_line:
            continue

        if raw_line.endswith(b"\n"):
            raw_line = raw_line[:-1]

        if not raw_line:
            continue

        line = raw_line.decode("ascii", errors="replace")
        try:
            window.write_event_value("-SERIAL-LINE-", line)
        except Exception:
            return


def build_window():
    canvas = sg.Graph(
        canvas_size=(350, 450),
        graph_bottom_left=(0, 0),
        graph_top_right=(350, 450),
        key="-CANVAS-",
        background_color="white",
        pad=(30, 10),
    )

    letter_grid = [
        [
            sg.Button(
                letter,
                key=f"-LETTER-{letter}-",
                size=(5, 2),
                font=("Helvetica", 12, "bold"),
                disabled=True,
            )
            for letter in ALPHABET[index:index + 6]
        ]
        for index in range(0, len(ALPHABET), 6)
    ]

    connection_row = [
        sg.Text("Puerto:"),
        sg.Combo(find_ports(), key="-PORT-", size=(15, 1), readonly=True),
        sg.Button("Actualizar", key="-REFRESH-"),
        sg.Button("Conectar", key="-CONNECT-"),
        sg.Text("Desconectado", key="-CONN-STATUS-", text_color="red"),
    ]

    game_information = [
        sg.Text("Modo: -", font=("Helvetica", 12, "bold"), key="-DIFFICULTY-"),
        sg.Text("Longitud: -", font=("Helvetica", 12, "bold"), key="-LENGTH-"),
        sg.Text(
            "Intentos restantes: -",
            font=("Helvetica", 12, "bold"),
            key="-ATTEMPTS-",
        ),
    ]

    layout = [
        [sg.VPush()],
        [sg.Push(), sg.Column([connection_row]), sg.Push()],
        [sg.Push(), *game_information, sg.Push()],
        [
            sg.Push(),
            canvas,
            sg.Column(
                letter_grid,
                element_justification="center",
                vertical_alignment="center",
                pad=(30, 10),
            ),
            sg.Push(),
        ],
        [
            sg.Push(),
            sg.Text(
                "Esperando partida...",
                font=("Helvetica", 30, "bold"),
                key="-WORD-",
                pad=(0, 20),
            ),
            sg.Push(),
        ],
        [
            sg.Push(),
            sg.Text(
                "Sin conexión.",
                font=("Helvetica", 12),
                key="-STATUS-",
                text_color="gray",
                pad=(0, 5),
            ),
            sg.Push(),
        ],
        [
            sg.Push(),
            sg.Button("Salir", key="-QUIT-", font=("Helvetica", 12), size=(14, 2)),
            sg.Push(),
        ],
        [sg.VPush()],
    ]

    window = sg.Window(
        "Juego del Ahorcado (Terminal Remota)",
        layout,
        resizable=True,
        finalize=True,
    )
    window.maximize()

    for letter in ALPHABET:
        window.bind(f"<Key-{letter.lower()}>", f"-LETTER-{letter}-")
        window.bind(f"<Key-{letter.upper()}>", f"-LETTER-{letter}-")

    draw_gallows(window["-CANVAS-"])
    return window


def main():
    window = build_window()

    serial_port = None
    stop_event = None
    reader_thread = None

    game_in_progress = False
    awaiting_response = False
    used_letters = set()
    current_word_length = None

    def set_status(message, color="gray"):
        window["-STATUS-"].update(message, text_color=color)

    def refresh_keyboard():
        connected = serial_port is not None and serial_port.is_open
        can_send = connected and game_in_progress and not awaiting_response
        for letter in ALPHABET:
            window[f"-LETTER-{letter}-"].update(
                disabled=(not can_send or letter in used_letters)
            )

    def disconnect_serial(update_window=True):
        nonlocal serial_port, stop_event, reader_thread, awaiting_response

        if stop_event is not None:
            stop_event.set()
        if reader_thread is not None:
            reader_thread.join(timeout=1.0)
        if serial_port is not None:
            try:
                serial_port.close()
            except (serial.SerialException, OSError):
                pass

        serial_port = None
        stop_event = None
        reader_thread = None
        awaiting_response = False

        if update_window:
            window["-CONN-STATUS-"].update("Desconectado", text_color="red")
            window["-CONNECT-"].update("Conectar")
            refresh_keyboard()

    def protocol_error():
        set_status("Error de protocolo", "red")

    def handle_fpga_line(line):
        nonlocal game_in_progress, awaiting_response, current_word_length

        fields = line.split(",")
        message_type = fields[0] if fields else ""

        if message_type == "START":
            if len(fields) != 3 or fields[1] not in ("EASY", "HARD"):
                protocol_error()
                return
            try:
                word_length = int(fields[2])
            except ValueError:
                protocol_error()
                return
            if not 4 <= word_length <= 12:
                protocol_error()
                return

            used_letters.clear()
            awaiting_response = False
            game_in_progress = True
            current_word_length = word_length

            window["-DIFFICULTY-"].update(f"Modo: {fields[1]}")
            window["-LENGTH-"].update(f"Longitud: {word_length}")
            window["-ATTEMPTS-"].update("Intentos restantes: -")
            window["-WORD-"].update(format_pattern("_" * word_length))
            update_hangman_visuals(window["-CANVAS-"], 0)
            set_status("Partida iniciada. Elige una letra.", "green")
            refresh_keyboard()
            return

        if message_type in ("HIT", "MISS", "REPEAT"):
            if len(fields) != 3 or not game_in_progress:
                protocol_error()
                return

            revealed_word = fields[1]
            try:
                attempts_left = int(fields[2])
            except ValueError:
                protocol_error()
                return

            valid_pattern = all(
                character in string.ascii_uppercase or character == "_"
                for character in revealed_word
            )
            if (
                not 0 <= attempts_left <= MAX_ERRORS
                or not valid_pattern
                or len(revealed_word) != current_word_length
            ):
                protocol_error()
                return

            awaiting_response = False
            window["-WORD-"].update(format_pattern(revealed_word))
            window["-ATTEMPTS-"].update(f"Intentos restantes: {attempts_left}")
            update_hangman_visuals(
                window["-CANVAS-"], MAX_ERRORS - attempts_left
            )

            if message_type == "HIT":
                set_status("¡Letra correcta!", "green")
            elif message_type == "MISS":
                set_status("Letra incorrecta", "red")
            else:
                set_status("Letra repetida", "orange")

            refresh_keyboard()
            return

        if message_type in ("WIN", "LOSE_ATTEMPTS", "LOSE_TIME"):
            if len(fields) != 2 or not game_in_progress:
                protocol_error()
                return

            final_word = fields[1]
            if (
                len(final_word) != current_word_length
                or not final_word
                or not all(character in string.ascii_uppercase for character in final_word)
            ):
                protocol_error()
                return

            awaiting_response = False
            game_in_progress = False
            window["-WORD-"].update(format_pattern(final_word))

            if message_type == "WIN":
                set_status("¡Ganaste!", "green")
            elif message_type == "LOSE_ATTEMPTS":
                update_hangman_visuals(
                    window["-CANVAS-"], MAX_ERRORS, game_over=True
                )
                set_status("Perdiste: se agotaron los intentos", "red")
            else:
                set_status("Perdiste: se acabó el tiempo", "red")

            refresh_keyboard()
            return

        protocol_error()

    while True:
        event, values = window.read(timeout=100)

        if event in (sg.WIN_CLOSED, "-QUIT-"):
            break

        if event == "-REFRESH-":
            window["-PORT-"].update(values=find_ports())

        elif event == "-CONNECT-":
            if serial_port is not None:
                disconnect_serial()
                set_status("Desconectado manualmente.", "gray")
                continue

            port_name = values.get("-PORT-")
            if not port_name:
                set_status("Selecciona un puerto antes de conectar.", "orange")
                continue

            try:
                serial_port = serial.Serial(
                    port=port_name,
                    baudrate=BAUD_RATE,
                    bytesize=serial.EIGHTBITS,
                    parity=serial.PARITY_NONE,
                    stopbits=serial.STOPBITS_ONE,
                    timeout=READ_TIMEOUT,
                    write_timeout=WRITE_TIMEOUT,
                )
            except (serial.SerialException, OSError) as error:
                set_status(f"No se pudo abrir {port_name}: {error}", "red")
                serial_port = None
                continue

            stop_event = threading.Event()
            reader_thread = threading.Thread(
                target=serial_reader,
                args=(serial_port, window, stop_event),
                daemon=True,
            )
            reader_thread.start()
            window["-CONN-STATUS-"].update(
                f"Conectado a {port_name}", text_color="green"
            )
            window["-CONNECT-"].update("Desconectar")
            set_status("Conectado. Esperando START desde la FPGA...", "gray")
            refresh_keyboard()

        elif isinstance(event, str) and event.startswith("-LETTER-"):
            chosen_letter = event.split("-")[2]
            connected = serial_port is not None and serial_port.is_open
            if (
                not connected
                or not game_in_progress
                or awaiting_response
                or chosen_letter in used_letters
            ):
                continue

            encoded_letter = chosen_letter.encode("ascii")
            try:
                bytes_written = serial_port.write(encoded_letter)
            except (serial.SerialException, OSError) as error:
                set_status(f"Error al enviar la letra: {error}", "red")
                continue

            if bytes_written != 1:
                set_status("Error al enviar la letra: no se escribió un byte.", "red")
                continue

            used_letters.add(chosen_letter)
            awaiting_response = True
            refresh_keyboard()
            set_status(f"TX -> {chosen_letter}. Esperando respuesta...", "gray")

        elif event == "-SERIAL-LINE-":
            handle_fpga_line(values[event])

        elif event == "-SERIAL-ERROR-":
            set_status(values[event], "red")
            disconnect_serial()

    disconnect_serial(update_window=False)
    window.close()


if __name__ == "__main__":
    main()
