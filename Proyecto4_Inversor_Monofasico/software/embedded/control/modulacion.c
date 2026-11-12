/* Conversión de v_PR a la referencia de modulación Q1.15 */
#include "modulacion.h"

/* Inicio: devuelve 0 si los parámetros no son válidos (salida en 0) */
int modulacion_iniciar(modulacion_t *mod, float vdc, int16_t mod_limit_q15)
{
    if (vdc <= 0.0f || mod_limit_q15 < 1) {
        mod->inv_vdc = 0.0f;
        mod->m_max = 0.0f;
        return 0;
    }

    mod->inv_vdc = 1.0f / vdc;
    mod->m_max = (float)mod_limit_q15 / 32768.0f;
    return 1;
}

/* m = sat(v_PR / Vdc) en Q1.15 */
int16_t modulacion_calcular(const modulacion_t *mod, float v_pr, int *saturado)
{
    float m = v_pr * mod->inv_vdc;
    float x;

    /* Saturación */
    if (m > mod->m_max) {
        m = mod->m_max;
        *saturado = 1;
    } else if (m < -mod->m_max) {
        m = -mod->m_max;
        *saturado = 1;
    } else {
        *saturado = 0;
    }

    /* Redondeo simétrico (nunca -32768) */
    x = m * 32768.0f;
    if (x >= 0.0f) {
        x = x + 0.5f;
    } else {
        x = x - 0.5f;
    }
    return (int16_t)x;
}
