"""Candidato PR muestreado: Tustin preajustado a 50 Hz y planta RL con ZOH.

El modelo promediado excluye rizado PWM, sensor, tiempo muerto y saturación
magnética. El retardo representa períodos completos entre cálculo y aplicación.
"""

import cmath
import math
import struct


TS = 100e-6
KP = 12.0
KR = 200.0
F0 = 50.0
WC = 2 * math.pi * 2
V_NORMALIZACION = 12.0


def coeficientes(ts=TS):
    """Devuelve b0, b1, b2, a1, a2 de la rama resonante, con a0=1."""
    if not 0 < ts < 1 / (2 * F0):
        raise ValueError("El muestreo debe superar la frecuencia de Nyquist.")
    w0 = 2 * math.pi * F0
    k = w0 / math.tan(w0 * ts / 2)
    d0 = k * k + 2 * WC * k + w0 * w0
    b0 = 2 * KR * WC * k / d0
    return b0, 0.0, -b0, 2 * (w0 * w0 - k * k) / d0, (
        k * k - 2 * WC * k + w0 * w0
    ) / d0


def float32(x):
    """Redondea un valor como un coeficiente almacenado en float de 32 bits."""
    return struct.unpack("f", struct.pack("f", x))[0]


def controlador(f, ts=TS, coef=None):
    b0, b1, b2, a1, a2 = coef or coeficientes(ts)
    q = cmath.exp(-2j * math.pi * f * ts)
    return KP + (b0 + b1 * q + b2 * q * q) / (1 + a1 * q + a2 * q * q)


def schur_estable(p):
    """Comprueba raíces estrictamente dentro del círculo unidad por recursión.

    Los coeficientes reales están ordenados en potencias descendentes de z.
    Se elimina un grado usando el polinomio reflejado en cada iteración.
    """
    p = list(p)
    while len(p) > 1:
        if p[0] == 0 or abs(p[-1]) >= abs(p[0]):
            return False
        p = [v / p[0] for v in p]
        r = p[-1]
        p = [p[i] - r * p[-1-i] for i in range(len(p)-1)]
    return p[0] != 0


def evaluar(r, l, vdc, retardo=1, ts=TS, coef=None):
    """Estabilidad lineal cerrada y seguimiento de referencia a 50 Hz."""
    if min(r, l, vdc) <= 0 or retardo < 0 or int(retardo) != retardo:
        raise ValueError("Parámetros de planta o retardo no válidos.")
    b0, b1, b2, a1, a2 = coef or coeficientes(ts)
    a = math.exp(-r * ts / l)
    b = -math.expm1(-r * ts / l) / r * vdc / V_NORMALIZACION
    # (1-Aq)D(q) + B*q**(1+retardo)*N_control(q), con q=z**-1.
    p = [1.0, a1-a, a2-a*a1, -a*a2] + [0.0] * retardo
    for j, n in enumerate((KP+b0, KP*a1+b1, KP*a2+b2)):
        p[j+1+retardo] += b*n
    q = cmath.exp(-2j * math.pi * F0 * ts)
    lazo = b * q**(1+retardo) / (1-a*q) * controlador(F0, ts, coef)
    t = lazo / (1+lazo)
    return schur_estable(p), abs(t), math.degrees(cmath.phase(t))


def simular(amplitud=.5, r=7.2, l=.01, vdc=12.0, retardo=1,
            ts=TS, duracion=1.0, limite=.85):
    """Integra exactamente la planta promediada por intervalo de retención.

    La rama resonante se actualiza sin anti-windup. Los casos aceptados deben
    permanecer sin saturación; no se usa este ensayo para validar su recuperación.
    """
    if int(retardo) != retardo or retardo < 0 or min(r, l, ts) <= 0:
        raise ValueError("Parámetros de simulación no válidos.")
    b0, b1, b2, a1, a2 = coeficientes(ts)
    a = math.exp(-r*ts/l)
    b = -math.expm1(-r*ts/l)/r
    i = e1 = e2 = y1 = y2 = 0.0
    cola = [0.0]*retardo
    registro = []
    for k in range(round(duracion/ts)):
        t = k*ts
        ref = amplitud * math.sin(2*math.pi*F0*t)
        e = ref-i
        y = b0*e+b1*e1+b2*e2-a1*y1-a2*y2
        orden = (KP*e+y)/V_NORMALIZACION
        m = max(-limite, min(limite, orden))
        cola.append(m)
        aplicada = cola.pop(0)
        registro.append((t, ref, i, m, abs(orden) > limite))
        i = a*i+b*vdc*aplicada
        e2, e1, y2, y1 = e1, e, y1, y
    return registro


def fundamental(registro, ts=TS, periodos=5):
    """Extrae seno/coseno sobre un número entero de períodos de régimen."""
    n = round(periodos/(F0*ts))
    if len(registro) < n:
        raise ValueError("La ventana no contiene los períodos solicitados.")
    ventana = registro[-n:]
    s = 2/n * sum(row[2]*math.sin(2*math.pi*F0*row[0]) for row in ventana)
    c = 2/n * sum(row[2]*math.cos(2*math.pi*F0*row[0]) for row in ventana)
    return math.hypot(s, c), math.degrees(math.atan2(c, s))


def main():
    print("Candidato: Ts=100 us, retardo=1 Ts, normalizacion fija de 12 V")
    print("b0,b1,b2,a1,a2:", ", ".join(f"{x:.16g}" for x in coeficientes()))
    print("R_total_ohm,L_H,Vdc_V,estable,ganancia_50Hz,fase_grados")
    casos = []
    for r in (7.2, 10.5):
        for l in (.006984, .009291, .010):
            for v in (12, 24):
                caso = evaluar(r, l, v)
                casos.append(caso)
                print(f"{r},{l},{v},{caso[0]},{caso[1]:.9f},{caso[2]:.6f}")
    if not all(ok and .9 <= g <= 1.1 for ok, g, _ in casos):
        raise SystemExit("El candidato no cumple el barrido lineal.")
    print("12 casos lineales estables; comprobar tambien la simulacion conmutada.")
    for v in (12, 24):
        for ref in (.2, .5, 1.0):
            datos = simular(amplitud=ref, vdc=v)
            amp, fase = fundamental(datos)
            saturadas = sum(row[4] for row in datos)
            print(f"Promediado: Vdc={v}, Iref={ref}, I1={amp:.6f} A, "
                  f"fase={fase:.3f} grados, muestras saturadas={saturadas}")
            if saturadas or not .9 <= amp/ref <= 1.1:
                raise SystemExit("Revisar seguimiento o saturacion.")


if __name__ == "__main__":
    main()
