/* Lectura y validación de la muestra del ADC */
#ifndef LECTURA_H
#define LECTURA_H

#include <stdint.h>

/* Clase de la muestra según Δn */
typedef enum {
    LECTURA_NUEVA,       /* Δn = N_PWM_POR_CONTROL */
    LECTURA_REPETIDA,    /* Δn = 0 */
    LECTURA_PERDIDAS     /* otro Δn */
} lectura_clase_t;

/* Estado de la lectura */
typedef struct {
    float    offset;         /* código para 0 A */
    float    ganancia;       /* A por código */
    uint16_t n_por_control;  /* Δn esperado */
    uint16_t n_falla;        /* anómalas seguidas para falla */
    uint16_t n_ant;          /* n anterior */
    uint16_t anomalas;       /* anómalas consecutivas */
    uint32_t perdidas;       /* conversiones perdidas */
} lectura_t;

void            lectura_iniciar(lectura_t *l, float offset, float ganancia,
                                uint16_t n_por_control, uint16_t n_falla,
                                uint16_t n_inicial);
float           lectura_a_amperios(const lectura_t *l, uint16_t codigo);
lectura_clase_t lectura_clasificar(lectura_t *l, uint16_t n);
int             lectura_falla(const lectura_t *l);

#endif
