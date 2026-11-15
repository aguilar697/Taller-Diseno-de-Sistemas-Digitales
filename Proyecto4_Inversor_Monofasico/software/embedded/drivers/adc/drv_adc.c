/* Driver del ADC/XADC (registros de adc_regs.h) */
#include "adc_regs.h"
#include "drivers.h"
#include "mmio.h"

/* Dirección base (en la PC la define la prueba) */
#ifndef ADC_BASE
#include "direcciones.h"
#endif

/* Configuración: sin errores persistentes al iniciar */
int adc_configurar(void)
{
    return mmio_leer32(ADC_BASE + ADC_ERROR_OFFSET) == 0u;
}

/* Lectura: estado, SAMPLE y reconocimiento con el token de 32 bits */
void adc_leer(uint16_t *codigo, uint16_t *n, uint32_t *estado)
{
    uint32_t muestra, token;

    /* Estado */
    *estado = mmio_leer32(ADC_BASE + ADC_STATUS_OFFSET);

    /* SAMPLE: ID[31:16] y código[11:0] en una sola lectura */
    muestra = mmio_leer32(ADC_BASE + ADC_SAMPLE_OFFSET);
    *codigo = (uint16_t)(muestra & ADC_SAMPLE_RAW_MASK);
    *n = (uint16_t)((muestra >> ADC_SAMPLE_ID_SHIFT) & ADC_SAMPLE_ID_MASK);

    /* Reconocer siempre la muestra leída (un ACK repetido no tiene efecto) */
    token = mmio_leer32(ADC_BASE + ADC_ACK_ID_OFFSET);
    if (token != ADC_ACK_ID_INVALID) {
        mmio_escribir32(ADC_BASE + ADC_ACK_ID_OFFSET, token);
    }
}

/* Inicio de conversión por software */
void adc_iniciar_conversion(void)
{
    mmio_escribir32(ADC_BASE + ADC_CONTROL_OFFSET, ADC_CONTROL_START);
}
