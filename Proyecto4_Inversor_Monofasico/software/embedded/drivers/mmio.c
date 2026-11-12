/* Acceso a registros de 32 bits en MicroBlaze V */
#include "mmio.h"

#include "xil_io.h"

/* Lectura */
uint32_t mmio_leer32(uintptr_t direccion)
{
    return Xil_In32(direccion);
}

/* Escritura */
void mmio_escribir32(uintptr_t direccion, uint32_t valor)
{
    Xil_Out32(direccion, valor);
}
