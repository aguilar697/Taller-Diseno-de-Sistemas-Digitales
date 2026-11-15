"""Receptor y análisis de la trama de exportación.

Uso:
    python receptor.py --puerto COM5            # trama desde la tarjeta
    python receptor.py --archivo trama.bin      # trama guardada
"""

import argparse
import cmath
import csv
import math
import struct
import sys

# Constantes de la trama
SINC = b"\xA5\x5A"
ENCABEZADO = 28
MUESTRA = 8
F_REF = 50.0
PERIODOS_MIN = 5

ESTADOS = {0: "INICIO", 1: "DETENIDO", 2: "OPERACIÓN", 3: "FALLA"}
CAUSAS = {0: "sobrecorriente", 1: "código fuera de rango", 2: "muestras anómalas",
          3: "exceso de tiempo", 4: "configuración"}


class TramaInvalida(Exception):
    """Trama incompleta, sin sincronismo o con CRC incorrecto."""


def crc16(datos, crc=0xFFFF):
    """CRC-16/CCITT-FALSE."""
    for byte in datos:
        crc ^= byte << 8
        for _ in range(8):
            crc = ((crc << 1) ^ 0x1021) if crc & 0x8000 else (crc << 1)
            crc &= 0xFFFF
    return crc


def decodificar(datos):
    """Busca el sincronismo, valida largo y CRC."""
    inicio = datos.find(SINC)
    if inicio < 0:
        raise TramaInvalida("no se encontró el sincronismo 0xA5 0x5A")
    datos = datos[inicio:]
    if len(datos) < ENCABEZADO + 2:
        raise TramaInvalida("trama cortada: falta el encabezado")

    (version, estado, f_sw, ts_ns, k_reg, n, amplitud_ma, causa,
     t_isr_max, perdidas) = struct.unpack_from("<BBIIHHHHII", datos, 2)
    largo = ENCABEZADO + MUESTRA * n + 2
    if len(datos) < largo:
        raise TramaInvalida(f"trama cortada: {len(datos)} de {largo} bytes")

    crc_recibido = struct.unpack_from("<H", datos, largo - 2)[0]
    if crc16(datos[2:largo - 2]) != crc_recibido:
        raise TramaInvalida("CRC incorrecto")

    muestras = [struct.unpack_from("<hhhH", datos, ENCABEZADO + MUESTRA * i) for i in range(n)]
    return {
        "version": version, "estado": estado, "f_sw": f_sw, "ts_ns": ts_ns,
        "k_reg": k_reg, "n": n, "amplitud_ma": amplitud_ma, "causa": causa,
        "t_isr_max": t_isr_max, "perdidas": perdidas,
        "i_med": [m[0] / 1000.0 for m in muestras],
        "i_ref": [m[1] / 1000.0 for m in muestras],
        "m": [m[2] / 32768.0 for m in muestras],
        "num": [m[3] for m in muestras],
        "bytes": bytes(datos[:largo]),
    }


def fundamental(x, muestras_por_periodo):
    """Componente de 50 Hz: amplitud pico y fase."""
    acum = sum(v * cmath.exp(-2j * math.pi * k / muestras_por_periodo) for k, v in enumerate(x))
    return 2.0 * abs(acum) / len(x), cmath.phase(acum)


def analizar(trama, n_pwm_por_control=1):
    """Error de amplitud, desfase y residuo en períodos enteros."""
    t_reg = trama["k_reg"] * trama["ts_ns"] * 1e-9
    por_periodo = 1.0 / (F_REF * t_reg)
    periodos = int(trama["n"] // por_periodo)
    if periodos < PERIODOS_MIN:
        raise TramaInvalida(f"solo {periodos} períodos de 50 Hz; hacen falta {PERIODOS_MIN}")

    # Períodos completos más recientes
    cuantas = int(round(periodos * por_periodo))
    i_med = trama["i_med"][-cuantas:]
    i_ref = trama["i_ref"][-cuantas:]
    num = trama["num"][-cuantas:]

    amp_med, fase_med = fundamental(i_med, por_periodo)
    amp_ref, fase_ref = fundamental(i_ref, por_periodo)
    if amp_ref == 0.0:
        raise TramaInvalida("la referencia es cero: no hay ensayo que analizar")

    desfase = math.degrees(fase_med - fase_ref)
    desfase = (desfase + 180.0) % 360.0 - 180.0

    residuo = [v - amp_med * math.cos(2 * math.pi * k / por_periodo + fase_med)
               for k, v in enumerate(i_med)]
    salto = trama["k_reg"] * n_pwm_por_control
    faltantes = sum(1 for a, b in zip(num, num[1:]) if (b - a) % 65536 != salto)

    error = (amp_med - amp_ref) / amp_ref
    return {
        "periodos": periodos, "amp_med": amp_med, "amp_ref": amp_ref,
        "error": error, "desfase": desfase,
        "residuo_rms": math.sqrt(sum(r * r for r in residuo) / len(residuo)),
        "saltos_de_n": faltantes, "cumple": abs(error) <= 0.10,
    }


def guardar(trama, prefijo):
    """Archivos .bin y .csv."""
    with open(prefijo + ".bin", "wb") as f:
        f.write(trama["bytes"])
    t_reg = trama["k_reg"] * trama["ts_ns"] * 1e-9
    with open(prefijo + ".csv", "w", newline="", encoding="utf-8") as f:
        w = csv.writer(f)
        w.writerow([f"# f_sw={trama['f_sw']} Hz", f"Ts={trama['ts_ns']} ns",
                    f"K_REG={trama['k_reg']}", f"amplitud={trama['amplitud_ma']} mA",
                    f"estado={ESTADOS.get(trama['estado'], '?')}",
                    f"causa=0x{trama['causa']:04X}", f"t_isr_max={trama['t_isr_max']} ciclos",
                    f"perdidas={trama['perdidas']}"])
        w.writerow(["t_s", "i_med_A", "i_ref_A", "m", "n"])
        for k in range(trama["n"]):
            w.writerow([f"{k * t_reg:.6f}", trama["i_med"][k], trama["i_ref"][k],
                        f"{trama['m'][k]:.5f}", trama["num"][k]])


def recibir(puerto, baudios, espera_s):
    """Lectura del puerto serie hasta completar una trama."""
    import serial  # pylint: disable=import-outside-toplevel

    with serial.Serial(puerto, baudios, timeout=espera_s) as s:
        datos = bytearray()
        while SINC not in datos:
            byte = s.read(1)
            if not byte:
                raise TramaInvalida("tiempo de espera agotado sin sincronismo")
            datos += byte
            datos = datos[-2:]
        datos = bytearray(SINC) + s.read(ENCABEZADO - 2)
        n = struct.unpack_from("<H", datos, 14)[0]
        datos += s.read(MUESTRA * n + 2)
        return bytes(datos)


def describir_causa(causa):
    """Nombres de los bits de causa."""
    nombres = [CAUSAS[b] for b in CAUSAS if causa & (1 << b)]
    return ", ".join(nombres) if nombres else "ninguna"


def main(argv=None):
    """Recepción, reporte y gráfica."""
    p = argparse.ArgumentParser(description="Receptor de la trama del Proyecto 4")
    origen = p.add_mutually_exclusive_group(required=True)
    origen.add_argument("--puerto", help="puerto serie, por ejemplo COM5")
    origen.add_argument("--archivo", help="trama guardada en binario")
    p.add_argument("--baudios", type=int, default=115200)
    p.add_argument("--espera", type=float, default=30.0, help="segundos de espera por la trama")
    p.add_argument("--salida", default="ensayo", help="prefijo de los archivos .bin y .csv")
    p.add_argument("--n-pwm", type=int, default=1, help="N_PWM_POR_CONTROL")
    p.add_argument("--graficar", action="store_true")
    a = p.parse_args(argv)

    try:
        if a.puerto:
            datos = recibir(a.puerto, a.baudios, a.espera)
        else:
            with open(a.archivo, "rb") as f:
                datos = f.read()
        trama = decodificar(datos)
    except TramaInvalida as e:
        print(f"Trama rechazada: {e}")
        return 1

    if a.puerto:
        guardar(trama, a.salida)
        print(f"Guardado en {a.salida}.bin y {a.salida}.csv")

    print(f"Estado: {ESTADOS.get(trama['estado'], '?')}   "
          f"causa de falla: {describir_causa(trama['causa'])}")
    print(f"f_sw = {trama['f_sw']} Hz   Ts = {trama['ts_ns']} ns   K_REG = {trama['k_reg']}   "
          f"N = {trama['n']}   amplitud = {trama['amplitud_ma']} mA")
    print(f"t_isr_max = {trama['t_isr_max']} ciclos ({trama['t_isr_max'] / 100.0:.2f} us)   "
          f"conversiones perdidas = {trama['perdidas']}")

    try:
        r = analizar(trama, a.n_pwm)
    except TramaInvalida as e:
        print(f"Sin análisis: {e}")
        return 0

    print(f"Fundamental sobre {r['periodos']} períodos: medida {r['amp_med']:.4f} A, "
          f"referencia {r['amp_ref']:.4f} A")
    veredicto = "cumple" if r["cumple"] else "NO cumple"
    print(f"Error de amplitud {100 * r['error']:+.2f} %  ({veredicto} <= 10 %)   "
          f"desfase {r['desfase']:+.2f} grados")
    print(f"Residuo de baja frecuencia: {1000 * r['residuo_rms']:.1f} mA rms   "
          f"saltos en n: {r['saltos_de_n']}")

    if a.graficar:
        try:
            import matplotlib.pyplot as plt  # pylint: disable=import-outside-toplevel
        except ImportError:
            print("matplotlib no está instalado: sin gráfica")
            return 0
        t_reg = trama["k_reg"] * trama["ts_ns"] * 1e-9
        t = [k * t_reg * 1000 for k in range(trama["n"])]
        plt.plot(t, trama["i_ref"], label="i_ref")
        plt.plot(t, trama["i_med"], label="i_med")
        plt.xlabel("t (ms)")
        plt.ylabel("corriente (A)")
        plt.legend()
        plt.grid(True)
        plt.show()
    return 0


if __name__ == "__main__":
    sys.exit(main())
