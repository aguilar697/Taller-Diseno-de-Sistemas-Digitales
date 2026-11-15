/* Antirrebote de botones e interruptores */
#ifndef ANTIRREBOTE_H
#define ANTIRREBOTE_H

#include <stdint.h>

/* Estado del antirrebote */
typedef struct {
    uint32_t estable;      /* valor aceptado */
    uint32_t candidato;    /* último valor leído */
    uint32_t t_cambio;     /* iteración del último cambio */
    uint32_t n_rebote;     /* T_REBOTE en iteraciones */
    uint32_t anterior;     /* para detectar flancos */
} antirrebote_t;

void     antirrebote_iniciar(antirrebote_t *a, uint32_t entradas, uint32_t n_rebote,
                             uint32_t ahora);
uint32_t antirrebote_actualizar(antirrebote_t *a, uint32_t crudo, uint32_t ahora);
uint32_t antirrebote_flancos(antirrebote_t *a);

#endif
