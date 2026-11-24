"""control_inversor (rama) con registro de falla: guarda cada muestra (K_REG = 1, 51,2 ms),
y tras una falla graba 20 muestras más y congela el registro hasta exportarlo.
La columna i_ref lleva el ADC en bruto: valor*1000 = código + 4096*errores (bits 4-6 de STATUS),
con signo negativo si la muestra no era válida. i_med es lo que recibió el PR.

Uso: python aplicar_captura_falla.py <carpeta Proyecto4_Inversor_Monofasico>
"""
import sys
from pathlib import Path

p = Path(sys.argv[1]) / "software/embedded/control/aplicacion.c"
t = p.read_bytes().decode("utf-8")
crlf = "\r\n" in t
t = t.replace("\r\n", "\n")
cambios = [
    ("    registro_iniciar(&app->registro, K_REG);",
     "    registro_iniciar(&app->registro, 1u);"),
    ("        info.k_reg = (uint16_t)K_REG;",
     "        info.k_reg = 1u;"),
    ("""    /* Registrar (fuera de OPERACIÓN: i_ref = m = 0) */
    registro_guardar(&app->registro, i_med, i_ref, q, n);""",
     """    /* Registro de falla: ADC en bruto; tras una falla, 20 muestras más y se congela */
    {
        static uint32_t post_falla;
        float bruto = (float)((codigo & 0x0FFFu) | (((estado_adc >> 4) & 0x7u) << 12)) / 1000.0f;
        (void)i_ref;
        if (!(estado_adc & ADC_ESTADO_VALIDO)) {
            bruto = -bruto;
        }
        if (app->estado != ESTADO_FALLA) {
            post_falla = 0u;
            registro_guardar(&app->registro, i_med, bruto, q, n);
        } else if (post_falla < 20u) {
            post_falla++;
            registro_guardar(&app->registro, i_med, bruto, q, n);
        }
    }"""),
]
for viejo, nuevo in cambios:
    if t.count(viejo) != 1:
        sys.exit("ERROR: no se encontró exactamente una vez: " + viejo[:60])
    t = t.replace(viejo, nuevo)
if crlf:
    t = t.replace("\n", "\r\n")
p.write_bytes(t.encode("utf-8"))
print("aplicado: control/aplicacion.c (3 cambios)")
