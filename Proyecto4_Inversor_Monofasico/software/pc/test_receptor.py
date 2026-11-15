"""Prueba del receptor con tramas sintéticas y con la trama que exporta el
firmware en la prueba de C (build/trama_aplicacion.bin, si existe).

Uso, desde proyecto_4:  python software/pc/test_receptor.py
"""

import math
import os
import struct
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import receptor  # noqa: E402  pylint: disable=wrong-import-position

TRAMA_FIRMWARE = os.path.join(os.path.dirname(__file__), "..", "..", "build",
                              "trama_aplicacion.bin")


def armar_trama(amp_med=0.48, amp_ref=0.5, desfase_grados=-3.0, n=1000, k_reg=2,
                ts_ns=50000):
    """Trama válida con senos de 50 Hz conocidos."""
    por_periodo = 1.0 / (50.0 * k_reg * ts_ns * 1e-9)
    cuerpo = struct.pack("<BBIIHHHHII", 1, 2, 20000, ts_ns, k_reg, n,
                         int(amp_ref * 1000), 0, 1500, 0)
    for k in range(n):
        ang = 2 * math.pi * k / por_periodo
        i_med = amp_med * math.sin(ang + math.radians(desfase_grados))
        i_ref = amp_ref * math.sin(ang)
        cuerpo += struct.pack("<hhhH", round(i_med * 1000), round(i_ref * 1000), 0,
                              (k * k_reg) % 65536)
    crc = receptor.crc16(cuerpo)
    return receptor.SINC + cuerpo + struct.pack("<H", crc)


class PruebaReceptor(unittest.TestCase):
    """Pruebas del receptor."""

    def test_crc_valor_de_verificacion(self):
        """CRC de "123456789"."""
        self.assertEqual(receptor.crc16(b"123456789"), 0x29B1)

    def test_decodifica_trama_valida(self):
        """Trama válida."""
        t = receptor.decodificar(armar_trama())
        self.assertEqual(t["n"], 1000)
        self.assertEqual(t["k_reg"], 2)
        self.assertEqual(t["amplitud_ma"], 500)
        self.assertEqual(len(t["i_med"]), 1000)

    def test_ignora_basura_antes_del_sincronismo(self):
        """Bytes antes del sincronismo."""
        t = receptor.decodificar(b"\x00\x13\xFF" + armar_trama())
        self.assertEqual(t["n"], 1000)

    def test_rechaza_byte_alterado(self):
        """Byte alterado."""
        datos = bytearray(armar_trama())
        datos[100] ^= 0x01
        with self.assertRaises(receptor.TramaInvalida):
            receptor.decodificar(bytes(datos))

    def test_rechaza_trama_cortada(self):
        """Trama cortada."""
        with self.assertRaises(receptor.TramaInvalida):
            receptor.decodificar(armar_trama()[:-10])

    def test_rechaza_sin_sincronismo(self):
        """Sin sincronismo."""
        with self.assertRaises(receptor.TramaInvalida):
            receptor.decodificar(b"\x00" * 100)

    def test_analisis_de_senos_conocidos(self):
        """Error y desfase de senos conocidos."""
        r = receptor.analizar(receptor.decodificar(armar_trama(0.48, 0.5, -3.0)))
        self.assertEqual(r["periodos"], 5)
        self.assertAlmostEqual(r["error"], -0.04, delta=0.002)
        self.assertAlmostEqual(r["desfase"], -3.0, delta=0.2)
        self.assertTrue(r["cumple"])
        self.assertEqual(r["saltos_de_n"], 0)
        self.assertLess(r["residuo_rms"], 0.002)

    def test_detecta_error_mayor_al_criterio(self):
        """Error mayor al 10 %."""
        r = receptor.analizar(receptor.decodificar(armar_trama(0.40, 0.5, 0.0)))
        self.assertFalse(r["cumple"])

    def test_rechaza_menos_de_cinco_periodos(self):
        """Menos de cinco períodos."""
        with self.assertRaises(receptor.TramaInvalida):
            receptor.analizar(receptor.decodificar(armar_trama(n=700)))

    @unittest.skipUnless(os.path.exists(TRAMA_FIRMWARE), "falta correr primero test_aplicacion.exe")
    def test_trama_del_firmware(self):
        """Trama exportada por la prueba de la aplicación."""
        with open(TRAMA_FIRMWARE, "rb") as f:
            t = receptor.decodificar(f.read())
        self.assertEqual(t["n"], 1024)
        r = receptor.analizar(t)
        self.assertGreaterEqual(r["periodos"], 5)
        self.assertTrue(r["cumple"])
        self.assertEqual(r["saltos_de_n"], 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
