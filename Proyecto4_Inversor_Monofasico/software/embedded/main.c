/* Programa principal: inicialización y lazo principal (figura 2, nivel 4) */
#include "aplicacion.h"
#include "drivers.h"
#include "plataforma.h"

/* Aplicación global (incluye el registro de 8 KB) */
static aplicacion_t app;

/* Rutina de la interrupción del Timer */
static void rutina_timer(void)
{
    app_isr(&app);
}

int main(void)
{
    /* Periféricos de la plataforma */
    gpio_iniciar();
    uart_iniciar();

    /* Inicialización (termina en DETENIDO o FALLA) */
    app_iniciar(&app);

    /* Arrancar el Timer y habilitar interrupciones */
    plataforma_iniciar_interrupciones(rutina_timer);
    timer_arrancar();

    /* Lazo principal */
    for (;;) {
        app_lazo_paso(&app);
    }
}
