/* Conversión de v_PR a la referencia de modulación Q1.15 */
#ifndef MODULACION_H
#define MODULACION_H

#include <stdint.h>

/* Constantes de la conversión */
typedef struct {
    float inv_vdc;   /* 1 / Vdc */
    float m_max;     /* MOD_LIMIT_Q15 / 32768 */
} modulacion_t;

int     modulacion_iniciar(modulacion_t *mod, float vdc, int16_t mod_limit_q15);
int16_t modulacion_calcular(const modulacion_t *mod, float v_pr, int *saturado);

#endif
