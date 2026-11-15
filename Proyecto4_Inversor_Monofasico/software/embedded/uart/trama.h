/* Formato de la trama de exportación */
#ifndef TRAMA_H
#define TRAMA_H

#include <stdint.h>

#include "registro.h"

/* Constantes de la trama */
#define TRAMA_SINC_0       0xA5u
#define TRAMA_SINC_1       0x5Au
#define TRAMA_VERSION      1u
#define TRAMA_ENCABEZADO   28u
#define TRAMA_MUESTRA      8u
#define TRAMA_CRC_INICIAL  0xFFFFu

/* Datos del encabezado */
typedef struct {
    uint8_t  estado;
    uint32_t f_sw;          /* Hz */
    uint32_t ts_ns;         /* ns */
    uint16_t k_reg;
    uint16_t n;             /* muestras enviadas */
    uint16_t amplitud_ma;   /* mA */
    uint16_t causa;         /* bits de falla */
    uint32_t t_isr_max;     /* ciclos */
    uint32_t perdidas;
} trama_info_t;

uint16_t trama_crc(uint16_t crc, uint8_t byte);
void     trama_encabezado(uint8_t buf[TRAMA_ENCABEZADO], const trama_info_t *info);
void     trama_muestra(uint8_t buf[TRAMA_MUESTRA], const muestra_t *m);

#endif
