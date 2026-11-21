/* Supervisión de fallas */
#ifndef SUPERVISION_H
#define SUPERVISION_H

#include <stdint.h>

/* Bits de causa */
#define FALLA_SOBRECORRIENTE  (1u << 0)   /* |i_med| > I_MAX en N_SOBRECORRIENTE muestras seguidas */
#define FALLA_CODIGO          (1u << 1)   /* código fuera de rango en N_CODIGO_FUERA muestras seguidas */
#define FALLA_MUESTRAS        (1u << 2)   /* muestras anómalas seguidas */
#define FALLA_TIEMPO          (1u << 3)   /* ISR más larga que el límite */
#define FALLA_CONFIGURACION   (1u << 4)   /* comprobación o running */

/* Una muestra aislada fuera de rango (acople de conmutación) no es sobrecorriente */
#ifndef N_SOBRECORRIENTE
#define N_SOBRECORRIENTE      3u
#endif
#ifndef N_CODIGO_FUERA
#define N_CODIGO_FUERA        3u
#endif

/* Límites y causa guardada */
typedef struct {
    float    i_max;        /* A */
    uint16_t codigo_min;
    uint16_t codigo_max;
    uint32_t ciclos_max;   /* Ts - MARGEN_ISR */
    uint16_t causa;        /* hasta el reconocimiento */
    uint8_t  sobre_seguidas;
    uint8_t  codigo_seguidas;
} supervision_t;

void     supervision_iniciar(supervision_t *sup, float i_max, uint16_t codigo_min,
                             uint16_t codigo_max, uint32_t ciclos_max);
uint16_t supervision_muestra(supervision_t *sup, float i_med, uint16_t codigo,
                             int muestras_en_falla);
uint16_t supervision_tiempo(supervision_t *sup, uint32_t ciclos_isr);
void     supervision_marcar(supervision_t *sup, uint16_t bits);
void     supervision_reconocer(supervision_t *sup);
int      supervision_hay_falla(const supervision_t *sup);

#endif
