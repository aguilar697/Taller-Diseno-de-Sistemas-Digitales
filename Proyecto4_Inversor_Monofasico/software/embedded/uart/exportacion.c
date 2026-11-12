/* Máquina de exportación por UART */
#include "exportacion.h"

/* Inicio */
void exportacion_iniciar(exportacion_t *e, registro_t *reg,
                         int (*tx_llena)(void), void (*tx_escribir)(uint8_t))
{
    e->reg = reg;
    e->tx_llena = tx_llena;
    e->tx_escribir = tx_escribir;
    e->estado = EXP_REPOSO;
    e->largo = 0;
    e->pos = 0;
    e->muestra = 0;
    e->n = 0;
    e->crc = TRAMA_CRC_INICIAL;
}

/* Siguiente pieza: muestra o CRC */
static void siguiente_pieza(exportacion_t *e)
{
    e->pos = 0;
    if (e->muestra < e->n) {
        muestra_t m = registro_leer(e->reg, e->muestra);
        trama_muestra(e->buf, &m);
        e->largo = TRAMA_MUESTRA;
        e->muestra++;
        e->estado = EXP_MUESTRAS;
    } else {
        e->buf[0] = (uint8_t)(e->crc & 0xFFu);
        e->buf[1] = (uint8_t)(e->crc >> 8);
        e->largo = 2;
        e->estado = EXP_CRC;
    }
}

/* REPOSO -> ENCABEZADO: congelar y armar el encabezado (0 si ya hay una en curso) */
int exportacion_solicitar(exportacion_t *e, const trama_info_t *info)
{
    trama_info_t datos;

    if (e->estado != EXP_REPOSO) {
        return 0;
    }

    registro_congelar(e->reg);
    datos = *info;
    datos.n = (uint16_t)registro_cantidad(e->reg);

    trama_encabezado(e->buf, &datos);
    e->largo = TRAMA_ENCABEZADO;
    e->pos = 0;
    e->muestra = 0;
    e->n = datos.n;
    e->crc = TRAMA_CRC_INICIAL;
    e->estado = EXP_ENCABEZADO;
    return 1;
}

/* Un paso: escribir mientras la FIFO tenga espacio */
void exportacion_paso(exportacion_t *e)
{
    while (e->estado != EXP_REPOSO && !e->tx_llena()) {
        uint8_t byte = e->buf[e->pos];
        e->tx_escribir(byte);

        /* CRC desde el byte 2 hasta la última muestra */
        if (e->estado == EXP_MUESTRAS || (e->estado == EXP_ENCABEZADO && e->pos >= 2)) {
            e->crc = trama_crc(e->crc, byte);
        }

        e->pos++;
        if (e->pos < e->largo) {
            continue;
        }

        /* Pieza terminada */
        if (e->estado == EXP_CRC) {
            registro_descongelar(e->reg);
            e->estado = EXP_REPOSO;
        } else {
            siguiente_pieza(e);
        }
    }
}

/* ¿Exportación en curso? */
int exportacion_en_curso(const exportacion_t *e)
{
    return e->estado != EXP_REPOSO;
}
