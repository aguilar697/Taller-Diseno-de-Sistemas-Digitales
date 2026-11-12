/* Driver del AXI Timer (PG079): contador 0 = interrupción, contador 1 = medición */
#include "drivers.h"
#include "mmio.h"

/* Dirección base (en la PC la define la prueba) */
#ifndef TIMER_BASE
#include "direcciones.h"
#endif

/* Registros */
#define TCSR0    0x00u
#define TLR0     0x04u
#define TCSR1    0x10u
#define TLR1     0x14u
#define TCR1     0x18u

/* Bits de TCSR */
#define TCSR_UDT     0x002u    /* cuenta descendente */
#define TCSR_ARHT    0x010u    /* recarga automática */
#define TCSR_LOAD    0x020u    /* cargar TLR */
#define TCSR_ENIT    0x040u    /* habilitar interrupción */
#define TCSR_ENT     0x080u    /* habilitar contador */
#define TCSR_TINT    0x100u    /* interrupción pendiente (se borra con 1) */

/* Configuración sin arrancar */
void timer_configurar(uint32_t carga)
{
    /* Contador 0: descendente con recarga; período = (TLR0 + 2) ciclos */
    mmio_escribir32(TIMER_BASE + TCSR0, 0u);
    mmio_escribir32(TIMER_BASE + TLR0, carga - 2u);
    mmio_escribir32(TIMER_BASE + TCSR0, TCSR_LOAD);
    mmio_escribir32(TIMER_BASE + TCSR0, TCSR_UDT | TCSR_ARHT | TCSR_ENIT);

    /* Contador 1: ascendente libre */
    mmio_escribir32(TIMER_BASE + TCSR1, 0u);
    mmio_escribir32(TIMER_BASE + TLR1, 0u);
    mmio_escribir32(TIMER_BASE + TCSR1, TCSR_LOAD);
    mmio_escribir32(TIMER_BASE + TCSR1, TCSR_ARHT);
}

/* Arrancar los dos contadores */
void timer_arrancar(void)
{
    mmio_escribir32(TIMER_BASE + TCSR1, mmio_leer32(TIMER_BASE + TCSR1) | TCSR_ENT);
    mmio_escribir32(TIMER_BASE + TCSR0, mmio_leer32(TIMER_BASE + TCSR0) | TCSR_ENT);
}

/* Contador libre para medir la ISR */
uint32_t timer_contador(void)
{
    return mmio_leer32(TIMER_BASE + TCR1);
}

/* Reconocer la interrupción del contador 0 */
void timer_reconocer(void)
{
    mmio_escribir32(TIMER_BASE + TCSR0, mmio_leer32(TIMER_BASE + TCSR0) | TCSR_TINT);
}
