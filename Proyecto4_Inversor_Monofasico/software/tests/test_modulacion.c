/*
 * Prueba de la conversión a modulación Q1.15 en PC.
 * Valores de prueba: Vdc = 24 V y MOD_LIMIT_Q15 = 31130 (m = 0,95).
 */
#include <stdio.h>

#include "modulacion.h"

#define VDC        24.0f
#define LIMITE     31130

static int fallas = 0;

static void comprobar(int condicion, const char *descripcion)
{
    printf("[%s] %s\n", condicion ? "PASA" : "FALLA", descripcion);
    if (!condicion) {
        fallas++;
    }
}

int main(void)
{
    modulacion_t mod;
    int sat = -1;
    int16_t q;

    modulacion_iniciar(&mod, VDC, LIMITE);
    comprobar(mod.inv_vdc > 0.0416f && mod.inv_vdc < 0.0417f, "inv_vdc = 1/24");
    comprobar(mod.m_max * 32768.0f == (float)LIMITE, "m_max * 32768 = MOD_LIMIT_Q15 exacto");

    /* Rango lineal */
    q = modulacion_calcular(&mod, 0.0f, &sat);
    comprobar(q == 0 && sat == 0, "0 V -> q = 0, sin saturar");

    q = modulacion_calcular(&mod, 12.0f, &sat);
    comprobar(q == 16384 && sat == 0, "12 V con Vdc = 24 V -> m = 0,5 -> q = 16384");

    q = modulacion_calcular(&mod, -12.0f, &sat);
    comprobar(q == -16384 && sat == 0, "-12 V -> q = -16384");

    /* Redondeo simétrico: 0,3 V -> m * 32768 = 409,6 -> 410; -0,3 V -> -410 */
    q = modulacion_calcular(&mod, 0.3f, &sat);
    comprobar(q == 410, "redondeo de positivos (409,6 -> 410)");
    q = modulacion_calcular(&mod, -0.3f, &sat);
    comprobar(q == -410, "redondeo de negativos (-409,6 -> -410)");

    /* 0,2 V -> 273,07 -> 273; -0,2 V -> -273 */
    q = modulacion_calcular(&mod, 0.2f, &sat);
    comprobar(q == 273, "redondeo hacia abajo de positivos (273,07 -> 273)");
    q = modulacion_calcular(&mod, -0.2f, &sat);
    comprobar(q == -273, "redondeo hacia arriba de negativos (-273,07 -> -273)");

    /* Un solo escalón de Q1.15: m = ±1/32768 -> q = ±1 */
    q = modulacion_calcular(&mod, VDC / 32768.0f, &sat);
    comprobar(q == 1 && sat == 0, "m = +1/32768 -> q = +1");
    q = modulacion_calcular(&mod, -VDC / 32768.0f, &sat);
    comprobar(q == -1 && sat == 0, "m = -1/32768 -> q = -1");

    /* Saturación */
    q = modulacion_calcular(&mod, 30.0f, &sat);
    comprobar(q == LIMITE && sat == 1, "30 V satura arriba en +MOD_LIMIT_Q15");

    q = modulacion_calcular(&mod, -30.0f, &sat);
    comprobar(q == -LIMITE && sat == 1, "-30 V satura abajo en -MOD_LIMIT_Q15");

    q = modulacion_calcular(&mod, 1e6f, &sat);
    comprobar(q == LIMITE && sat == 1, "valor enorme no desborda el int16_t");

    q = modulacion_calcular(&mod, 22.79f, &sat);
    comprobar(sat == 0 && q < LIMITE, "justo debajo del límite no satura");

    /* Límite máximo permitido: nunca -32768 */
    modulacion_iniciar(&mod, VDC, 32767);
    q = modulacion_calcular(&mod, -1000.0f, &sat);
    comprobar(q == -32767, "con el límite máximo, el mínimo es -32767 (nunca -32768)");

    /* Parámetros inválidos: se rechazan y la salida queda en 0 */
    comprobar(modulacion_iniciar(&mod, VDC, LIMITE) == 1, "parámetros válidos: aceptados");
    comprobar(modulacion_iniciar(&mod, 0.0f, LIMITE) == 0, "Vdc = 0: rechazado");
    q = modulacion_calcular(&mod, 10.0f, &sat);
    comprobar(q == 0, "con Vdc inválido la salida queda en 0");
    comprobar(modulacion_iniciar(&mod, -24.0f, LIMITE) == 0, "Vdc negativo: rechazado");
    comprobar(modulacion_iniciar(&mod, VDC, 0) == 0, "MOD_LIMIT_Q15 = 0: rechazado");
    comprobar(modulacion_iniciar(&mod, VDC, -5) == 0, "MOD_LIMIT_Q15 negativo: rechazado");

    printf("\n%s: %d falla(s)\n", fallas == 0 ? "RESULTADO OK" : "RESULTADO CON FALLAS", fallas);
    return fallas == 0 ? 0 : 1;
}
