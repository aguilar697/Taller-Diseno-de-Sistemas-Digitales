"""Comprobación lineal del candidato PR continuo; no simula el PWM ni retardos."""

import cmath
import math


KP = 12.0
KR = 200.0
W0 = 2 * math.pi * 50
WC = 2 * math.pi * 2
V_NORMALIZACION = 12.0


def evaluar(resistencia, inductancia, vdc):
    """Aplica Routh al cúbico cerrado y evalúa el seguimiento a 50 Hz."""
    alfa = vdc / V_NORMALIZACION
    b = 2 * KR * WC
    coeficientes = (
        inductancia,
        2 * inductancia * WC + resistencia + alfa * KP,
        inductancia * W0**2 + 2 * resistencia * WC
        + alfa * (2 * KP * WC + b),
        (resistencia + alfa * KP) * W0**2,
    )
    a3, a2, a1, a0 = coeficientes
    estable = min(coeficientes) > 0 and a2 * a1 > a3 * a0
    s = 1j * W0
    controlador = KP + b * s / (s * s + 2 * WC * s + W0**2)
    lazo = alfa * controlador / (resistencia + inductancia * s)
    seguimiento = lazo / (1 + lazo)
    return estable, abs(seguimiento), math.degrees(cmath.phase(seguimiento))


def main():
    print("PR continuo: Kp=12 V/A, Kr=200 V/A, f0=50 Hz, fc_res=2 Hz")
    print("Numerador resonante:", [2 * KR * WC, 0])
    print("Denominador resonante:", [1, 2 * WC, W0**2])
    print("R_total_ohm,L_H,Vdc_V,estable_Routh,amplitud_relativa_50Hz,fase_grados")
    resultados = []
    for resistencia in (7.6, 9.8):
        for inductancia in (.00423, .0047, .00517):
            for vdc in (12, 18, 24):
                estable, amplitud, fase = evaluar(resistencia, inductancia, vdc)
                resultados.append((estable, amplitud, fase))
                print(f"{resistencia},{inductancia},{vdc},{estable},{amplitud:.9f},{fase:.6f}")
    if not all(estable and .9 <= amplitud <= 1.1
               for estable, amplitud, _ in resultados):
        raise SystemExit("El candidato no satisface las comprobaciones lineales indicadas.")
    print("18 casos: estabilidad continua y amplitud lineal a 50 Hz comprobadas.")
    print("No incluye saturación, retardos, discretización, conmutación ni medición.")


if __name__ == "__main__":
    main()
