/*
 * Prueba del antirrebote en PC.
 * Valores de prueba: T_REBOTE = 400 iteraciones (20 ms a 20 kHz).
 */
#include <stdio.h>

#include "antirrebote.h"

#define N_REBOTE 400u

static int fallas = 0;

static void comprobar(int condicion, const char *descripcion)
{
    printf("[%s] %s\n", condicion ? "PASA" : "FALLA", descripcion);
    if (!condicion) {
        fallas++;
    }
}

int main(void)
{
    antirrebote_t a;
    uint32_t t, e;

    antirrebote_iniciar(&a, 0x0u, N_REBOTE, 0u);
    comprobar(antirrebote_actualizar(&a, 0x0u, 1u) == 0x0u, "iniciar: estable = 0");

    /* Rebote: el botón alterna antes de cumplir el tiempo y termina en 0 */
    for (t = 10u; t <= 300u; t++) {
        e = antirrebote_actualizar(&a, (t & 1u) ? 0x1u : 0x0u, t);
    }
    comprobar(e == 0x0u, "rebote de 290 iteraciones: no se acepta");

    /* Presión estable */
    antirrebote_actualizar(&a, 0x1u, 1000u);
    e = antirrebote_actualizar(&a, 0x1u, 1399u);
    comprobar(e == 0x0u, "399 iteraciones estable: todavía no");
    e = antirrebote_actualizar(&a, 0x1u, 1400u);
    comprobar(e == 0x1u, "400 iteraciones estable: aceptado");

    /* Flancos */
    comprobar(antirrebote_flancos(&a) == 0x1u, "flanco de subida detectado una vez");
    comprobar(antirrebote_flancos(&a) == 0x0u, "segunda consulta: sin flanco nuevo");

    /* Soltar: no genera flanco de subida */
    antirrebote_actualizar(&a, 0x0u, 2000u);
    e = antirrebote_actualizar(&a, 0x0u, 2400u);
    comprobar(e == 0x0u && antirrebote_flancos(&a) == 0x0u, "soltar: estable = 0, sin flanco");

    /* Varios bits independientes de la misma lectura */
    antirrebote_actualizar(&a, 0x6u, 3000u);
    e = antirrebote_actualizar(&a, 0x6u, 3400u);
    comprobar(e == 0x6u && antirrebote_flancos(&a) == 0x6u, "dos botones a la vez: dos flancos");

    /* Vuelta del contador de iteraciones */
    antirrebote_iniciar(&a, 0x0u, N_REBOTE, 0xFFFFFF00u);
    antirrebote_actualizar(&a, 0x1u, 0xFFFFFF00u);
    e = antirrebote_actualizar(&a, 0x1u, 0x00000090u);   /* 400 iteraciones después */
    comprobar(e == 0x1u, "contador de la ISR da la vuelta: se acepta igual");

    printf("\n%s: %d fallas\n", fallas ? "RESULTADO NEGATIVO" : "RESULTADO POSITIVO", fallas);
    return fallas ? 1 : 0;
}
