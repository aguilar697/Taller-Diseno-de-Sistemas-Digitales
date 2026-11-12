/*
 * Prueba del controlador PR en PC.
 * Los coeficientes de prueba se obtienen como lo haría PEDP: PR no ideal
 * discretizado con Tustin y pre-warping en 50 Hz. Los definitivos los entrega PEDP.
 */
#include <math.h>
#include <stdio.h>

#include "control_pr.h"

#define TS     50e-6       /* 20 kHz */
#define F0     50.0
#define KP     1.0
#define KR     100.0
#define WC     5.0         /* rad/s */
#define PI     3.14159265358979323846

static int fallas = 0;

static void comprobar(int condicion, const char *descripcion)
{
    printf("[%s] %s\n", condicion ? "PASA" : "FALLA", descripcion);
    if (!condicion) {
        fallas++;
    }
}

/* G(s) = Kp + 2 Kr wc s / (s^2 + 2 wc s + w0^2), Tustin con pre-warping en w0 */
static pr_coef_t coeficientes_prueba(void)
{
    double w0 = 2.0 * PI * F0;
    double k  = w0 / tan(w0 * TS / 2.0);
    double a0 = k * k + 2.0 * WC * k + w0 * w0;
    pr_coef_t c;
    c.kp = (float)KP;
    c.b0 = (float)(2.0 * KR * WC * k / a0);
    c.b1 = 0.0f;
    c.b2 = -c.b0;
    c.a1 = (float)(2.0 * (w0 * w0 - k * k) / a0);
    c.a2 = (float)((k * k - 2.0 * WC * k + w0 * w0) / a0);
    return c;
}

/* Amplitud de v_PR en régimen permanente ante un error sinusoidal de amplitud 1 */
static double ganancia_medida(const pr_coef_t *c, double f)
{
    pr_t pr;
    pr_iniciar(&pr, c);
    int n_total = 60000;                      /* 3 s: el transitorio decae con 1/wc = 0,2 s */
    int n_ventana = (int)(1.0 / (f * TS));    /* un período */
    double maximo = 0.0;
    for (int k = 0; k < n_total; k++) {
        float e = (float)sin(2.0 * PI * f * k * TS);
        float v = pr_calcular(&pr, e);
        pr_actualizar(&pr, 0);
        if (k >= n_total - n_ventana && fabs(v) > maximo) {
            maximo = fabs(v);
        }
    }
    return maximo;
}

int main(void)
{
    pr_coef_t c = coeficientes_prueba();
    pr_t pr;

    /* 1. Arranque en cero */
    pr.e1 = pr.e2 = pr.r1 = pr.r2 = 123.0f;   /* basura a propósito */
    pr_iniciar(&pr, &c);
    comprobar(pr.e1 == 0.0f && pr.e2 == 0.0f && pr.r1 == 0.0f && pr.r2 == 0.0f,
              "pr_iniciar deja los estados en cero");
    comprobar(pr.c.b0 == c.b0 && pr.c.a2 == c.a2, "pr_iniciar copia los coeficientes");

    /* 2. Ecuación: en cada iteración se calcula aparte (en double) lo que
     * debería dar con los estados actuales del PR. Se compara paso a paso
     * para que el redondeo de float no se acumule en el resonador. */
    double error_max = 0;
    for (int k = 0; k < 2000; k++) {
        float e = (float)(0.3 * sin(2.0 * PI * F0 * k * TS) + 0.05 * cos(0.37 * k));
        double r = (double)c.b0 * e + (double)c.b1 * pr.e1 + (double)c.b2 * pr.e2
                 - (double)c.a1 * pr.r1 - (double)c.a2 * pr.r2;
        double v = (double)c.kp * e + r;
        float v_pr = pr_calcular(&pr, e);
        pr_actualizar(&pr, 0);
        double dif = fabs(v_pr - v) / (fabs(v) + 1e-3);
        if (dif > error_max) error_max = dif;
    }
    comprobar(error_max < 1e-4, "v_PR coincide con la ecuación calculada aparte");

    /* 3. Orden de los estados */
    pr_iniciar(&pr, &c);
    pr_calcular(&pr, 1.0f); pr_actualizar(&pr, 0);
    pr_calcular(&pr, 2.0f); pr_actualizar(&pr, 0);
    comprobar(pr.e1 == 2.0f && pr.e2 == 1.0f, "e1 es el último error y e2 el anterior");

    /* 4. Anti-windup */
    pr_iniciar(&pr, &c);
    pr_calcular(&pr, 0.5f); pr_actualizar(&pr, 0);
    float r1_antes = pr.r1;
    pr_calcular(&pr, 0.5f);                    /* e > 0 y v > 0 */
    pr_actualizar(&pr, 1);                     /* saturó con el mismo signo */
    comprobar(pr.r1 == r1_antes && pr.e1 == 0.5f && pr.e2 == 0.0f,
              "saturado y mismo signo: los estados no cambian");

    pr_iniciar(&pr, &c);
    pr.r1 = 5.0f;                              /* resonador "inflado" hacia arriba */
    pr.r2 = 5.0f;
    pr_calcular(&pr, -0.1f);                   /* la corriente ya se pasó: e < 0 */
    float v_k = pr.v_k;                        /* pero v_PR sigue > 0 por el resonador */
    pr_actualizar(&pr, 1);
    comprobar(v_k > 0.0f && pr.e1 == -0.1f && pr.r1 != 5.0f,
              "saturado y signo opuesto: los estados se actualizan");

    pr_iniciar(&pr, &c);
    pr_calcular(&pr, 0.5f); pr_actualizar(&pr, 0);
    pr_calcular(&pr, 0.5f); pr_actualizar(&pr, 0);
    comprobar(pr.e1 == 0.5f && pr.e2 == 0.5f, "sin saturación: los estados se actualizan");

    /* 5. Reinicio */
    pr_reiniciar(&pr);
    comprobar(pr.e1 == 0.0f && pr.r1 == 0.0f && pr.c.b0 == c.b0,
              "pr_reiniciar borra los estados y conserva los coeficientes");

    /* 6. Resonancia: ganancia Kp + Kr en 50 Hz y baja lejos de 50 Hz */
    double g50 = ganancia_medida(&c, 50.0);
    double g500 = ganancia_medida(&c, 500.0);
    printf("       ganancia en 50 Hz = %.2f (esperada %.0f), en 500 Hz = %.2f\n", g50, KP + KR, g500);
    comprobar(fabs(g50 - (KP + KR)) / (KP + KR) < 0.01, "ganancia en 50 Hz = Kp + Kr (error < 1 %)");
    comprobar(g500 < 2.0, "ganancia en 500 Hz pequeña (el resonador solo actúa en 50 Hz)");

    printf("\n%s: %d falla(s)\n", fallas == 0 ? "RESULTADO OK" : "RESULTADO CON FALLAS", fallas);
    return fallas == 0 ? 0 : 1;
}
