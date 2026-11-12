/* Driver de GPIO (AXI GPIO, PG144) */
#include "drivers.h"
#include "mmio.h"
#include "parametros.h"

/* Direcciones base (en la PC las define la prueba) */
#ifndef GPIO_ENTRADAS_BASE
#include "direcciones.h"
#endif

/* Registros */
#define GPIO_DATA    0x00u    /* canal 1 */
#define GPIO_TRI     0x04u    /* 1 = entrada */
#define GPIO2_DATA   0x08u    /* canal 2 */
#define GPIO2_TRI    0x0Cu

/* Distribución (PRUEBA: Daniel) */
#define BOTONES_MASCARA      0x7u    /* entradas, canal 1: habilitar, reconocer, exportar */
#define INTERRUPTORES_MASC   0x3u    /* entradas, canal 2: amplitud */
#define MEDICION_BIT         0x1u    /* salidas, canal 2: pulso de la ISR */

/* Direcciones de los pines */
void gpio_iniciar(void)
{
    mmio_escribir32(GPIO_ENTRADAS_BASE + GPIO_TRI, 0xFFFFFFFFu);
    mmio_escribir32(GPIO_ENTRADAS_BASE + GPIO2_TRI, 0xFFFFFFFFu);
    mmio_escribir32(GPIO_SALIDAS_BASE + GPIO_TRI, 0u);
    mmio_escribir32(GPIO_SALIDAS_BASE + GPIO2_TRI, 0u);
}

/* Botones y amplitud en una palabra (bits de parametros.h) */
uint32_t gpio_leer_entradas(void)
{
    uint32_t botones = mmio_leer32(GPIO_ENTRADAS_BASE + GPIO_DATA) & BOTONES_MASCARA;
    uint32_t amplitud = mmio_leer32(GPIO_ENTRADAS_BASE + GPIO2_DATA) & INTERRUPTORES_MASC;
    return botones | (amplitud << SW_AMPLITUD_POS);
}

/* LED (canal 1 de salidas, solo el lazo principal) */
void gpio_escribir_led(uint32_t mascara)
{
    mmio_escribir32(GPIO_SALIDAS_BASE + GPIO_DATA, mascara);
}

/* Salida de medición (canal 2 de salidas, solo la ISR) */
void gpio_medicion(int nivel)
{
    mmio_escribir32(GPIO_SALIDAS_BASE + GPIO2_DATA, nivel ? MEDICION_BIT : 0u);
}
