/* Formato de la trama de exportación */
#include "trama.h"

/* CRC-16/CCITT-FALSE, un byte a la vez */
uint16_t trama_crc(uint16_t crc, uint8_t byte)
{
    int bit;

    crc ^= (uint16_t)((uint16_t)byte << 8);
    for (bit = 0; bit < 8; bit++) {
        if (crc & 0x8000u) {
            crc = (uint16_t)((crc << 1) ^ 0x1021u);
        } else {
            crc = (uint16_t)(crc << 1);
        }
    }
    return crc;
}

/* Escritura little-endian de 16 bits */
static void poner_16(uint8_t *p, uint16_t v)
{
    p[0] = (uint8_t)(v & 0xFFu);
    p[1] = (uint8_t)(v >> 8);
}

/* Escritura little-endian de 32 bits */
static void poner_32(uint8_t *p, uint32_t v)
{
    p[0] = (uint8_t)(v & 0xFFu);
    p[1] = (uint8_t)((v >> 8) & 0xFFu);
    p[2] = (uint8_t)((v >> 16) & 0xFFu);
    p[3] = (uint8_t)(v >> 24);
}

/* Encabezado de 28 bytes */
void trama_encabezado(uint8_t buf[TRAMA_ENCABEZADO], const trama_info_t *info)
{
    buf[0] = TRAMA_SINC_0;
    buf[1] = TRAMA_SINC_1;
    buf[2] = TRAMA_VERSION;
    buf[3] = info->estado;
    poner_32(&buf[4], info->f_sw);
    poner_32(&buf[8], info->ts_ns);
    poner_16(&buf[12], info->k_reg);
    poner_16(&buf[14], info->n);
    poner_16(&buf[16], info->amplitud_ma);
    poner_16(&buf[18], info->causa);
    poner_32(&buf[20], info->t_isr_max);
    poner_32(&buf[24], info->perdidas);
}

/* Muestra de 8 bytes */
void trama_muestra(uint8_t buf[TRAMA_MUESTRA], const muestra_t *m)
{
    poner_16(&buf[0], (uint16_t)m->i_med_ma);
    poner_16(&buf[2], (uint16_t)m->i_ref_ma);
    poner_16(&buf[4], (uint16_t)m->m_q15);
    poner_16(&buf[6], m->n);
}
