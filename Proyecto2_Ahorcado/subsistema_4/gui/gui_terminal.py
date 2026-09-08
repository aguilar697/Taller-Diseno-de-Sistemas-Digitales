import os
import string
import PySimpleGUI as sg
from PIL import Image

# Rutas absolutas
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CABEZA_PATH = os.path.join(BASE_DIR, "cabeza.png")

# Redimensionar la imagen a 60x60 px
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
# 1. DIBUJO EN EL LIENZO (Visual)
# ==========================================
def draw_gallows(graph):
    graph.erase()
    graph.draw_line((50, 40), (300, 40), color="black", width=4)    # Base
    graph.draw_line((100, 40), (100, 400), color="black", width=4)   # Poste vertical
    graph.draw_line((100, 400), (225, 400), color="black", width=4) # Viga superior
    graph.draw_line((225, 400), (225, 340), color="black", width=3) # Cuerda

HANGMAN_PICS = [
    lambda g, c="black": g.draw_image(filename=CABEZA_PATH, location=(195, 340)),
    lambda g, c="black": g.draw_line((225, 280), (225, 170), color=c, width=3),      # Torso
    lambda g, c="black": g.draw_line((225, 250), (180, 200), color=c, width=3),      # Brazo izq
    lambda g, c="black": g.draw_line((225, 250), (270, 200), color=c, width=3),      # Brazo der
    lambda g, c="black": g.draw_line((225, 170), (180, 110), color=c, width=3),      # Pierna izq
    lambda g, c="black": g.draw_line((225, 170), (270, 110), color=c, width=3),      # Pierna der
]

def update_hangman_visuals(graph, errors, game_over=False):
    """Dibuja las partes del cuerpo según la cantidad de errores indicados por la FPGA."""
    draw_gallows(graph)
    color = "red" if game_over else "black"
    
    for i in range(min(errors, len(HANGMAN_PICS))):
        HANGMAN_PICS[i](graph, color)

# ==========================================
# 2. INTERFAZ GRÁFICA (Layout)
# ==========================================
canvas_element = sg.Graph(
    canvas_size=(350, 450),
    graph_bottom_left=(0, 0),
    graph_top_right=(350, 450),
    key="-CANVAS-",
    background_color="white",
    pad=(30, 10)
)

alphabet = list(string.ascii_uppercase)
letter_grid = [
    [sg.Button(letter, key=f"-LETTER-{letter}-", size=(5, 2), font=("Helvetica", 12, "bold")) for letter in alphabet[i:i+6]]
    for i in range(0, len(alphabet), 6)
]

right_column = sg.Column(
    letter_grid, 
    element_justification="center", 
    vertical_alignment="center",
    pad=(30, 10)
)

# Se inicializa con guiones, la FPGA actualizará esto luego.
word_display = sg.Text("_ _ _ _ _ _ _", font=("Helvetica", 36, "bold"), key="-WORD-", pad=(0, 20))

difficulty_selector = [
    sg.Text("Dificultad:", font=("Helvetica", 12, "bold")),
    sg.Combo(["Fácil", "Difícil"], default_value="Fácil", key="-DIFFICULTY-", font=("Helvetica", 11), readonly=True, size=(10, 1))
]

action_buttons = [
    sg.Button("Nuevo Juego", key="-NEW-", font=("Helvetica", 12), size=(14, 2), pad=(10, 0)),
    sg.Button("Reiniciar", key="-RESTART-", font=("Helvetica", 12), size=(14, 2), pad=(10, 0)),
    sg.Button("Salir", key="-QUIT-", font=("Helvetica", 12), size=(14, 2), pad=(10, 0))
]

layout = [
    [sg.VPush()],
    [sg.Push(), sg.Column([difficulty_selector], pad=(0, 10)), sg.Push()],
    [sg.Push(), canvas_element, right_column, sg.Push()],
    [sg.Push(), word_display, sg.Push()],
    [sg.Push(), action_buttons[0], action_buttons[1], action_buttons[2], sg.Push()],
    [sg.VPush()]
]

window = sg.Window("Juego del Ahorcado (Terminal Remota)", layout, resizable=True, finalize=True)
window.maximize()

for letter in alphabet:
    window.bind(f"<Key-{letter.lower()}>", f"-LETTER-{letter}-")
    window.bind(f"<Key-{letter.upper()}>", f"-LETTER-{letter}-")

# ==========================================
# 3. BUCLE PRINCIPAL DE EVENTOS
# ==========================================
draw_gallows(window["-CANVAS-"])

while True:
    event, values = window.read()
    
    if event == sg.WIN_CLOSED or event == "-QUIT-":
        break
        
    if event == "-NEW-" or event == "-RESTART-":
        # TODO: Enviar comando de inicio a la FPGA vía UART
        print(f"[PC -> FPGA]: Iniciar Juego. Dificultad: {values['-DIFFICULTY-']}")
        
        # Reset visual local
        draw_gallows(window["-CANVAS-"])
        window["-WORD-"].update("_ _ _ _ _ _ _")
        for letter in alphabet:
            window[f"-LETTER-{letter}-"].update(disabled=False)
            
    if event.startswith("-LETTER-"):
        chosen_letter = event.split("-")[2]
        
        if not window[f"-LETTER-{chosen_letter}-"].Disabled:
            # Apagamos el botón localmente para feedback visual
            window[f"-LETTER-{chosen_letter}-"].update(disabled=True)
            
            # TODO: Enviar el carácter 'chosen_letter' a la FPGA vía UART
            print(f"[PC -> FPGA]: Letra enviada '{chosen_letter}'")

window.close()