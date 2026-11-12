"""Ensaya seis puntos nominales en PLECS por su interfaz XML-RPC local.

Instrumenta una copia temporal con salidas de registro. No modifica el modelo
del repositorio ni cambia las preferencias de PLECS. Requiere RPC habilitado.
"""

import argparse
import hashlib
import json
import math
from pathlib import Path
import re
import tempfile
import xmlrpc.client


MODELO = Path(__file__).resolve().parents[1]/"plecs/proyecto4_pr_discreto.plecs"
NOMBRE = "ensayo_pr_discreto"


def fin_bloque(texto, inicio):
    """Localiza la llave final respetando las cadenas y sus escapes."""
    profundidad = 1
    i = texto.index("{", inicio)+1
    cadena = escape = False
    while profundidad:
        c = texto[i]
        if cadena:
            if escape:
                escape = False
            elif c == "\\":
                escape = True
            elif c == '"':
                cadena = False
        elif c == '"':
            cadena = True
        elif c == "{":
            profundidad += 1
        elif c == "}":
            profundidad -= 1
        i += 1
    return i


def instrumentar(texto, fuentes=("i_ref", "Am1", "Saturation"), nombre=NOMBRE):
    texto = re.sub(r'(\bName\s+")[^"]*(")',
                   lambda m: m[1]+nombre+m[2], texto, count=1)
    terminales = ""
    for indice, fuente in enumerate(fuentes, 1):
        nombre = f"Registro{indice}"
        for match in re.finditer(r"    Connection \{\n", texto):
            a = match.start()
            b = fin_bloque(texto, a)
            bloque = texto[a:b]
            if (re.search(r"Type\s+Signal", bloque)
                    and re.search(r'SrcComponent\s+"'+fuente+'"', bloque)):
                cabecera = re.search(r"SrcTerminal\s+\d+\n", bloque).end()
                nuevo = (bloque[:cabecera]+"      Branch {\n"+bloque[cabecera:-5]
                         +'      }\n      Branch {\n        DstComponent "'
                         +nombre+'"\n        DstTerminal 1\n      }\n    }')
                texto = texto[:a]+nuevo+texto[b:]
                break
        else:
            raise ValueError(f"No se encontró la salida de {fuente}.")
        componente = f'''    Component {{
      Type Output
      Name "{nombre}"
      Show on
      Position [1450, {110+60*indice}]
      Direction right
      Flipped off
      LabelPosition south
      Parameter {{
        Variable "Index"
        Value "{indice}"
        Show on
      }}
      Parameter {{
        Variable "Width"
        Value "1"
        Show off
      }}
    }}
'''
        texto = texto.replace("    Connection {", componente+"    Connection {", 1)
        terminales += f'  Terminal {{\n    Type Output\n    Index "{indice}"\n  }}\n'
    return texto.replace("  Schematic {", terminales+"  Schematic {", 1)


def medir(resultado):
    # Se excluye el extremo final: [0,4; 0,5) s contiene cinco períodos.
    tiempo = resultado["Time"][:-1]
    _, corriente, modulacion = [fila[:-1] for fila in resultado["Values"]]
    if len(tiempo) != 100000:
        raise ValueError("Ventana de salida incompleta.")
    n = len(tiempo)
    seno = 2/n*sum(i*math.sin(2*math.pi*50*t) for t, i in zip(tiempo, corriente))
    coseno = 2/n*sum(i*math.cos(2*math.pi*50*t) for t, i in zip(tiempo, corriente))
    return {"fundamental_a_pico": math.hypot(seno, coseno),
            "fase_grados": math.degrees(math.atan2(coseno, seno)),
            "corriente_max_abs_a": max(map(abs, corriente)),
            "modulacion_max_abs": max(map(abs, modulacion))}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--puerto", type=int, default=1080)
    parser.add_argument("--salida", type=Path, default=MODELO.parents[2]/
                        "build/potencia/pr_discreto_plecs.json")
    args = parser.parse_args()
    proxy = xmlrpc.client.ServerProxy(f"http://localhost:{args.puerto}")
    informe = {"modelo": MODELO.name,
               "sha256_modelo": hashlib.sha256(MODELO.read_bytes()).hexdigest(),
               "motor": "PLECS Standalone 5.0",
               "ts_s": .0001, "retardo_periodos": 1,
               "r_total_ohm": 7.2, "l_h": .010, "normalizacion_v": 12,
               "ventana_s": [.4, .5], "paso_exportacion_s": 1e-6,
               "metodo": "Proyección seno/coseno a 50 Hz sobre cinco períodos",
               "exclusiones": ["sensor y ADC", "tiempo muerto y driver",
                                "pérdidas", "saturación magnética", "anti-windup"],
               "casos": []}
    with tempfile.TemporaryDirectory(prefix="pr_discreto_") as carpeta:
        archivo = Path(carpeta)/f"{NOMBRE}.plecs"
        archivo.write_text(instrumentar(MODELO.read_text(encoding="utf-8")),
                           encoding="utf-8")
        proxy.plecs.load(str(archivo))
        try:
            for vbus in (12, 24):
                for referencia in (.2, .5, 1.0):
                    resultado = proxy.plecs.simulate(NOMBRE, {
                        "ModelVars": {"Vbus": vbus, "Iref": referencia},
                        "SolverOpts": {"TimeSpan": .5, "OutputTimes":
                                       [k*1e-6 for k in range(400000, 500001)]}})
                    caso = {"bus_v": vbus, "referencia_a_pico": referencia,
                            **medir(resultado)}
                    caso["error_amplitud_porcentaje"] = 100*(
                        caso["fundamental_a_pico"]/referencia-1)
                    informe["casos"].append(caso)
                    print(f"{vbus} V, {referencia} A: "
                          f"I1={caso['fundamental_a_pico']:.6f} A, "
                          f"error={caso['error_amplitud_porcentaje']:.3f}%", flush=True)
        finally:
            proxy.plecs.close(NOMBRE)
    args.salida.parent.mkdir(parents=True, exist_ok=True)
    args.salida.write_text(json.dumps(informe, ensure_ascii=False, indent=2)+"\n",
                           encoding="utf-8")
    if any(abs(c["error_amplitud_porcentaje"]) > 10
           or c["modulacion_max_abs"] >= .85 for c in informe["casos"]):
        raise SystemExit("Revisar seguimiento o saturación en los casos nominales.")


if __name__ == "__main__":
    main()
