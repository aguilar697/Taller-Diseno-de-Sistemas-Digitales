/*
 * Prueba de los drivers de GPIO, UART Lite y AXI Timer en PC, con un modelo
 * de sus registros (PG144, PG142 y PG079). Las direcciones base las define
 * la compilación (-D...).
 */
#include <stdio.h>

#include "drivers.h"
#include "mmio.h"
#include "parametros.h"

static int fallas = 0;

static void comprobar(int condicion, const char *descripcion)
{
    printf("[%s] %s\n", condicion ? "PASA" : "FALLA", descripcion);
    if (!condicion) {
        fallas++;
    }
}

/* Modelo de GPIO */
static uint32_t ent_data1 = 0, ent_data2 = 0, ent_tri1 = 0, ent_tri2 = 0;
static uint32_t sal_data1 = 0, sal_data2 = 0, sal_tri1 = 0xFFFFFFFFu, sal_tri2 = 0xFFFFFFFFu;

/* Modelo de UART Lite */
static uint32_t uart_fifo = 0, uart_ctrl = 0, uart_bytes = 0;
static uint8_t  uart_ultimo = 0;

/* Modelo de AXI Timer */
static uint32_t tcsr0 = 0, tlr0 = 0, tcsr1 = 0, tlr1 = 0, tcr1 = 0;
static int      carga0 = 0, carga1 = 0;

#define TINT 0x100u

uint32_t mmio_leer32(uintptr_t d)
{
    if (d == GPIO_ENTRADAS_BASE + 0x00u) return ent_data1;
    if (d == GPIO_ENTRADAS_BASE + 0x08u) return ent_data2;
    if (d == GPIO_SALIDAS_BASE + 0x00u)  return sal_data1;
    if (d == GPIO_SALIDAS_BASE + 0x08u)  return sal_data2;
    if (d == UART_BASE + 0x08u)          return (uart_fifo >= 16u) ? 0x08u : 0u;
    if (d == TIMER_BASE + 0x00u)         return tcsr0;
    if (d == TIMER_BASE + 0x10u)         return tcsr1;
    if (d == TIMER_BASE + 0x18u)         return tcr1;
    return 0;
}

void mmio_escribir32(uintptr_t d, uint32_t v)
{
    if (d == GPIO_ENTRADAS_BASE + 0x04u) ent_tri1 = v;
    else if (d == GPIO_ENTRADAS_BASE + 0x0Cu) ent_tri2 = v;
    else if (d == GPIO_SALIDAS_BASE + 0x00u) sal_data1 = v;
    else if (d == GPIO_SALIDAS_BASE + 0x04u) sal_tri1 = v;
    else if (d == GPIO_SALIDAS_BASE + 0x08u) sal_data2 = v;
    else if (d == GPIO_SALIDAS_BASE + 0x0Cu) sal_tri2 = v;
    else if (d == UART_BASE + 0x04u) { uart_fifo++; uart_bytes++; uart_ultimo = (uint8_t)v; }
    else if (d == UART_BASE + 0x0Cu) { uart_ctrl = v; if (v & 0x1u) uart_fifo = 0; }
    else if (d == TIMER_BASE + 0x04u) tlr0 = v;
    else if (d == TIMER_BASE + 0x14u) tlr1 = v;
    else if (d == TIMER_BASE + 0x00u) {
        if (v & 0x20u) carga0 = 1;
        tcsr0 = (v & ~TINT & ~0x20u) | (tcsr0 & TINT & ~(v & TINT));   /* TINT se borra con 1 */
    } else if (d == TIMER_BASE + 0x10u) {
        if (v & 0x20u) carga1 = 1;
        tcsr1 = (v & ~TINT & ~0x20u) | (tcsr1 & TINT & ~(v & TINT));
    }
}

int main(void)
{
    /* GPIO */
    gpio_iniciar();
    comprobar(ent_tri1 == 0xFFFFFFFFu && ent_tri2 == 0xFFFFFFFFu && sal_tri1 == 0u && sal_tri2 == 0u,
              "gpio_iniciar: entradas como entradas y salidas como salidas");

    ent_data1 = 0x5u;    /* habilitar y exportar */
    ent_data2 = 0x2u;    /* amplitud 1,0 A */
    comprobar(gpio_leer_entradas() == (BTN_HABILITAR | BTN_EXPORTAR | (0x2u << SW_AMPLITUD_POS)),
              "entradas: botones en sus bits y amplitud en SW_AMPLITUD_POS");
    ent_data1 = 0xFFu;
    ent_data2 = 0xFFu;
    comprobar(gpio_leer_entradas() == (0x7u | (0x3u << SW_AMPLITUD_POS)), "bits de más se ignoran");

    gpio_escribir_led(LED_OPERACION | LED_LATIDO);
    gpio_medicion(1);
    comprobar(sal_data1 == (LED_OPERACION | LED_LATIDO) && sal_data2 == 1u, "LED y medición en canales distintos");
    gpio_medicion(0);
    comprobar(sal_data1 == (LED_OPERACION | LED_LATIDO) && sal_data2 == 0u,
              "bajar la medición no toca los LED");

    /* UART */
    uart_fifo = 5u;
    uart_iniciar();
    comprobar((uart_ctrl & 0x3u) == 0x3u && uart_fifo == 0u && !(uart_ctrl & 0x10u),
              "uart_iniciar: FIFOs reiniciadas y sin interrupciones");
    while (!uart_tx_llena() && uart_bytes < 100u) {
        uart_escribir((uint8_t)uart_bytes);
    }
    comprobar(uart_bytes == 16u && uart_ultimo == 15u, "se escriben 16 bytes hasta que la FIFO se llena");

    /* Timer */
    timer_configurar(CICLOS_POR_TS);
    comprobar(tlr0 == CICLOS_POR_TS - 2u && carga0, "contador 0: TLR0 = carga - 2 y cargado");
    comprobar(tcsr0 == (0x002u | 0x010u | 0x040u), "contador 0: descendente, recarga, interrupción, sin arrancar");
    comprobar(tlr1 == 0u && carga1 && tcsr1 == 0x010u, "contador 1: ascendente libre, sin arrancar");

    timer_arrancar();
    comprobar((tcsr0 & 0x080u) && (tcsr1 & 0x080u) && (tcsr0 & 0x040u),
              "arrancar: los dos contadores habilitados, interrupción conservada");

    tcsr0 |= TINT;
    timer_reconocer();
    comprobar(!(tcsr0 & TINT) && (tcsr0 & 0x080u), "reconocer: borra la interrupción y sigue contando");

    tcr1 = 123456u;
    comprobar(timer_contador() == 123456u, "timer_contador lee el contador 1");

    printf("\n%s: %d fallas\n", fallas ? "RESULTADO NEGATIVO" : "RESULTADO POSITIVO", fallas);
    return fallas ? 1 : 0;
}
