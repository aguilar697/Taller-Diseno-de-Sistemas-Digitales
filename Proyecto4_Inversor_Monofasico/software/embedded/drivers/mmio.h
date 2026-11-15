/* Acceso a registros de 32 bits */
#ifndef MMIO_H
#define MMIO_H

#include <stdint.h>

/* En la tarjeta: Xil_In32 / Xil_Out32 (mmio.c). En la PC: modelo de la prueba */
uint32_t mmio_leer32(uintptr_t direccion);
void     mmio_escribir32(uintptr_t direccion, uint32_t valor);

#endif
