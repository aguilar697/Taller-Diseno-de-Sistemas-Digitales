/* Registro circular de muestras */
#ifndef REGISTRO_H
#define REGISTRO_H

#include <stdint.h>

#ifndef REGISTRO_N_BUF
#define REGISTRO_N_BUF 1024u
#endif

/* Entrada de 8 bytes */
typedef struct {
    int16_t  i_med_ma;   /* mA */
    int16_t  i_ref_ma;   /* mA */
    int16_t  m_q15;      /* REFERENCE escrita */
    uint16_t n;          /* número de muestra */
} muestra_t;

/* Buffer y contadores */
typedef struct {
    muestra_t datos[REGISTRO_N_BUF];
    uint32_t  indice;              /* próxima posición */
    uint32_t  cantidad;            /* entradas válidas */
    uint32_t  contador;            /* para el submuestreo */
    uint32_t  k_reg;               /* una de cada k_reg */
    volatile uint32_t congelado;   /* 1 mientras se exporta */
} registro_t;

void      registro_iniciar(registro_t *reg, uint32_t k_reg);
void      registro_guardar(registro_t *reg, float i_med, float i_ref, int16_t m_q15, uint16_t n);
void      registro_congelar(registro_t *reg);
void      registro_descongelar(registro_t *reg);
uint32_t  registro_cantidad(const registro_t *reg);
muestra_t registro_leer(const registro_t *reg, uint32_t i);

#endif
