/* Conexion del Timer al controlador AXI INTC de la plataforma. */
#include "plataforma.h"

#include "xil_exception.h"
#include "xparameters.h"

/* Rutina de la aplicación */
static void (*rutina_isr)(void);

/* Entrada de la interrupción */
static void atender(void *ref)
{
    (void)ref;
    rutina_isr();
}

#ifdef PLATAFORMA_CON_INTC

/* Variante con AXI INTC */
#include "xintc.h"

#include "direcciones.h"
#include "xstatus.h"
#define TIMER_INTR_ID     0u

static XIntc intc;

void plataforma_iniciar_interrupciones(void (*rutina)(void))
{
    rutina_isr = rutina;
    if (XIntc_Initialize(&intc, INTC_BASE) != XST_SUCCESS ||
        XIntc_Connect(&intc, TIMER_INTR_ID, (XInterruptHandler)atender, NULL) != XST_SUCCESS ||
        XIntc_Start(&intc, XIN_REAL_MODE) != XST_SUCCESS) {
        /* No iniciar una aplicacion que dependa de una ISR inexistente. */
        for (;;) { __asm__ volatile ("nop"); }
    }
    XIntc_Enable(&intc, TIMER_INTR_ID);

    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT,
                                 (Xil_ExceptionHandler)XIntc_InterruptHandler, &intc);
    Xil_ExceptionEnable();
}

#else

/* Variante directa: el Timer va a la entrada de interrupción del procesador */
void plataforma_iniciar_interrupciones(void (*rutina)(void))
{
    rutina_isr = rutina;
    Xil_ExceptionInit();
    Xil_ExceptionRegisterHandler(XIL_EXCEPTION_ID_INT, (Xil_ExceptionHandler)atender, NULL);
    Xil_ExceptionEnable();
}

#endif
