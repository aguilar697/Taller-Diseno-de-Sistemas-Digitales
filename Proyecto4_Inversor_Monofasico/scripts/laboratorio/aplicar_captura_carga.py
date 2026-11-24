"""Captura para el cambio de carga: ventana de 819,2 ms (K_REG = 16). Con BTNL la trama
sale 50 ms después, así que contiene ~770 ms ANTES de la pulsación: primero se quita el
puente y enseguida se pulsa BTNL. Un cambio de amplitud sigue centrado en la trama.

Uso: python aplicar_captura_carga.py <carpeta Proyecto4_Inversor_Monofasico>
"""
import runpy
import sys
from pathlib import Path

raiz = Path(sys.argv[1])
runpy.run_path(str(Path(__file__).with_name("aplicar_captura_transitorio.py")), run_name="__main__")

p = raiz / "software/embedded/control/aplicacion.c"
t = p.read_bytes().decode("utf-8")
crlf = "\r\n" in t
t = t.replace("\r\n", "\n")
cambios = [
    ("#define MEDIA_VENTANA ((REGISTRO_N_BUF * K_REG) / 2u)\n",
     "#define MEDIA_VENTANA ((REGISTRO_N_BUF * K_REG) / 2u)\n#define RETARDO_BTNL 500u\n"),
    ("    if ((flancos & BTN_EXPORTAR) && !captura_armada) {\n        captura_armada = 1;\n        captura_en = ahora + MEDIA_VENTANA;\n",
     "    if ((flancos & BTN_EXPORTAR) && !captura_armada) {\n        captura_armada = 1;\n        captura_en = ahora + RETARDO_BTNL;\n"),
]
for viejo, nuevo in cambios:
    if t.count(viejo) != 1:
        sys.exit("ERROR: no se encontró exactamente una vez: " + viejo[:60])
    t = t.replace(viejo, nuevo)
if crlf:
    t = t.replace("\n", "\r\n")
p.write_bytes(t.encode("utf-8"))

b = raiz / "scripts/vitis/build_integrated.py"
s = b.read_text(encoding="utf-8")
viejo = "-DREGISTRO_N_BUF=512u -DK_REG=2u -fstack-usage"
if s.count(viejo) != 1:
    sys.exit("ERROR: banderas de compilación no encontradas")
b.write_text(s.replace(viejo, "-DREGISTRO_N_BUF=512u -DK_REG=16u -fstack-usage"), encoding="utf-8")
print("aplicado: BTNL con 50 ms de retardo y K_REG = 16")
