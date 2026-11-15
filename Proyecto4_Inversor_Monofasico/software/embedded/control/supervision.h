/* Supervisión de fallas */
#ifndef SUPERVISION_H
#define SUPERVISION_H

#include <stdint.h>

/* Bits de causa */
#define FALLA_SOBRECORRIENTE  (1u << 0)   /* |i_med| > I_MAX */
#define FALLA_CODIGO          (1u << 1)   /* código fuera de rango */
#define FALLA_MUESTRAS        (1u << 2)   /* muestras anómalas seguidas */
#define FALLA_TIEMPO          (1u << 3)   /* ISR más larga que el límite */
#define FALLA_CONFIGURACION   (1u << 4)   /* comprobación o running */

/* Límites y causa guardada */
typedef struct {
    float    i_max;        /* A */
    uint16_t codigo_min;
    uint16_t codigo_max;
    uint32_t ciclos_max;   /* Ts - MARGEN_ISR */
    uint16_t causa;        /* hasta el reconocimiento */
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
