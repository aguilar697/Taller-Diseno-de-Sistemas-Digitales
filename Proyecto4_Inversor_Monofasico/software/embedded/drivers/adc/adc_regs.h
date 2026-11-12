/* Contrato de registros del periférico ADC/XADC, independiente del BSP y de su base.
 * SAMPLE conserva ID 16 y código de 12; ACK_ID transporta el identificador completo de 32 bits.
 * Los accesos MMIO deben ser de 32 bits, ordenados y serializados entre consumidores.
 *
 * Protocolo definitivo: leer SAMPLE captura en hardware la palabra y su token.
 * Leer ACK_ID devuelve ese token capturado, aunque el ADC publique entre lecturas.
 * No se supone atomicidad entre transacciones AXI ni se lee el token vivo del ADC.
 * La pareja SAMPLE/ACK_ID exige accesos MMIO ordenados, no cacheados, y exclusión
 * entre lectores. Conservar el token local; no actualizarlo antes de reconocer.
 * ACK_ID=0 cancela el reconocimiento: falta snapshot o se agotaron los tokens.
 *
 * Reset inicia otra sesión y puede reutilizar numeros: el driver debe descartar
 * operaciones/tokens anteriores y coordinar reset con la captura y el write ACK.
 * Un reset externo no notificado queda fuera de esa garantía de software.
 *
 * Ejemplo con primitivas y control de sesión suministrados por la plataforma:
 *   lock_reader_and_reset();
 *   session = current_session();
 *   sample  = read32(base + ADC_SAMPLE_OFFSET);
 *   token   = read32(base + ADC_ACK_ID_OFFSET); // Snapshot de sample, no valor vivo.
 *   unlock_reader_and_reset();
 *   ... consumir sample y conservar token ...
 *   lock_reader_and_reset();
 *   if (session == current_session() && token != ADC_ACK_ID_INVALID)
 *       write32(base + ADC_ACK_ID_OFFSET, token);
 *   unlock_reader_and_reset();
 * No implementa barreras/BSP, control PR ni conversión de código a corriente.
 */
#ifndef ADC_REGS_H
#define ADC_REGS_H
#include <stdint.h>

/* Offsets en bytes. Address Editor asigna la base durante la integración. */
#define ADC_CONTROL_OFFSET       UINT32_C(0x00)
#define ADC_STATUS_OFFSET        UINT32_C(0x04)
#define ADC_SAMPLE_OFFSET        UINT32_C(0x08)
#define ADC_ERROR_OFFSET         UINT32_C(0x0c)
#define ADC_ACK_ID_OFFSET        UINT32_C(0x10)
#define ADC_CONTROL_START        UINT32_C(0x01)
/* Compatibilidad de nombre solamente: el comando antiguo devuelve SLVERR; no usarlo. */
#define ADC_CONTROL_ACK_SAMPLE   UINT32_C(0x02)
#define ADC_ACK_ID_INVALID       UINT32_C(0x00)

/* STATUS: validez/disponibilidad y ocupación del controlador y del XADC. */
#define ADC_STATUS_VALID         UINT32_C(0x01)
#define ADC_STATUS_NEW_DATA      UINT32_C(0x02)
#define ADC_STATUS_BUSY          UINT32_C(0x04)
#define ADC_STATUS_XADC_BUSY     UINT32_C(0x08)
#define ADC_STATUS_MISSED        UINT32_C(0x10)
#define ADC_STATUS_OVERRUN       UINT32_C(0x20)
#define ADC_STATUS_TIMEOUT       UINT32_C(0x40)
/* Los errores son persistentes hasta reset; un ACK no los limpia. */
#define ADC_ERROR_MISSED         UINT32_C(0x01)
#define ADC_ERROR_OVERRUN        UINT32_C(0x02)
#define ADC_ERROR_TIMEOUT        UINT32_C(0x04)

/* Extraer código/ID desde una sola lectura SAMPLE; el ACK usa los 32 bits de ACK_ID. */
#define ADC_SAMPLE_ID_SHIFT      16u
#define ADC_SAMPLE_ID_MASK       UINT32_C(0xffff)
#define ADC_SAMPLE_RAW_MASK      UINT32_C(0x0fff)
#endif
