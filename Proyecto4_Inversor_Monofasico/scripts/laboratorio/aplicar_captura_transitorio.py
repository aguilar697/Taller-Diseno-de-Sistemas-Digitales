"""control_inversor con captura centrada: BTNL o un cambio de amplitud en marcha
arman la exportación, que sale media ventana después (51,2 ms con 512 x 200 us).
La trama queda con la mitad antes y la mitad después del evento. LD2 encendido = armada.

Uso: python aplicar_captura_transitorio.py <carpeta Proyecto4_Inversor_Monofasico>
"""
import sys
from pathlib import Path

p = Path(sys.argv[1]) / "software/embedded/control/aplicacion.c"
t = p.read_bytes().decode("utf-8")
crlf = "\r\n" in t
t = t.replace("\r\n", "\n")

viejo_export = """    /* Evento: exportar */
    if ((flancos & BTN_EXPORTAR) && !exportacion_en_curso(&app->exportacion)) {
        trama_info_t info;"""
nuevo_export = """    /* Captura: BTNL o cambio de amplitud en marcha; se exporta media ventana después */
    if (app->estado != ESTADO_OPERACION || app->arranque > 0u) {
        amplitud_previa = -1.0f;
    } else {
        if (amplitud_previa >= 0.0f && app->referencia.amplitud != amplitud_previa && !captura_armada) {
            captura_armada = 1;
            captura_en = ahora + MEDIA_VENTANA;
        }
        amplitud_previa = app->referencia.amplitud;
    }
    if ((flancos & BTN_EXPORTAR) && !captura_armada) {
        captura_armada = 1;
        captura_en = ahora + MEDIA_VENTANA;
    }

    /* Evento: exportar */
    if (captura_armada && (int32_t)(ahora - captura_en) >= 0 && !exportacion_en_curso(&app->exportacion)) {
        trama_info_t info;
        captura_armada = 0;"""

cambios = [
    ("void app_lazo_paso(aplicacion_t *app)\n{",
     "#define MEDIA_VENTANA ((REGISTRO_N_BUF * K_REG) / 2u)\n"
     "static int captura_armada;\n"
     "static uint32_t captura_en;\n"
     "static float amplitud_previa = -1.0f;\n\n"
     "void app_lazo_paso(aplicacion_t *app)\n{"),
    (viejo_export, nuevo_export),
    ("    if (exportacion_en_curso(&app->exportacion)) {\n        leds |= LED_EXPORTANDO;",
     "    if (exportacion_en_curso(&app->exportacion) || captura_armada) {\n        leds |= LED_EXPORTANDO;"),
]
for viejo, nuevo in cambios:
    if t.count(viejo) != 1:
        sys.exit("ERROR: no se encontró exactamente una vez: " + viejo[:60])
    t = t.replace(viejo, nuevo)
if crlf:
    t = t.replace("\n", "\r\n")
p.write_bytes(t.encode("utf-8"))
print("aplicado: control/aplicacion.c (3 cambios)")
