/* Referencia sinusoidal de corriente */
#include "referencia.h"
#include "tabla_seno.h"

/* Inicio: Δθ = round(2^32 · f · Ts) */
void referencia_iniciar(referencia_t *r, float f_ref_hz, float ts_s)
{
    r->theta = 0;
    r->amplitud = 0.0f;
    r->amplitud_pend = 0.0f;
    r->delta_theta = (uint32_t)(4294967296.0 * (double)f_ref_hz * (double)ts_s + 0.5);
}

/* Arranque al habilitar: θ en cero y amplitud pedida activa */
void referencia_arrancar(referencia_t *r)
{
    r->theta = 0;
    r->amplitud = r->amplitud_pend;
}

/* Amplitud pedida (se aplica en el cruce por cero) */
void referencia_pedir_amplitud(referencia_t *r, float amplitud_a)
{
    r->amplitud_pend = amplitud_a;
}

/* Paso: avanzar θ y leer la tabla */
float referencia_paso(referencia_t *r)
{
    uint32_t anterior = r->theta;
    r->theta = r->theta + r->delta_theta;

    /* Cruce por cero: θ dio la vuelta */
    if (r->theta < anterior) {
        r->amplitud = r->amplitud_pend;
    }

    return r->amplitud * (float)TABLA_SENO[r->theta >> 24] / 32768.0f;
}
