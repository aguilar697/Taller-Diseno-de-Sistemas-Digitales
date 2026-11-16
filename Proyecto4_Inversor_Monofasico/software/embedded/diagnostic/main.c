#include "xparameters.h"
#include "xstatus.h"
#include "xuartlite.h"
#include "xuartlite_l.h"

/* Diagnostico preparado para ejecucion posterior; aun no probado en FPGA. */
static XUartLite uart;
volatile unsigned int diagnostic_status;
volatile unsigned int global_value = 7U;
volatile unsigned int integer_a = 19U;
volatile unsigned int integer_b = 23U;
volatile float float_a = 1.25f;
volatile float float_b = 2.5f;
volatile float float_result;

static void send_text(const char *text)
{
    while (*text != '\0') {
        XUartLite_SendByte(uart.RegBaseAddress, (u8)*text);
        ++text;
    }
}

__attribute__((noinline)) static unsigned int run_checks(void)
{
    unsigned int failures = 0U;
    volatile unsigned int local_stack_value = 0x13579BDFU;
    volatile float local_sum = float_a + float_b;

    if ((integer_a + integer_b) != 42U) {
        failures |= 1U;
    }
    float_result = local_sum;
    if (float_result != 3.75f) {
        failures |= 2U;
    }
    global_value = 123U;
    if (global_value != 123U) {
        failures |= 4U;
    }
    local_stack_value ^= 0xFFFFFFFFU;
    if (local_stack_value != 0xECA86420U) {
        failures |= 8U;
    }
    return failures;
}

int main(void)
{
    diagnostic_status = 0xFFFFFFFFU;
    if (XUartLite_Initialize(&uart, XPAR_UART_BASEADDR) != XST_SUCCESS) {
        diagnostic_status = 0x80000000U;
        for (;;) {
            __asm__ volatile ("nop");
        }
    }
    XUartLite_ResetFifos(&uart);
    XUartLite_DisableInterrupt(&uart);
    send_text("EL3313 MicroBlaze V: RV32, 100 MHz, UART 115200 8N1\n");

    diagnostic_status = run_checks();
    if (diagnostic_status == 0U) {
        send_text("DIAGNOSTICO: ENTEROS FLOAT GLOBAL PILA OK\n");
    } else {
        send_text("DIAGNOSTICO: ERROR; revisar diagnostic_status\n");
    }
    for (;;) {
        __asm__ volatile ("nop");
    }
}
