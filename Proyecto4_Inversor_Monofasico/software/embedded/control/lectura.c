/* Lectura y validación de la muestra del ADC */
#include "lectura.h"

#define ANOMALAS_MAX 65535u

/* Inicio */
void lectura_iniciar(lectura_t *l, float offset, float ganancia,
                     uint16_t n_por_control, uint16_t n_falla,
                     uint16_t n_inicial)
{
    l->offset        = offset;
    l->ganancia      = ganancia;
    l->n_por_control = n_por_control;
    l->n_falla       = n_falla;
    l->n_ant         = n_inicial;
    l->anomalas      = 0u;
    l->perdidas      = 0u;
}

/* Código a amperios (resta en float) */
float lectura_a_amperios(const lectura_t *l, uint16_t codigo)
{
    return ((float)codigo - l->offset) * l->ganancia;
}

/* Clasificación con Δn = (n - n_ant) mod 2^16 */
lectura_clase_t lectura_clasificar(lectura_t *l, uint16_t n)
{
    uint16_t delta = (uint16_t)(n - l->n_ant);
    l->n_ant = n;

    /* Muestra nueva */
    if (delta == l->n_por_control) {
        l->anomalas = 0u;
        return LECTURA_NUEVA;
    }

    /* Anómala: contador saturado, sin vuelta */
    if (l->anomalas < ANOMALAS_MAX) {
        l->anomalas++;
    }

    /* Muestra repetida */
    if (delta == 0u) {
        return LECTURA_REPETIDA;
    }

    /* Conversiones perdidas (solo si avanzó de más) */
    if (delta > l->n_por_control) {
        l->perdidas += (uint32_t)(delta - l->n_por_control);
    }
    return LECTURA_PERDIDAS;
}

/* Falla por anómalas seguidas */
int lectura_falla(const lectura_t *l)
{
    return l->anomalas >= l->n_falla;
}
