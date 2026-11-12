/* Registro circular de muestras */
#include "registro.h"

/* Amperios a mA int16 (redondeo simétrico y saturación) */
static int16_t a_miliamperios(float a)
{
    float x = a * 1000.0f;

    if (x > 32767.0f) {
        x = 32767.0f;
    } else if (x < -32767.0f) {
        x = -32767.0f;
    }

    if (x >= 0.0f) {
        x = x + 0.5f;
    } else {
        x = x - 0.5f;
    }
    return (int16_t)x;
}

/* Inicio */
void registro_iniciar(registro_t *reg, uint32_t k_reg)
{
    reg->indice = 0;
    reg->cantidad = 0;
    reg->contador = 0;
    reg->k_reg = (k_reg == 0) ? 1 : k_reg;
    reg->congelado = 0;
}

/* Guardar una muestra */
void registro_guardar(registro_t *reg, float i_med, float i_ref, int16_t m_q15, uint16_t n)
{
    /* Congelado: no se toca */
    if (reg->congelado) {
        return;
    }

    /* Submuestreo: una de cada k_reg */
    reg->contador++;
    if (reg->contador < reg->k_reg) {
        return;
    }
    reg->contador = 0;

    /* Escritura de la entrada */
    muestra_t *destino = &reg->datos[reg->indice];
    destino->i_med_ma = a_miliamperios(i_med);
    destino->i_ref_ma = a_miliamperios(i_ref);
    destino->m_q15 = m_q15;
    destino->n = n;

    /* Avance circular (sin %) */
    reg->indice++;
    if (reg->indice == REGISTRO_N_BUF) {
        reg->indice = 0;
    }

    if (reg->cantidad < REGISTRO_N_BUF) {
        reg->cantidad++;
    }
}

/* Congelar */
void registro_congelar(registro_t *reg)
{
    reg->congelado = 1;
}

/* Descongelar */
void registro_descongelar(registro_t *reg)
{
    reg->congelado = 0;
}

/* Cantidad de entradas */
uint32_t registro_cantidad(const registro_t *reg)
{
    return reg->cantidad;
}

/* Lectura en orden cronológico (i = 0 es la más antigua) */
muestra_t registro_leer(const registro_t *reg, uint32_t i)
{
    uint32_t mas_antigua = (reg->cantidad < REGISTRO_N_BUF) ? 0 : reg->indice;

    uint32_t posicion = mas_antigua + i;
    if (posicion >= REGISTRO_N_BUF) {
        posicion -= REGISTRO_N_BUF;
    }
    return reg->datos[posicion];
}
