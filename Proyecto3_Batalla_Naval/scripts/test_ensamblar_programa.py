"""Comprueba codificaciones y límites del subconjunto implementado por la CPU."""

import unittest

from ensamblar_programa import assemble, encode, expand


class AssemblerTests(unittest.TestCase):
    def test_unsupported_unsigned_branches_are_rejected(self):
        for op in ("bltu", "bgeu"):
            with self.subTest(op=op), self.assertRaisesRegex(ValueError, "no implementada"):
                encode(op, ["x1", "x2", "destino"], 0, {"destino": 8})

    def test_known_encodings(self):
        cases = [
            ("addi", ["x1", "x0", "-1"], 0, {}, 0xFFF00093),
            ("sub", ["x3", "x5", "x7"], 0, {}, 0x407281B3),
            ("sw", ["x3", "4(x20)"], 0, {}, 0x003A2223),
            ("lw", ["x4", "4(x20)"], 0, {}, 0x004A2203),
            ("beq", ["x0", "x0", "destino"], 4, {"destino": 0}, 0xFE000EE3),
            ("jal", ["x0", "destino"], 0, {"destino": 0}, 0x0000006F),
        ]
        for op, args, pc, symbols, expected in cases:
            with self.subTest(op=op):
                self.assertEqual(encode(op, args, pc, symbols), expected)

    def test_li_round_trips_signed_and_unsigned_boundaries(self):
        for value in (-2147483648, -2049, -2048, 0, 2047, 2048, 0x7FFFFFFF, 0xFFFFFFFF):
            result = 0
            for op, args in expand("li", ["x1", str(value)], {}):
                word = encode(op, args, 0, {})
                if op == "lui":
                    result = word & 0xFFFFF000
                else:
                    immediate = word >> 20
                    if immediate & 0x800:
                        immediate -= 0x1000
                    result = ((result if args[1] == "x1" else 0) + immediate) & 0xFFFFFFFF
            self.assertEqual(result, value & 0xFFFFFFFF)

    def test_invalid_immediates_and_alignment_are_rejected(self):
        for op, args in (("addi", ["x1", "x0", "2048"]),
                         ("slli", ["x1", "x0", "32"]),
                         ("jal", ["x0", "2"])):
            with self.subTest(op=op), self.assertRaises(ValueError):
                encode(op, args, 0, {})

    def test_game_fits_rom(self):
        words, used = assemble()
        self.assertEqual(len(words), 2048)
        self.assertLessEqual(used, 2048)
        self.assertTrue(all(0 <= word <= 0xFFFFFFFF for word in words))


if __name__ == "__main__":
    unittest.main()
