/* Máquina de exportación por UART */
#ifndef EXPORTACION_H
#define EXPORTACION_H

#include <stdint.h>

#include "registro.h"
#include "trama.h"

/* Estados de la máquina */
typedef enum {
    EXP_REPOSO,
    EXP_ENCABEZADO,
    EXP_MUESTRAS,
    EXP_CRC
} exportacion_estado_t;

/* Estado de la exportación */
typedef struct {
    registro_t *reg;
    int  (*tx_llena)(void);          /* FIFO TX llena */
    void (*tx_escribir)(uint8_t);    /* escribir un byte */
    exportacion_estado_t estado;
    uint8_t  buf[TRAMA_ENCABEZADO];  /* pieza en envío */
    uint32_t largo;                  /* bytes de la pieza */
    uint32_t pos;                    /* próximo byte */
    uint32_t muestra;                /* próxima muestra */
    uint32_t n;                      /* muestras de la trama */
    uint16_t crc;
} exportacion_t;

void exportacion_iniciar(exportacion_t *e, registro_t *reg,
                         int (*tx_llena)(void), void (*tx_escribir)(uint8_t));
int  exportacion_solicitar(exportacion_t *e, const trama_info_t *info);
void exportacion_paso(exportacion_t *e);
int  exportacion_en_curso(const exportacion_t *e);

#endif
