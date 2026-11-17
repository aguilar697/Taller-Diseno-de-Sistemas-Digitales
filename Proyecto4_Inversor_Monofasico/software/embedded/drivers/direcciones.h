/* Direcciones exportadas por el XSA; impide enlazar con un mapa anterior. */
#ifndef DIRECCIONES_H
#define DIRECCIONES_H
#include "xparameters.h"
#ifndef PWM_BASE
#define PWM_BASE XPAR_PWM_SYSTEM_AXI_0_BASEADDR
#endif
#ifndef ADC_BASE
#define ADC_BASE XPAR_ADC_SYSTEM_AXI_0_BASEADDR
#endif
#ifndef GPIO_ENTRADAS_BASE
#define GPIO_ENTRADAS_BASE XPAR_GPIO_INPUTS_BASEADDR
#endif
#ifndef GPIO_SALIDAS_BASE
#define GPIO_SALIDAS_BASE XPAR_GPIO_OUTPUTS_BASEADDR
#endif
#ifndef UART_BASE
#define UART_BASE XPAR_UART_BASEADDR
#endif
#ifndef TIMER_BASE
#define TIMER_BASE XPAR_TIMER_BASEADDR
#endif
#ifndef INTC_BASE
#define INTC_BASE XPAR_MBV_AXI_INTC_BASEADDR
#endif
#if PWM_BASE != 0x44000000u || ADC_BASE != 0x44A00000u
#error "Reconstruya el software con el XSA integrado actual"
#endif
#if XPAR_PWM_SYSTEM_AXI_0_HIGHADDR != 0x44000FFFu || XPAR_ADC_SYSTEM_AXI_0_HIGHADDR != 0x44A00FFFu
#error "Ventanas PWM/ADC distintas de 4 KiB"
#endif
#endif
