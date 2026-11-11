"""Análisis reproducible del rizado PWM unipolar en una carga RL ideal.

La planta se integra exactamente entre conmutaciones. La excitación se obtiene
de la tensión sinusoidal requerida, sin controlador PR ni dispositivos reales.
El cálculo solo requiere la biblioteca estándar; las figuras usan Matplotlib.
"""

from __future__ import annotations

import argparse
import csv
import json
import math
from dataclasses import asdict, dataclass
from pathlib import Path


@dataclass(frozen=True)
class Caso:
    vdc: float
    inductancia: float
    frecuencia_pwm: float
    corriente_pico: float
    resistencia_externa: float = 6.8
    resistencia_devanado: float = 1.0
    frecuencia_referencia: float = 50.0

    @property
    def resistencia_total(self) -> float:
        return self.resistencia_externa + self.resistencia_devanado


def evolucion(i0: float, tension: float, duracion: float, r: float, l: float) -> float:
    """Solución de L di/dt + R i = v para tensión constante y R, L positivas."""
    return i0 + (tension / r - i0) * (-math.expm1(-r * duracion / l))


def integral_cuadrado(i0: float, tension: float, duracion: float,
                      r: float, l: float) -> float:
    """Integral temporal de i² para calcular RMS sin muestreo de la onda."""
    a = tension / r
    b = i0 - a
    k = r / l
    valor = (a * a * duracion + 2 * a * b * (-math.expm1(-k * duracion)) / k
             + b * b * (-math.expm1(-2 * k * duracion)) / (2 * k))
    return max(0.0, valor)


def segmentos(m: float, periodo: float, vdc: float) -> list[tuple[float, float]]:
    """Pares duración/tensión para portadora triangular común y referencia fija.

    Los cinco intervalos son cero, activo, cero, activo, cero. Su tensión media
    es Vdc*m. No representan el tiempo muerto ni la conducción de los diodos.
    """
    if not -1.0 <= m <= 1.0:
        raise ValueError("Referencia fuera del intervalo lineal [-1, 1].")
    a = abs(m)
    activo = math.copysign(vdc, m)
    candidatos = [((1-a)*periodo/4, 0.0), (a*periodo/2, activo),
                  ((1-a)*periodo/2, 0.0), (a*periodo/2, activo),
                  ((1-a)*periodo/4, 0.0)]
    return [(dt, v) for dt, v in candidatos if dt > 0.0]


def modulacion(caso: Caso, tiempo: float) -> float:
    """Tensión requerida por la senoide, muestreada al inicio de cada período."""
    w = 2 * math.pi * caso.frecuencia_referencia
    return caso.corriente_pico * (
        caso.resistencia_total * math.sin(w * tiempo)
        + w * caso.inductancia * math.cos(w * tiempo)) / caso.vdc


def rizado_estacionario(m: float, vdc: float, r: float, l: float, fs: float) -> float:
    """Rizado exacto con m constante y régimen periódico, sin cambio sinusoidal."""
    a = abs(m)
    q = r / (2 * l * fs)
    return (vdc / r * (-math.expm1(-q * a)) * (-math.expm1(-q * (1-a)))
            / (-math.expm1(-q)))


def simular(caso: Caso, ciclos_asentamiento: int = 5,
            ciclos_medida: int = 5) -> dict:
    r, l = caso.resistencia_total, caso.inductancia
    if min(r, l, caso.vdc, caso.frecuencia_pwm, caso.frecuencia_referencia) <= 0:
        raise ValueError("R, L, Vdc y frecuencias deben ser positivas.")
    if ciclos_asentamiento < 0 or ciclos_medida < 1 or caso.corriente_pico < 0:
        raise ValueError("Número de ciclos o amplitud no válidos.")
    relacion = caso.frecuencia_pwm / caso.frecuencia_referencia
    if not math.isclose(relacion, round(relacion), abs_tol=1e-10):
        raise ValueError("El barrido requiere períodos fundamentales completos.")
    por_ciclo = round(relacion)
    inicio = ciclos_asentamiento * por_ciclo
    total = inicio + ciclos_medida * por_ciclo
    periodo = 1 / caso.frecuencia_pwm
    v_requerida = caso.corriente_pico * math.hypot(
        r, 2 * math.pi * caso.frecuencia_referencia * l)
    if v_requerida / caso.vdc > 1:
        raise ValueError("El caso necesita sobremodulación; no se recorta silenciosamente.")
    i_sw = i_avg = 0.0
    max_rizado = max_corriente = integral_i2 = 0.0
    peor = None
    for n in range(total):
        t = n * periodo
        m = modulacion(caso, t)
        v_avg = caso.vdc * m
        i_inicio, avg_inicio = i_sw, i_avg
        residuos = [i_sw - i_avg]
        extremos = [abs(i_sw)]
        for dt, v in segmentos(m, periodo, caso.vdc):
            if n >= inicio:
                integral_i2 += integral_cuadrado(i_sw, v, dt, r, l)
            i_sw = evolucion(i_sw, v, dt, r, l)
            i_avg = evolucion(i_avg, v_avg, dt, r, l)
            residuos.append(i_sw - i_avg)
            extremos.append(abs(i_sw))
        # En cada segmento el residuo satisface otra ecuación RL con entrada
        # constante. Es monótono: sus extremos están en los extremos temporales.
        if n >= inicio:
            rizado = max(residuos) - min(residuos)
            if peor is None or rizado > max_rizado:
                max_rizado = rizado
                peor = {"tiempo_s": t, "i_sw_a": i_inicio, "i_avg_a": avg_inicio}
            max_corriente = max(max_corriente, *extremos)
    return {
        "vdc_v": caso.vdc, "l_h": l, "f_pwm_hz": caso.frecuencia_pwm,
        "i_referencia_pico_a": caso.corriente_pico,
        "r_externa_ohm": caso.resistencia_externa,
        "r_devanado_ohm": caso.resistencia_devanado,
        "v_requerida_pico_v": v_requerida,
        "m_requerida_pico": v_requerida / caso.vdc,
        "rizado_residuo_max_pp_a": max_rizado,
        "envolvente_m_constante_pp_a": caso.vdc / r * math.tanh(r / (8*l*caso.frecuencia_pwm)),
        "cota_lineal_m_constante_pp_a": caso.vdc / (8*l*caso.frecuencia_pwm),
        "i_total_rms_a": math.sqrt(integral_i2 / (ciclos_medida / caso.frecuencia_referencia)),
        "i_total_pico_abs_a": max_corriente,
        "tiempo_peor_periodo_s": peor["tiempo_s"],
        "_peor": peor,
    }


def traza(caso: Caso, resultado: dict, periodos: int = 4,
          puntos_por_segmento: int = 16) -> list[dict]:
    estado = resultado["_peor"]
    t0 = tiempo = estado["tiempo_s"]
    i_sw, i_avg = estado["i_sw_a"], estado["i_avg_a"]
    puntos = []
    periodo = 1 / caso.frecuencia_pwm
    for n in range(periodos):
        m = modulacion(caso, t0 + n * periodo)
        for duracion, tension in segmentos(m, periodo, caso.vdc):
            for j in range(puntos_por_segmento + 1):
                dt = duracion * j / puntos_por_segmento
                corriente = evolucion(i_sw, tension, dt, caso.resistencia_total, caso.inductancia)
                promedio = evolucion(i_avg, caso.vdc*m, dt, caso.resistencia_total, caso.inductancia)
                puntos.append({"tiempo_s": tiempo+dt, "tiempo_local_s": tiempo+dt-t0,
                               "v_ab_v": tension, "i_conmutada_a": corriente,
                               "i_promediada_a": promedio, "residuo_a": corriente-promedio})
            i_sw = evolucion(i_sw, tension, duracion, caso.resistencia_total, caso.inductancia)
            i_avg = evolucion(i_avg, caso.vdc*m, duracion, caso.resistencia_total, caso.inductancia)
            tiempo += duracion
    return puntos


def escribir_csv(ruta: Path, filas: list[dict]) -> None:
    campos = [k for k in filas[0] if not k.startswith("_")]
    with ruta.open("w", encoding="utf-8", newline="") as archivo:
        writer = csv.DictWriter(archivo, fieldnames=campos, extrasaction="ignore")
        writer.writeheader()
        writer.writerows(filas)


def figuras(salida: Path, filas: list[dict], onda: list[dict]) -> None:
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    matplotlib.rcParams["svg.fonttype"] = "none"
    matplotlib.rcParams["svg.hashsalt"] = "Proyecto4-rizado-rl"
    fig, ejes = plt.subplots(1, 2, figsize=(11, 4.6), sharey=True, layout="constrained")
    for ax, vdc in zip(ejes, (12.0, 24.0)):
        for l, color, desfase in ((.0047, "#2366a4", -.18), (.01, "#d87520", .18)):
            valores = [1000*max(row["rizado_residuo_max_pp_a"] for row in filas
                       if row["vdc_v"] == vdc and row["l_h"] == l and row["f_pwm_hz"] == fs
                       and row["r_externa_ohm"] == 6.8 and row["r_devanado_ohm"] == 1)
                       for fs in (10000., 20000., 25000.)]
            barras = ax.bar([x+desfase for x in range(3)], valores, .34,
                            label=f"L = {l*1000:g} mH", color=color)
            ax.bar_label(barras, fmt="%.1f", fontsize=9)
        ax.axhline(200, color="#ac3030", linestyle="--", label="Criterio: 200 mA p-p")
        ax.set(title=f"Bus DC de {vdc:g} V", xlabel="Frecuencia PWM por transistor [kHz]",
               xticks=range(3), xticklabels=["10", "20", "25"], ylim=(0, 225))
        ax.grid(axis="y", alpha=.2)
    ejes[0].set_ylabel("Rizado máximo del residuo [mA p-p]")
    ejes[1].legend(loc="upper right", fontsize=8)
    fig.suptitle("PWM unipolar ideal — R externa 6,8 Ω; R devanado supuesta 1 Ω\n"
                 "Máximo entre referencias de 0,2; 0,5 y 1 A pico")
    fig.savefig(salida/"comparacion_rizado.svg", metadata={"Date": None})
    plt.close(fig)
    fig, ejes = plt.subplots(3, 1, figsize=(10, 7), sharex=True, layout="constrained")
    tiempo = [p["tiempo_local_s"]*1e6 for p in onda]
    ejes[0].plot(tiempo, [p["v_ab_v"] for p in onda], color="#555555")
    ejes[0].set_ylabel("v_AB [V]")
    ejes[1].plot(tiempo, [p["i_conmutada_a"] for p in onda], label="Planta conmutada")
    ejes[1].plot(tiempo, [p["i_promediada_a"] for p in onda], "--", label="Planta promediada")
    ejes[1].set_ylabel("Corriente [A]")
    ejes[1].legend(fontsize=9)
    ejes[2].plot(tiempo, [p["residuo_a"]*1000 for p in onda], color="#d87520")
    ejes[2].set(ylabel="Residuo [mA]", xlabel="Tiempo desde el inicio de la ventana [µs]")
    for ax in ejes:
        ax.grid(alpha=.25)
    fig.suptitle("Ejemplo ideal: 24 V, 4,7 mH, 10 kHz, referencia de 1 A pico\n"
                 "R externa 6,8 Ω; R devanado supuesta 1 Ω; sin PR ni tiempo muerto")
    fig.savefig(salida/"ventana_rizado.svg", metadata={"Date": None})
    plt.close(fig)


def main() -> None:
    proyecto = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--salida", type=Path, default=proyecto/"build/potencia/rizado")
    parser.add_argument("--graficas", action="store_true", help="Generar figuras SVG con Matplotlib.")
    args = parser.parse_args()
    filas = []
    ejemplo = None
    for vdc in (12., 24.):
        for l in (.0047, .01):
            for fs in (10000., 20000., 25000.):
                for rw in (.5, 1., 3.):
                    for rext, ipk in ((6.8, .2), (6.8, .5), (6.8, 1.), (8.5, .5)):
                        caso = Caso(vdc, l, fs, ipk, rext, rw)
                        resultado = simular(caso)
                        filas.append(resultado)
                        if caso == Caso(24., .0047, 10000., 1.):
                            ejemplo = caso, resultado
    args.salida.mkdir(parents=True, exist_ok=True)
    escribir_csv(args.salida/"barrido_rizado.csv", filas)
    onda = traza(*ejemplo)
    escribir_csv(args.salida/"ventana_rizado.csv", onda)
    condiciones = {
        "modelo": "Puente H ideal, PWM unipolar centrado y planta RL lineal",
        "metodo": "Integración exponencial exacta por segmento de tensión constante",
        "excitación": "Tensión requerida por una senoide; referencia retenida desde el inicio del período PWM",
        "metrica": "Máximo por período PWM de pico-pico(i_conmutada - i_promediada)",
        "frecuencia_referencia_hz": 50, "ciclos_asentamiento": 5, "ciclos_medida": 5,
        "numero_casos": len(filas), "caso_figura_ventana": asdict(ejemplo[0]),
        "exclusiones": ["PR", "cuantización digital", "tiempo muerto", "caídas de semiconductores",
                        "saturación magnética", "sensor y ADC", "tolerancias y ruido"],
    }
    (args.salida/"condiciones.json").write_text(
        json.dumps(condiciones, indent=2, ensure_ascii=False)+"\n", encoding="utf-8")
    if args.graficas:
        figuras(args.salida, filas, onda)
    maximo = max(filas, key=lambda row: row["rizado_residuo_max_pp_a"])
    print(f"Casos evaluados: {len(filas)}")
    print(f"Máximo del residuo: {maximo['rizado_residuo_max_pp_a']:.9f} A pico a pico")
    print(f"Resultados: {args.salida.resolve()}")


if __name__ == "__main__":
    main()
