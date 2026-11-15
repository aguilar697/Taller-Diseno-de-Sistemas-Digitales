/* Controlador PR discreto con anti-windup */
#include "control_pr.h"

/* Estados en cero */
void pr_reiniciar(pr_t *pr)
{
    pr->e1 = 0.0f;
    pr->e2 = 0.0f;
    pr->r1 = 0.0f;
    pr->r2 = 0.0f;
    pr->e_k = 0.0f;
    pr->r_k = 0.0f;
    pr->v_k = 0.0f;
}

/* Inicio */
void pr_iniciar(pr_t *pr, const pr_coef_t *coef)
{
    pr->c = *coef;
    pr_reiniciar(pr);
}

/* Paso 1: candidato sin tocar los estados */
float pr_calcular(pr_t *pr, float e)
{
    pr->r_k = pr->c.b0 * e
            + pr->c.b1 * pr->e1
            + pr->c.b2 * pr->e2
            - pr->c.a1 * pr->r1
            - pr->c.a2 * pr->r2;

    pr->v_k = pr->c.kp * e + pr->r_k;
    pr->e_k = e;
    return pr->v_k;
}

/* Paso 2: confirmar estados (integración condicional) */
void pr_actualizar(pr_t *pr, int saturado)
{
    /* Saturó y el error empuja en el mismo sentido: no acumular */
    if (saturado && pr->e_k * pr->v_k > 0.0f) {
        return;
    }

    /* Desplazar estados (el orden importa) */
    pr->e2 = pr->e1;
    pr->e1 = pr->e_k;
    pr->r2 = pr->r1;
    pr->r1 = pr->r_k;
}
