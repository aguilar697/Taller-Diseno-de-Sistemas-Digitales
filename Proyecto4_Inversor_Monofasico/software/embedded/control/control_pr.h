/* Controlador PR discreto con anti-windup */
#ifndef CONTROL_PR_H
#define CONTROL_PR_H

/* Coeficientes */
typedef struct {
    float kp;              /* proporcional */
    float b0, b1, b2;      /* numerador resonante */
    float a1, a2;          /* denominador resonante */
} pr_coef_t;

/* Estados y candidato de la iteración */
typedef struct {
    pr_coef_t c;
    float e1, e2;          /* e[k-1], e[k-2] */
    float r1, r2;          /* r[k-1], r[k-2] */
    float e_k, r_k, v_k;   /* pendientes de confirmar */
} pr_t;

void  pr_iniciar(pr_t *pr, const pr_coef_t *coef);
void  pr_reiniciar(pr_t *pr);
float pr_calcular(pr_t *pr, float e);
void  pr_actualizar(pr_t *pr, int saturado);

#endif
