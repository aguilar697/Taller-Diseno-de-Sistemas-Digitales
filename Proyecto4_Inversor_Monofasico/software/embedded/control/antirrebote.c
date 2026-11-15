/* Antirrebote de botones e interruptores */
#include "antirrebote.h"

/* Inicio */
void antirrebote_iniciar(antirrebote_t *a, uint32_t entradas, uint32_t n_rebote,
                         uint32_t ahora)
{
    a->estable = entradas;
    a->candidato = entradas;
    a->t_cambio = ahora;
    a->n_rebote = n_rebote;
    a->anterior = entradas;
}

/* Actualización con el contador de iteraciones de la ISR */
uint32_t antirrebote_actualizar(antirrebote_t *a, uint32_t crudo, uint32_t ahora)
{
    if (crudo != a->candidato) {
        /* Cambio: reinicia la cuenta */
        a->candidato = crudo;
        a->t_cambio = ahora;
    } else if (a->candidato != a->estable &&
               (uint32_t)(ahora - a->t_cambio) >= a->n_rebote) {
        /* Estable el tiempo suficiente: se acepta */
        a->estable = a->candidato;
    }
    return a->estable;
}

/* Flancos de subida (botón presionado) */
uint32_t antirrebote_flancos(antirrebote_t *a)
{
    uint32_t flancos = a->estable & ~a->anterior;
    a->anterior = a->estable;
    return flancos;
}
