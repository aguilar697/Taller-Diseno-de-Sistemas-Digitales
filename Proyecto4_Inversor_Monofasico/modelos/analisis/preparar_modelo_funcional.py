"""Genera una copia funcional del puente; conserva los modelos de partida.

Añade órdenes con tiempo muerto, Ron constante y medición nominal de corriente.
No representa la compuerta eléctrica, bootstrap, temperatura ni ruido medido.
"""

from pathlib import Path
import re

from verificar_pr_plecs import fin_bloque


CARPETA = Path(__file__).resolve().parents[1]/"plecs"


def parametro(variable, valor):
    return (f'      Parameter {{\n        Variable "{variable}"\n'
            f'        Value "{valor}"\n        Show off\n      }}\n')


def componente(tipo, nombre, x, y, parametros=(), referencia=None):
    bloque = f'    Component {{\n      Type {tipo}\n'
    if referencia:
        bloque += f'      SrcComponent "{referencia}"\n'
    bloque += (f'      Name "{nombre}"\n      Show on\n'
               f'      Position [{x}, {y}]\n      Direction right\n'
               '      Flipped off\n      LabelPosition south\n')
    if referencia:
        bloque += '      Frame [-15, -15; 15, 15]\n'
    elif tipo == "TransferFunction":
        bloque += '      Frame [-35, -15; 35, 15]\n'
    for variable, valor in parametros:
        bloque += parametro(variable, valor)
    if referencia:
        bloque += ('      Terminal {\n        Type Input\n'
                   '        Position [-15, 0]\n        Direction left\n      }\n'
                   '      Terminal {\n        Type Output\n'
                   '        Position [19, 0]\n        Direction right\n      }\n')
        if referencia.endswith("Turn-on Delay"):
            bloque += ('      Terminal {\n        Type Input\n'
                       '        Position [-15, 5]\n        Direction left\n      }\n')
    return bloque+'    }\n'


def conexion(fuente, terminal, destino, entrada):
    return (f'    Connection {{\n      Type Signal\n      SrcComponent "{fuente}"\n'
            f'      SrcTerminal {terminal}\n      DstComponent "{destino}"\n'
            f'      DstTerminal {entrada}\n    }}\n')


def editar_parametro(texto, nombre, variable, valor):
    for match in re.finditer(r'    Component \{\n', texto):
        a = match.start()
        b = fin_bloque(texto, a)
        bloque = texto[a:b]
        if re.search(r'Name\s+"'+re.escape(nombre)+'"', bloque):
            bloque, n = re.subn(r'(Variable\s+"'+re.escape(variable)
                                +r'"\s+Value\s+")[^"]*(")',
                                lambda m: m[1]+valor+m[2], bloque)
            if n != 1:
                raise ValueError((nombre, variable, n))
            return texto[:a]+bloque+texto[b:]
    raise ValueError(nombre)


def medicion():
    # La impedancia de adquisición del XADC no se representa mediante este RC.
    bloques = componente("Gain", "Corriente", 40, 130, (("K", "1"),))
    bloques += componente("TransferFunction", "ACS nominal", 160, 130,
                           (("Numerator", "Sens"),
                            ("Denominator", "[Tau_sensor 1]"), ("X0", "0")))
    bloques += componente("Constant", "Cero sensor", 270, 60, (("Value", "Voffset*Kdiv"),))
    bloques += componente("Sum", "Offset", 270, 130,
                           (("Inputs", "++"), ("IconShape", "2")))
    bloques += componente("Gain", "Divisor", 365, 130, (("K", "Kdiv"),))
    bloques += componente("TransferFunction", "RC evaluacion", 465, 130,
                           (("Numerator", "1"), ("Denominator", "[Tau_adc 1]"),
                            ("X0", "0")))
    bloques += componente("ZeroOrderHold", "Muestreo", 565, 130, (("Ts", "Ts"),))
    bloques += componente("Reference", "ADC 12 bits", 650, 130,
                           (("q", "1/4096"), ("stepDetection", "1")),
                           "Components/Control/Discontinuous/Quantizer")
    bloques += componente("Saturation", "Rango ADC", 730, 130,
                           (("UpperLimit", "4095/4096"), ("LowerLimit", "0")))
    bloques += componente("Constant", "Cero calibrado", 805, 60,
                           (("Value", "Voffset*Kdiv"),))
    bloques += componente("Sum", "Restar cero", 805, 130,
                           (("Inputs", "+-"), ("IconShape", "2")))
    bloques += componente("Gain", "Amperios", 885, 130, (("K", "1/(Kdiv*Sens)"),))
    bloques += componente("Gain", "Corriente ADC", 975, 130, (("K", "1"),))
    for f, ft, d, dt in (("Corriente", 2, "ACS nominal", 1),
                         ("ACS nominal", 2, "Divisor", 1),
                         ("Cero sensor", 1, "Offset", 3),
                         ("Divisor", 2, "RC evaluacion", 1),
                         ("RC evaluacion", 2, "Offset", 2),
                         ("Offset", 1, "Muestreo", 1),
                         ("Muestreo", 2, "ADC 12 bits", 1),
                         ("ADC 12 bits", 2, "Rango ADC", 1),
                         ("Rango ADC", 2, "Restar cero", 2),
                         ("Cero calibrado", 1, "Restar cero", 3),
                         ("Restar cero", 1, "Amperios", 1),
                         ("Amperios", 2, "Corriente ADC", 1)):
        bloques += conexion(f, ft, d, dt)
    # Cadena visible en la parte inferior del esquema principal.
    posiciones = {"Corriente": (120, 830), "ACS nominal": (220, 830),
                  "Divisor": (320, 830), "RC evaluacion": (420, 830),
                  "Cero sensor": (520, 790), "Offset": (520, 830),
                  "Muestreo": (615, 830), "ADC 12 bits": (705, 830),
                  "Rango ADC": (790, 830), "Cero calibrado": (875, 790),
                  "Restar cero": (875, 830), "Amperios": (965, 830),
                  "Corriente ADC": (1055, 830)}
    for nombre, (x, y) in posiciones.items():
        patron = r'(Name "'+re.escape(nombre)+r'"\s+Show on\s+Position )\[[^\]]*\]'
        bloques, n = re.subn(patron, lambda m: m[1]+f'[{x}, {y}]', bloques)
        if n != 1:
            raise ValueError(nombre)
    return bloques
def generar():
    texto = (CARPETA/"proyecto4_pr_discreto.plecs").read_text(encoding="utf-8")
    texto = texto.replace('Name          "proyecto4_pr_discreto"',
                          'Name          "proyecto4_funcional"', 1)
    texto = re.sub(r'(ZoomFactor\s+)\S+', r'\g<1>0.88', texto, count=1)
    extra = (r"\nTmuerto = 1e-6; Ron = 0.044; Sens = 0.185; Voffset = 2.5;"
             r"\nKdiv = 1/5.7; Tau_sensor = 1/(2*pi*80000); Tau_adc = (4700*1000/5700)*10e-9;"
             r"\nIref_final = Iref; T_cambio_ref = 2;")
    texto = texto.replace('Vnorm = 12;"', 'Vnorm = 12;'+extra+'"', 1)
    for nombre in ("FETD", "FETD1", "FETD2", "FETD3"):
        texto = editar_parametro(texto, nombre, "Ron", "Ron")
    # La amplitud se conmuta sin reiniciar la fase de la senoide.
    texto = editar_parametro(texto, "i_ref", "Amplitude", "Iref")
    nuevos = medicion()
    nuevos += componente("Step", "Cambio referencia", 60, 100,
                          (("Time", "T_cambio_ref"), ("Before", "1"),
                           ("After", "Iref_final/Iref"), ("DataType", "10")))
    nuevos += componente("Product", "Referencia aplicada", 115, 150,
                          (("Inputs", "**"),))
    # Reconectar el generador a un producto permite escalones de amplitud.
    for match in re.finditer(r'    Connection \{\n', texto):
        a = match.start()
        b = fin_bloque(texto, a)
        bloque = texto[a:b]
        if re.search(r'SrcComponent\s+"i_ref"', bloque):
            bloque = bloque.replace('SrcComponent  "i_ref"',
                                     'SrcComponent  "Referencia aplicada"')
            texto = texto[:a]+bloque+texto[b:]
            break
    nuevos += conexion("i_ref", 1, "Referencia aplicada", 2)
    nuevos += conexion("Cambio referencia", 1, "Referencia aplicada", 3)
    for nombre, fet, x, y in (("DT A alto", "FETD", 780, 345),
                              ("DT A bajo", "FETD1", 780, 515),
                              ("DT B alto", "FETD2", 1085, 345),
                              ("DT B bajo", "FETD3", 1085, 515)):
        patron = r'(DstComponent\s+")'+fet+r'("\s+DstTerminal\s+3\b)'
        texto, n = re.subn(patron, lambda m: m[1]+nombre+m[2].replace('3', '1'), texto)
        if n != 1:
            raise ValueError((fet, n))
        nuevos += componente("Reference", nombre, x, y,
                              (("DeadTimeSource", "1"), ("T_d", "Tmuerto"),
                               ("Rounding", "1")),
                              "Components/Control/Delays/Turn-on Delay")
        nuevos += conexion(nombre, 2, fet, 3)
    texto, n = re.subn(r'DstComponent\s+"Sum"\s+DstTerminal\s+3',
                       'DstComponent "Corriente"\n          DstTerminal 1', texto)
    if n != 1:
        raise ValueError("Realimentación no identificada.")
    retorno = conexion("Corriente ADC", 2, "Sum", 3).replace(
        '      DstComponent', '      Points [1230, 830; 1230, 930; 185, 930; 185, 250]\n      DstComponent')
    nuevos += retorno
    # El formato PLECS requiere declarar todos los bloques antes de sus cables.
    declarados, cables = [], []
    posicion = 0
    while match := re.search(r'    (Component|Connection) \{', nuevos[posicion:]):
        a = posicion+match.start()
        b = fin_bloque(nuevos, a)
        (declarados if match[1] == "Component" else cables).append(nuevos[a:b]+"\n")
        posicion = b
    nuevos = "".join(declarados+cables)
    texto = texto.replace('    Connection {', nuevos+'    Connection {', 1)
    destino = CARPETA/"proyecto4_funcional.plecs"
    destino.write_text(texto, encoding="utf-8", newline="\n")
    return destino


if __name__ == "__main__":
    print(generar())
