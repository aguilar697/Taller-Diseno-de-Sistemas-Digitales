import math
from pathlib import Path

N = 256
valores = [round(math.sin(2 * math.pi * i / N) * 32767) for i in range(N)]

lineas = ["/* Generado por scripts/generar_tabla_seno.py: sin(2*pi*i/256) en Q1.15 */",
          "#ifndef TABLA_SENO_H", "#define TABLA_SENO_H", "", "#include <stdint.h>", "",
          f"#define TABLA_SENO_N {N}u", "",
          "static const int16_t TABLA_SENO[TABLA_SENO_N] = {"]
for i in range(0, N, 8):
    lineas.append("    " + ", ".join(f"{v:6d}" for v in valores[i:i + 8]) + ",")
lineas += ["};", "", "#endif", ""]

salida = Path(__file__).parent.parent / "software/embedded/control/tabla_seno.h"
salida.write_text("\n".join(lineas), encoding="utf-8")
print(f"Escrito {salida}")
