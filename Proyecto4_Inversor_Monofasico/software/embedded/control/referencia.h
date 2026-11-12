/* Referencia sinusoidal de corriente */
#ifndef REFERENCIA_H
#define REFERENCIA_H

#include <stdint.h>

/* Fase, avance y amplitud */
typedef struct {
    uint32_t       theta;          /* 2^32 = una vuelta */
    uint32_t       delta_theta;    /* avance por iteración */
    float          amplitud;       /* A pico, activa */
    volatile float amplitud_pend;  /* pedida por el lazo principal */
} referencia_t;

void  referencia_iniciar(referencia_t *r, float f_ref_hz, float ts_s);
void  referencia_arrancar(referencia_t *r);
void  referencia_pedir_amplitud(referencia_t *r, float amplitud_a);
float referencia_paso(referencia_t *r);

#endif
