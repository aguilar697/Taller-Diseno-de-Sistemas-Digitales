"""Verifica la extracción de fundamental y la detección temporal de órdenes."""

import math
import unittest

from ensayar_lazo_funcional import fundamental, comprobar_ordenes


class MetricasTest(unittest.TestCase):
    def test_fundamental_con_offset_y_armonico(self):
        t = [.4+k*1e-5 for k in range(10001)]
        fase = -.17
        i = [.07+.5*math.sin(2*math.pi*50*x+fase)
             +.03*math.sin(2*math.pi*150*x) for x in t]
        amp, phi = fundamental(t, i)
        self.assertAlmostEqual(amp, .5, places=10)
        self.assertAlmostEqual(phi, math.degrees(fase), places=8)

    def test_hueco_sin_incluir_bordes(self):
        alto = [0, 0, 1, 1, 0, 0, 0, 0, 1, 1, 0]
        bajo = [0, 0, 0, 0, 0, 1, 1, 0, 0, 0, 0]
        r = comprobar_ordenes([alto, bajo, alto, bajo], 1e-6)
        self.assertEqual(r["muestras_con_solapamiento"], 0)
        self.assertEqual(r["hueco_minimo_muestreado_s"], 1e-6)
        self.assertTrue(r["actividad_en_las_cuatro_ordenes"])

    def test_detecta_solapamiento_y_salida_inactiva(self):
        r = comprobar_ordenes([[0, 1, 1], [0, 0, 1], [0, 0, 0], [1, 0, 1]], 1e-6)
        self.assertEqual(r["muestras_con_solapamiento"], 1)
        self.assertFalse(r["actividad_en_las_cuatro_ordenes"])


if __name__ == "__main__":
    unittest.main()
