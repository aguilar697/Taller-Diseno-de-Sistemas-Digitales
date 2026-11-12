"""Comprobaciones independientes de discretización, estabilidad y seguimiento."""

import cmath
import math
import unittest

import pr_discreto as pr


class PRDiscretoTest(unittest.TestCase):
    def test_resonancia_conserva_ganancia(self):
        self.assertAlmostEqual(pr.controlador(50).real, pr.KP+pr.KR, places=7)
        self.assertAlmostEqual(pr.controlador(50).imag, 0.0, places=7)

    def test_tustin_contra_transformacion_compleja(self):
        w0 = 2*math.pi*pr.F0
        k = w0/math.tan(w0*pr.TS/2)
        for f in (1, 20, 49, 50, 51, 500, 2000):
            q = cmath.exp(-2j*math.pi*f*pr.TS)
            s = k*(1-q)/(1+q)
            continuo = pr.KP+2*pr.KR*pr.WC*s/(s*s+2*pr.WC*s+w0*w0)
            self.assertLess(abs(pr.controlador(f)-continuo), 1e-7)

    def test_schur_con_raices_conocidas(self):
        self.assertTrue(pr.schur_estable([1, -1.7, .72]))  # 0,8 y 0,9
        self.assertFalse(pr.schur_estable([1, -1.2, .11]))  # 1,1 y 0,1
        self.assertFalse(pr.schur_estable([1, -1]))  # polo en el límite

    def test_regimen_coincide_con_respuesta_frecuencial(self):
        for delay in (0, 1):
            for v in (12, 24):
                datos = pr.simular(vdc=v, retardo=delay)
                amp, fase = pr.fundamental(datos)
                ok, ganancia, fase_teorica = pr.evaluar(7.2, .01, v, delay)
                self.assertTrue(ok)
                self.assertAlmostEqual(amp/.5, ganancia, places=6)
                self.assertAlmostEqual(fase, fase_teorica, places=4)

    def test_barrido_float32(self):
        coef = tuple(map(pr.float32, pr.coeficientes()))
        for r in (7.2, 10.5):
            for l in (.006984, .009291, .010):
                for v in (12, 24):
                    ok, g, _ = pr.evaluar(r, l, v, coef=coef)
                    self.assertTrue(ok)
                    self.assertTrue(.9 <= g <= 1.1)

    def test_retardo_excesivo_detectado(self):
        self.assertFalse(pr.evaluar(7.2, .006984, 24, retardo=20)[0])

    def test_limite_modulacion(self):
        datos = pr.simular(amplitud=10, duracion=.02)
        self.assertTrue(any(row[4] for row in datos))
        self.assertTrue(all(abs(row[3]) <= .85 for row in datos))


if __name__ == "__main__":
    unittest.main()
