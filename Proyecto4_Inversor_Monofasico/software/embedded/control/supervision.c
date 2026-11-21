/* Supervisión de fallas */
#include "supervision.h"

/* Inicio */
void supervision_iniciar(supervision_t *sup, float i_max, uint16_t codigo_min,
                         uint16_t codigo_max, uint32_t ciclos_max)
{
    sup->i_max = i_max;
    sup->codigo_min = codigo_min;
    sup->codigo_max = codigo_max;
    sup->ciclos_max = ciclos_max;
    sup->causa = 0;
    sup->sobre_seguidas = 0;
    sup->codigo_seguidas = 0;
}

/* Fallas de la muestra: devuelve los bits nuevos */
uint16_t supervision_muestra(supervision_t *sup, float i_med, uint16_t codigo,
                             int muestras_en_falla)
{
    uint16_t nuevas = 0;

    /* Sobrecorriente en N_SOBRECORRIENTE muestras seguidas (sin fabsf) */
    if (i_med > sup->i_max || i_med < -sup->i_max) {
        if (sup->sobre_seguidas < N_SOBRECORRIENTE) {
            sup->sobre_seguidas++;
        }
        if (sup->sobre_seguidas >= N_SOBRECORRIENTE) {
            nuevas |= FALLA_SOBRECORRIENTE;
        }
    } else {
        sup->sobre_seguidas = 0;
    }

    /* Código fuera de rango en N_CODIGO_FUERA muestras seguidas */
    if (codigo < sup->codigo_min || codigo > sup->codigo_max) {
        if (sup->codigo_seguidas < N_CODIGO_FUERA) {
            sup->codigo_seguidas++;
        }
        if (sup->codigo_seguidas >= N_CODIGO_FUERA) {
            nuevas |= FALLA_CODIGO;
        }
    } else {
        sup->codigo_seguidas = 0;
    }

    /* Muestras anómalas */
    if (muestras_en_falla) {
        nuevas |= FALLA_MUESTRAS;
    }

    sup->causa |= nuevas;
    return nuevas;
}

/* Exceso de tiempo de la ISR */
uint16_t supervision_tiempo(supervision_t *sup, uint32_t ciclos_isr)
{
    if (ciclos_isr > sup->ciclos_max) {
        sup->causa |= FALLA_TIEMPO;
        return FALLA_TIEMPO;
    }
    return 0;
}

/* Marcar una causa externa */
void supervision_marcar(supervision_t *sup, uint16_t bits)
{
    sup->causa |= bits;
}

/* Reconocimiento */
void supervision_reconocer(supervision_t *sup)
{
    sup->causa = 0;
    sup->sobre_seguidas = 0;
    sup->codigo_seguidas = 0;
}

/* ¿Hay falla? */
int supervision_hay_falla(const supervision_t *sup)
{
    return sup->causa != 0;
}
