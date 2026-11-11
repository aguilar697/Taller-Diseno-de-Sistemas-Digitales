"""Comprobaciones del modelo numérico; no sustituyen pruebas RTL ni PLECS."""

import math
import unittest

from rizado_pwm_rl import Caso, evolucion, integral_cuadrado, rizado_estacionario, segmentos, simular


class VerificacionModelo(unittest.TestCase):
    def test_tension_media_y_carrier_independiente(self):
        # Se contrasta la secuencia de eventos con comparadores muestreados,
        # construidos directamente desde una triangular normalizada.
        pasos = 20000
        for m in (-1., -.73, -.1, 0., .1, .73, 1.):
            secuencia = segmentos(m, 1., 24.)
            self.assertAlmostEqual(sum(dt for dt, _ in secuencia), 1.)
            self.assertAlmostEqual(sum(dt*v for dt, v in secuencia), 24*m)
            suma = 0
            for k in range(pasos):
                p = (k+.5)/pasos
                carrier = 2*p if p < .5 else 2*(1-p)
                suma += 24*(int(carrier < (1+m)/2)-int(carrier < (1-m)/2))
            self.assertAlmostEqual(suma/pasos, 24*m, places=10)

    def test_rk4_independiente(self):
        # RK4 de paso pequeño verifica la evolución exacta y la secuencia PWM.
        r, l, periodo, i = 7.8, .0047, .0001, .3
        exacta = i
        for dt, v in segmentos(.37, periodo, 24):
            exacta = evolucion(exacta, v, dt, r, l)
        dt = periodo/20000
        for k in range(20000):
            p = (k+.5)/20000
            carrier = 2*p if p < .5 else 2*(1-p)
            v = 24*(int(carrier < .685)-int(carrier < .315))
            f = lambda x: (v-r*x)/l
            a = f(i); b = f(i+dt*a/2); c = f(i+dt*b/2); d = f(i+dt*c)
            i += dt*(a+2*b+2*c+d)/6
        self.assertAlmostEqual(i, exacta, places=9)

    def test_integral_rms_por_cuadratura(self):
        i0, v, dt, r, l = .3, 24., .00003, 7.8, .0047
        numerica = sum(evolucion(i0, v, (k+.5)*dt/10000, r, l)**2
                       for k in range(10000))*dt/10000
        self.assertAlmostEqual(integral_cuadrado(i0, v, dt, r, l), numerica, places=13)

    def test_rizado_fijo_contra_formula_estacionaria(self):
        r, l, vdc, fs = 7.8, .0047, 24., 10000.
        for m in (.1, .5, .9):
            i = 0.
            extremos = []
            for n in range(500):
                extremos = [i]
                for dt, v in segmentos(m, 1/fs, vdc):
                    i = evolucion(i, v, dt, r, l)
                    extremos.append(i)
            self.assertAlmostEqual(max(extremos)-min(extremos),
                                   rizado_estacionario(m, vdc, r, l, fs), places=12)
        self.assertAlmostEqual(rizado_estacionario(.5, vdc, r, l, fs),
                               vdc/r*math.tanh(r/(8*l*fs)), places=12)

    def test_referencia_cero(self):
        resultado = simular(Caso(12., .0047, 10000., 0.))
        self.assertEqual(resultado["rizado_residuo_max_pp_a"], 0.)
        self.assertEqual(resultado["i_total_rms_a"], 0.)

    def test_convergencia_asentamiento(self):
        caso = Caso(24., .01, 10000., .2, resistencia_devanado=.5)
        corto, largo = simular(caso, 5, 5), simular(caso, 10, 5)
        for clave in ("rizado_residuo_max_pp_a", "i_total_rms_a", "i_total_pico_abs_a"):
            self.assertAlmostEqual(corto[clave], largo[clave], places=11)

    def test_extremos_y_simetria(self):
        for m in (.1, .5, 1.):
            positivos = segmentos(m, .0001, 24)
            negativos = segmentos(-m, .0001, 24)
            self.assertEqual([(dt, -v) for dt, v in positivos], negativos)
        caso = Caso(12., .0047, 10000., 1.)
        resultado = simular(caso)
        self.assertGreater(resultado["i_total_rms_a"], 0.)
        self.assertLess(resultado["rizado_residuo_max_pp_a"], .2)

    def test_sobremodulacion_rechazada(self):
        with self.assertRaises(ValueError):
            simular(Caso(12., .01, 10000., 3.))


if __name__ == "__main__":
    unittest.main()
