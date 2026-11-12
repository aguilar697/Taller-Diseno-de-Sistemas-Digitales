"""Contrasta el PR ideal y la copia funcional con ensayos acotados en PLECS.

Requiere PLECS abierto con RPC local habilitado. Usa copias temporales y
conserva únicamente métricas y trazas resumidas de los transitorios.
"""

import argparse
import csv
import hashlib
import json
import math
from pathlib import Path
import tempfile
import xmlrpc.client

from verificar_pr_plecs import instrumentar


PROYECTO = Path(__file__).resolve().parents[2]
PLECS = PROYECTO/"modelos/plecs"


def fundamental(tiempo, valores, inicio=.4, fin=.5):
    datos = [(t, v) for t, v in zip(tiempo, valores) if inicio <= t < fin-1e-10]
    if len(datos) < 100:
        raise ValueError("Ventana insuficiente.")
    n = len(datos)
    s = 2/n*sum(v*math.sin(2*math.pi*50*t) for t, v in datos)
    c = 2/n*sum(v*math.cos(2*math.pi*50*t) for t, v in datos)
    return math.hypot(s, c), math.degrees(math.atan2(c, s))


def metricas(resultado, ref):
    tiempo = resultado["Time"]
    valores = resultado["Values"]
    amp, fase = fundamental(tiempo, valores[1])
    return {"fundamental_a_pico": amp, "fase_grados": fase,
            "error_amplitud_porcentaje": 100*(amp/ref-1),
            "pico_corriente_total_a": max(map(abs, valores[1])),
            "modulacion_max_abs": max(map(abs, valores[2]))}


def comprobar_ordenes(valores, paso):
    """Detecta solapamiento, actividad y huecos completos entre órdenes."""
    huecos = []
    for alto, bajo in ((valores[0], valores[1]), (valores[2], valores[3])):
        cuenta = 0
        iniciado = False
        for a, b in zip(alto, bajo):
            if a < .5 and b < .5:
                if iniciado:
                    cuenta += 1
            else:
                if cuenta:
                    huecos.append(cuenta*paso)
                iniciado = True
                cuenta = 0
    return {"muestras_con_solapamiento": sum(a*b > .5 or c*d > .5
                                             for a, b, c, d in zip(*valores)),
            "actividad_en_las_cuatro_ordenes": all(max(v) > .5 and min(v) < .5
                                                   for v in valores),
            "huecos_completos": len(huecos),
            "hueco_minimo_muestreado_s": min(huecos) if huecos else None}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--puerto", type=int, default=1080)
    parser.add_argument("--salida", type=Path, default=PROYECTO/"build/potencia/lazo_funcional")
    args = parser.parse_args()
    args.salida.mkdir(parents=True, exist_ok=True)
    proxy = xmlrpc.client.ServerProxy(f"http://localhost:{args.puerto}")
    informe = {"motor": "PLECS Standalone 5.0", "ts_s": .0001,
               "pwm_hz": 10000, "retardo_periodos": 1,
               "ventana_fundamental_s": [.4, .5], "paso_exportacion_s": 2e-6,
               "modelos_sha256": {}, "casos": [],
               "hipotesis_funcional": {"ron_ohm": .044, "tiempo_muerto_s": 1e-6,
                   "sensor_sensibilidad_v_a": .185, "sensor_offset_v": 2.5,
                   "sensor_polo_hz": 80000, "divisor": [4700, 1000],
                   "c_adc_evaluacion_f": 10e-9, "adc_bits": 12,
                   "cero_calibrado": "Promedio ideal de 2,5 V/5,7; sin error ni deriva"},
               "exclusiones": ["ruido medido", "dispersión del sensor y fuente de 5 V",
                   "temperatura", "bootstrap y VGS", "parásitos", "pérdidas de conmutación",
                   "caída directa y recuperación de diodos", "saturación magnética",
                   "cuantización Q1.15 de la actuación", "anti-windup"]}
    with tempfile.TemporaryDirectory(prefix="ensayo_lazo_") as carpeta:
        for funcional in (False, True):
            base = "proyecto4_funcional" if funcional else "proyecto4_pr_discreto"
            archivo = PLECS/(base+".plecs")
            nombre = "ensayo_lazo_funcional" if funcional else "ensayo_lazo_ideal"
            fuentes = ("Referencia aplicada" if funcional else "i_ref", "Am1", "Saturation")
            if funcional:
                fuentes += ("Corriente ADC",)
            texto = archivo.read_text(encoding="utf-8")
            informe["modelos_sha256"][base] = hashlib.sha256(archivo.read_bytes()).hexdigest()
            copia = Path(carpeta)/(nombre+".plecs")
            copia.write_text(instrumentar(texto, fuentes, nombre), encoding="utf-8")
            proxy.plecs.load(str(copia))
            try:
                escenarios = []
                if funcional:
                    escenarios += [(f"nominal_{v}V_{a}A", {"Vbus": v, "Iref": a}, a)
                                   for v in (12, 24) for a in (.2, .5, 1.)]
                    escenarios += [("referencia_02_05", {"Iref": .2, "Iref_final": .5,
                                    "T_cambio_ref": .205}, .5),
                                   ("referencia_05_10", {"Iref": .5, "Iref_final": 1.,
                                    "T_cambio_ref": .205}, 1.)]
                escenarios += [("carga_66_99", {"Iref": .5, "T_cambio_R": .205}, .5)]
                for etiqueta, variables, ref_final in escenarios:
                    # Iref_final debe coincidir con Iref en casos sin escalón.
                    if funcional:
                        variables.setdefault("Iref_final", variables["Iref"])
                    r = proxy.plecs.simulate(nombre, {
                        "ModelVars": variables,
                        "SolverOpts": {"TimeSpan": .5, "Timeout": 60,
                                       "OutputTimes": [k*2e-6 for k in range(250001)]}})
                    caso = {"modelo": base, "ensayo": etiqueta,
                            "variables": variables, **metricas(r, ref_final)}
                    if funcional:
                        t = r["Time"]
                        errores = [m-i for t0, i, m in zip(t, r["Values"][1], r["Values"][3])
                                   if .4 <= t0 < .5]
                        caso["error_medicion_rms_a"] = math.sqrt(sum(e*e for e in errores)/len(errores))
                    informe["casos"].append(caso)
                    print(f"{base}: {etiqueta}: I1={caso['fundamental_a_pico']:.5f} A, "
                          f"error={caso['error_amplitud_porcentaje']:.2f}%", flush=True)
                    if not etiqueta.startswith("nominal"):
                        ruta = args.salida/(base+"_"+etiqueta+".csv")
                        with ruta.open("w", newline="", encoding="utf-8") as f:
                            writer = csv.writer(f)
                            writer.writerow(["tiempo_s", "referencia_a", "corriente_a", "modulacion"]
                                            +(["medida_a"] if funcional else []))
                            # Solo trazas ilustrativas; no se usan para medir rizado.
                            for k in range(0, len(r["Time"]), 50):
                                writer.writerow([r["Time"][k]]+[v[k] for v in r["Values"]])
            finally:
                proxy.plecs.close(nombre)
        # Comprobación temporal de órdenes en diez períodos PWM ya establecidos.
        nombre = "ensayo_compuertas"
        texto = (PLECS/"proyecto4_funcional.plecs").read_text(encoding="utf-8")
        fuentes = ("DT A alto", "DT A bajo", "DT B alto", "DT B bajo")
        copia = Path(carpeta)/(nombre+".plecs")
        copia.write_text(instrumentar(texto, fuentes, nombre), encoding="utf-8")
        proxy.plecs.load(str(copia))
        try:
            r = proxy.plecs.simulate(nombre, {"SolverOpts": {"TimeSpan": .101,
                "OutputTimes": [k*1e-7 for k in range(1000000, 1010001)]}})
            ordenes = comprobar_ordenes(r["Values"], 1e-7)
            informe["ordenes"] = {"ventana_s": [.1, .101], "paso_s": 1e-7,
                                  **ordenes,
                                  "alcance": "Órdenes lógicas, no tensiones VGS"}
        finally:
            proxy.plecs.close(nombre)
    (args.salida/"resultados.json").write_text(
        json.dumps(informe, ensure_ascii=False, indent=2)+"\n", encoding="utf-8")
    if (any(abs(c["error_amplitud_porcentaje"]) > 10 for c in informe["casos"])
            or ordenes["muestras_con_solapamiento"]
            or not ordenes["actividad_en_las_cuatro_ordenes"]
            or (ordenes["hueco_minimo_muestreado_s"] or 0) < .8e-6):
        raise SystemExit("Un ensayo requiere revisión; consultar resultados.json.")


if __name__ == "__main__":
    main()
