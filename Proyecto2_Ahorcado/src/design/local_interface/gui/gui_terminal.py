
import os
import string
import threading

import PySimpleGUI as sg
import serial
import serial.tools.list_ports
from PIL import Image

# ==========================================
# 0. CONFIGURACIÓN
# ==========================================
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CABEZA_PATH = os.path.join(BASE_DIR, "cabeza.png")

BAUD_RATE = 115200
ALPHABET = list(string.ascii_uppercase)


# ==========================================
# 1. IMAGEN DE LA CABEZA
# ==========================================
def prepare_head_image():
    if os.path.exists(CABEZA_PATH):
        try:
            with Image.open(CABEZA_PATH) as img:
                if img.size != (60, 60):
                    img_resized = img.resize((60, 60), Image.Resampling.LANCZOS)
                    img_resized.save(CABEZA_PATH)
        except Exception as e:
            print(f"Error al procesar la imagen: {e}")


prepare_head_image()


# ==========================================
# 2. DIBUJO EN EL LIENZO (Visual)
# ==========================================
def draw_gallows(graph):
    graph.erase()
    graph.draw_line((50, 40), (300, 40), color="black", width=4)     # Base
    graph.draw_line((100, 40), (100, 400), color="black", width=4)   # Poste vertical
    graph.draw_line((100, 400), (225, 400), color="black", width=4)  # Viga superior
    graph.draw_line((225, 400), (225, 340), color="black", width=3)  # Cuerda


HANGMAN_PICS = [
    lambda g, c="black": g.draw_image(filename=CABEZA_PATH, location=(195, 340)),
    lambda g, c="black": g.draw_line((225, 280), (225, 170), color=c, width=3),  # Torso
    lambda g, c="black": g.draw_line((225, 250), (180, 200), color=c, width=3),  # Brazo izq
    lambda g, c="black": g.draw_line((225, 250), (270, 200), color=c, width=3),  # Brazo der
    lambda g, c="black": g.draw_line((225, 170), (180, 110), color=c, width=3),  # Pierna izq
    lambda g, c="black": g.draw_line((225, 170), (270, 110), color=c, width=3),  # Pierna der
]

# Los 6 tramos del dibujo corresponden 1 a 1 con el máximo de 6 letras
# incorrectas que exige el enunciado (sección 3.1). errors = tramos a dibujar.
MAX_ERRORS = len(HANGMAN_PICS)


def update_hangman_visuals(graph, errors, game_over=False):
    """Dibuja las partes del cuerpo según la cantidad de errores reportados por la FPGA."""
    draw_gallows(graph)
    color = "red" if game_over else "black"
    errors = max(0, min(errors, len(HANGMAN_PICS)))
    for i in range(errors):
        HANGMAN_PICS[i](graph, color)


def format_pattern(patron: str) -> str:
    """'_A__A__' -> '_ A _ _ A _ _' para que se lea igual que el original."""
    return " ".join(patron) if patron else ""


# ==========================================
# 3. COMUNICACIÓN SERIAL (UART)
# ==========================================
def find_ports():
    return [p.device for p in serial.tools.list_ports.comports()]


def serial_reader(ser: serial.Serial, window: sg.Window, stop_event: threading.Event):
    """
    Corre en un hilo aparte. PySimpleGUI no es seguro para actualizar
    widgets desde otro hilo, así que cada línea recibida se empuja al
    loop de eventos principal con window.write_event_value(), y se
    procesa allí como un evento más.
    """
    while not stop_event.is_set():
        try:
            raw = ser.readline()
        except (serial.SerialException, OSError):
            window.write_event_value("-SERIAL-ERROR-", "Se perdió la conexión con la FPGA.")
            return
        if not raw:
            continue  # timeout de lectura, seguir esperando
        try:
            line = raw.decode("ascii", errors="ignore").strip()
        except Exception:
            continue
        if line:
            window.write_event_value("-SERIAL-LINE-", line)


# ==========================================
# 4. INTERFAZ GRÁFICA (Layout)
# ==========================================
canvas_element = sg.Graph(
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
            disabled=True,  # se habilitan al recibir START de la FPGA
        )
        for letter in ALPHABET[i:i + 6]
    ]
    for i in range(0, len(ALPHABET), 6)
]

right_column = sg.Column(
    letter_grid,
    element_justification="center",
    vertical_alignment="center",
    pad=(30, 10),
)

word_display = sg.Text(
    "Esperando partida...", font=("Helvetica", 30, "bold"), key="-WORD-", pad=(0, 20)
)

status_text = sg.Text(
    "Sin conexión.", font=("Helvetica", 12), key="-STATUS-", text_color="gray", pad=(0, 5)
)

# Solo informativo: la dificultad la decide la FPGA (BTN_SEL/BTN_OK en la
# tarjeta), no la PC. Se actualiza al llegar el mensaje START.
difficulty_label = sg.Text("Modo: —", font=("Helvetica", 12, "bold"), key="-DIFFICULTY-")

connection_row = [
    sg.Text("Puerto:"),
    sg.Combo(find_ports(), key="-PORT-", size=(15, 1), readonly=True),
    sg.Button("Actualizar", key="-REFRESH-"),
    sg.Button("Conectar", key="-CONNECT-"),
    sg.Text("Desconectado", key="-CONN-STATUS-", text_color="red"),
]

action_buttons = [
    sg.Button("Nuevo Juego", key="-NEW-", font=("Helvetica", 12), size=(14, 2), pad=(10, 0)),
    sg.Button("Reiniciar", key="-RESTART-", font=("Helvetica", 12), size=(14, 2), pad=(10, 0)),
    sg.Button("Salir", key="-QUIT-", font=("Helvetica", 12), size=(14, 2), pad=(10, 0)),
]

layout = [
    [sg.VPush()],
    [sg.Push(), sg.Column([connection_row]), sg.Push()],
    [sg.Push(), difficulty_label, sg.Push()],
    [sg.Push(), canvas_element, right_column, sg.Push()],
    [sg.Push(), word_display, sg.Push()],
    [sg.Push(), status_text, sg.Push()],
    [sg.Push(), action_buttons[0], action_buttons[1], action_buttons[2], sg.Push()],
    [sg.VPush()],
]

window = sg.Window("Juego del Ahorcado (Terminal Remota)", layout, resizable=True, finalize=True)
window.maximize()

for letter in ALPHABET:
    window.bind(f"<Key-{letter.lower()}>", f"-LETTER-{letter}-")
    window.bind(f"<Key-{letter.upper()}>", f"-LETTER-{letter}-")

draw_gallows(window["-CANVAS-"])


# ==========================================
# 5. ESTADO DE LA APLICACIÓN
# ==========================================
ser: serial.Serial | None = None
stop_event = threading.Event()
reader_thread: threading.Thread | None = None
game_in_progress = False


def reset_local_view():
    """Limpia SOLO la vista local. No envía nada a la FPGA (ver nota de protocolo arriba)."""
    global game_in_progress
    game_in_progress = False
    draw_gallows(window["-CANVAS-"])
    window["-WORD-"].update("Esperando partida...")
    window["-DIFFICULTY-"].update("Modo: —")
    for l in ALPHABET:
        window[f"-LETTER-{l}-"].update(disabled=True)


def set_status(msg: str, color: str = "gray"):
    window["-STATUS-"].update(msg, text_color=color)


def disconnect_serial():
    global ser, reader_thread
    stop_event.set()
    if reader_thread is not None:
        reader_thread.join(timeout=1)
    if ser is not None:
        try:
            ser.close()
        except Exception:
            pass
    ser = None
    reader_thread = None
    window["-CONN-STATUS-"].update("Desconectado", text_color="red")


# ==========================================
# 6. MANEJO DE MENSAJES DE LA FPGA
# ==========================================
def handle_fpga_line(line: str):
    """Traduce una línea del protocolo FPGA -> PC a actualizaciones de la GUI."""
    global game_in_progress

    fields = line.split(",")
    msg_type = fields[0]

    if msg_type == "START" and len(fields) >= 3:
        modo, longitud_str = fields[1], fields[2]
        try:
            longitud = int(longitud_str)
        except ValueError:
            set_status(f"Trama START mal formada: {line}", "orange")
            return
        game_in_progress = True
        window["-DIFFICULTY-"].update(f"Modo: {modo}")
        window["-WORD-"].update(format_pattern("_" * longitud))
        update_hangman_visuals(window["-CANVAS-"], 0)
        for l in ALPHABET:
            window[f"-LETTER-{l}-"].update(disabled=False)
        set_status("Partida iniciada. Elegí una letra.", "green")

    elif msg_type in ("HIT", "MISS", "REPEAT") and len(fields) >= 3:
        patron, intentos_str = fields[1], fields[2]
        try:
            intentos = int(intentos_str)
        except ValueError:
            set_status(f"Trama {msg_type} mal formada: {line}", "orange")
            return
        errors = MAX_ERRORS - intentos
        window["-WORD-"].update(format_pattern(patron))
        update_hangman_visuals(window["-CANVAS-"], errors)
        if msg_type == "HIT":
            set_status("¡Letra correcta!", "green")
        elif msg_type == "MISS":
            set_status(f"Letra incorrecta. Intentos restantes: {intentos}", "red")
        else:  # REPEAT
            set_status("Esa letra ya se había intentado (no penaliza).", "orange")

    elif msg_type == "WIN" and len(fields) >= 2:
        palabra = fields[1]
        game_in_progress = False
        window["-WORD-"].update(format_pattern(palabra))
        set_status("¡GANASTE!", "green")
        for l in ALPHABET:
            window[f"-LETTER-{l}-"].update(disabled=True)

    elif msg_type == "LOSE_ATTEMPTS" and len(fields) >= 2:
        palabra = fields[1]
        game_in_progress = False
        window["-WORD-"].update(format_pattern(palabra))
        update_hangman_visuals(window["-CANVAS-"], MAX_ERRORS, game_over=True)
        set_status("PERDISTE — se agotaron los intentos.", "red")
        for l in ALPHABET:
            window[f"-LETTER-{l}-"].update(disabled=True)

    elif msg_type == "LOSE_TIME" and len(fields) >= 2:
        palabra = fields[1]
        game_in_progress = False
        window["-WORD-"].update(format_pattern(palabra))
        set_status("PERDISTE — se agotó el tiempo.", "red")
        for l in ALPHABET:
            window[f"-LETTER-{l}-"].update(disabled=True)

    else:
        # Trama desconocida: se reporta sin afectar la partida en curso,
        # igual que el enunciado exige para bytes inválidos en el otro sentido.
        set_status(f"Trama no reconocida: {line}", "orange")


# ==========================================
# 7. BUCLE PRINCIPAL DE EVENTOS
# ==========================================
while True:
    event, values = window.read(timeout=100)

    if event == sg.WIN_CLOSED or event == "-QUIT-":
        break

    elif event == "-REFRESH-":
        window["-PORT-"].update(values=find_ports())

    elif event == "-CONNECT-":
        if ser is not None:
            disconnect_serial()
            set_status("Desconectado manualmente.", "gray")
            continue
        port = values.get("-PORT-")
        if not port:
            set_status("Seleccioná un puerto antes de conectar.", "orange")
            continue
        try:
            ser = serial.Serial(port, BAUD_RATE, timeout=0.1)
        except serial.SerialException as e:
            set_status(f"No se pudo abrir {port}: {e}", "red")
            ser = None
            continue
        stop_event.clear()
        reader_thread = threading.Thread(
            target=serial_reader, args=(ser, window, stop_event), daemon=True
        )
        reader_thread.start()
        window["-CONN-STATUS-"].update(f"Conectado a {port}", text_color="green")
        set_status("Conectado. Esperando a que la FPGA inicie una partida...", "gray")

    elif event in ("-NEW-", "-RESTART-"):
        # No se envía nada por UART: el inicio real de partida lo controla
        # BTN_OK en la tarjeta. Esto solo resincroniza la vista local.
        reset_local_view()
        set_status("Vista local reiniciada. Iniciá la partida desde la FPGA (BTN_OK).", "gray")

    elif event.startswith("-LETTER-"):
        chosen_letter = event.split("-")[2]
        if window[f"-LETTER-{chosen_letter}-"].Disabled:
            continue
        if ser is None:
            set_status("No hay conexión con la FPGA.", "red")
            continue
        if not game_in_progress:
            set_status("No hay una partida activa; la letra sería ignorada por la FPGA.", "orange")
            continue
        try:
            ser.write(chosen_letter.encode("ascii"))
        except (serial.SerialException, OSError) as e:
            set_status(f"Error al enviar la letra: {e}", "red")
            continue
        window[f"-LETTER-{chosen_letter}-"].update(disabled=True)

    elif event == "-SERIAL-LINE-":
        handle_fpga_line(values[event])

    elif event == "-SERIAL-ERROR-":
        set_status(values[event], "red")
        disconnect_serial()

window.close()
disconnect_serial()