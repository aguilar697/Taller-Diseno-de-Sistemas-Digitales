/* Driver de UART Lite (PG142), solo transmisión */
#include "drivers.h"
#include "mmio.h"

/* Dirección base (en la PC la define la prueba) */
#ifndef UART_BASE
#include "direcciones.h"
#endif

/* Registros */
#define UART_TX_FIFO     0x04u
#define UART_STAT        0x08u
#define UART_CTRL        0x0Cu

/* Bits */
#define STAT_TX_LLENA    0x08u
#define CTRL_RST_TX      0x01u
#define CTRL_RST_RX      0x02u

/* Inicio: FIFOs vacías y sin interrupciones */
void uart_iniciar(void)
{
    mmio_escribir32(UART_BASE + UART_CTRL, CTRL_RST_TX | CTRL_RST_RX);
}

/* ¿FIFO de transmisión llena? */
int uart_tx_llena(void)
{
    return (mmio_leer32(UART_BASE + UART_STAT) & STAT_TX_LLENA) != 0u;
}

/* Escribir un byte (sin espera) */
void uart_escribir(uint8_t byte)
{
    mmio_escribir32(UART_BASE + UART_TX_FIFO, byte);
}
