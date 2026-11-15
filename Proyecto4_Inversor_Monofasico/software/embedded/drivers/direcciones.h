/* Direcciones base de los periféricos (PRUEBA: Daniel, desde xparameters.h) */
#ifndef DIRECCIONES_H
#define DIRECCIONES_H

#include "xparameters.h"

/* Completar con los nombres que genere Vitis, por ejemplo:
 * #define PWM_BASE            XPAR_PWM_AXI_0_BASEADDR
 */
/* #define PWM_BASE            */
/* #define ADC_BASE            */
/* #define GPIO_ENTRADAS_BASE  */
/* #define GPIO_SALIDAS_BASE   */
/* #define UART_BASE           */
/* #define TIMER_BASE          */

/* Aviso si falta alguna */
#if !defined(PWM_BASE) || !defined(ADC_BASE) || !defined(GPIO_ENTRADAS_BASE) || \
    !defined(GPIO_SALIDAS_BASE) || !defined(UART_BASE) || !defined(TIMER_BASE)
#error "Completar direcciones.h con las direcciones del Address Editor"
#endif

#endif
