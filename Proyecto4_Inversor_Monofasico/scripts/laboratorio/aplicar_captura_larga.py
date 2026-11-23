"""Captura de transitorio con ventana de 409,6 ms (K_REG = 8): la trama sale 204,8 ms
después de BTNL o del cambio de amplitud, con la mitad antes y la mitad después.

Uso: python aplicar_captura_larga.py <carpeta Proyecto4_Inversor_Monofasico>
"""
import runpy
import sys
from pathlib import Path

raiz = Path(sys.argv[1])
runpy.run_path(str(Path(__file__).with_name("aplicar_captura_transitorio.py")), run_name="__main__")
p = raiz / "scripts/vitis/build_integrated.py"
t = p.read_text(encoding="utf-8")
viejo = "-DREGISTRO_N_BUF=512u -DK_REG=2u -fstack-usage"
if t.count(viejo) != 1:
    sys.exit("ERROR: banderas de compilación no encontradas")
p.write_text(t.replace(viejo, "-DREGISTRO_N_BUF=512u -DK_REG=8u -fstack-usage"), encoding="utf-8")
print("aplicado: K_REG = 8 en build_integrated.py")
