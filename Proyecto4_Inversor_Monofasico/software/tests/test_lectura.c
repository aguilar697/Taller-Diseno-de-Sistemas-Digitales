/*
 * Prueba de la lectura y validación de la muestra en PC.
 * Valores de prueba: offset = 2048, ganancia = 0,001 A por código,
 * N_FALLA_MUESTRAS = 3.
 */
#include <math.h>
#include <stdio.h>

#include "lectura.h"

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
    lectura_t l;
    lectura_clase_t c;
    int i;

    /* Conversión a amperios */
    lectura_iniciar(&l, 2048.0f, 0.001f, 1u, 3u, 10u);
    comprobar(l.n_ant == 10u && l.anomalas == 0u && l.perdidas == 0u,
              "iniciar: n_ant = 10 y contadores en cero");
    comprobar(fabsf(lectura_a_amperios(&l, 2048u)) < 1e-6f, "código 2048 -> 0 A");
    comprobar(fabsf(lectura_a_amperios(&l, 3048u) - 1.0f) < 1e-4f, "código 3048 -> +1 A");
    comprobar(fabsf(lectura_a_amperios(&l, 1048u) + 1.0f) < 1e-4f, "código 1048 -> -1 A (resta en float)");

    /* Clasificación con N_PWM_POR_CONTROL = 1 */
    c = lectura_clasificar(&l, 11u);
    comprobar(c == LECTURA_NUEVA && l.anomalas == 0u, "10 -> 11: nueva");
    c = lectura_clasificar(&l, 11u);
    comprobar(c == LECTURA_REPETIDA && l.anomalas == 1u && l.perdidas == 0u,
              "11 -> 11: repetida, 1 anómala");
    c = lectura_clasificar(&l, 14u);
    comprobar(c == LECTURA_PERDIDAS && l.perdidas == 2u && l.anomalas == 2u,
              "11 -> 14: perdidas (2 conversiones), 2 anómalas");
    comprobar(lectura_falla(&l) == 0, "2 anómalas seguidas: todavía sin falla");
    c = lectura_clasificar(&l, 15u);
    comprobar(c == LECTURA_NUEVA && l.anomalas == 0u, "una muestra nueva borra las anómalas");

    /* Falla por muestras anómalas seguidas */
    lectura_clasificar(&l, 15u);
    lectura_clasificar(&l, 15u);
    comprobar(lectura_falla(&l) == 0, "2 repetidas seguidas: sin falla");
    lectura_clasificar(&l, 15u);
    comprobar(lectura_falla(&l) == 1, "3 repetidas seguidas: falla");

    /* Vuelta del contador de 16 bits */
    lectura_iniciar(&l, 2048.0f, 0.001f, 1u, 3u, 65535u);
    c = lectura_clasificar(&l, 0u);
    comprobar(c == LECTURA_NUEVA, "65535 -> 0: nueva (vuelta de 16 bits)");
    lectura_iniciar(&l, 2048.0f, 0.001f, 1u, 3u, 65535u);
    c = lectura_clasificar(&l, 1u);
    comprobar(c == LECTURA_PERDIDAS && l.perdidas == 1u, "65535 -> 1: perdió 1 conversión");

    /* Dos períodos PWM por período de control (N = 2) */
    lectura_iniciar(&l, 2048.0f, 0.001f, 2u, 3u, 100u);
    c = lectura_clasificar(&l, 102u);
    comprobar(c == LECTURA_NUEVA, "N = 2: avance de 2 es nueva");
    c = lectura_clasificar(&l, 103u);
    comprobar(c == LECTURA_PERDIDAS && l.perdidas == 0u && l.anomalas == 1u,
              "N = 2: avance de 1 es anómala pero no suma pérdidas");
    c = lectura_clasificar(&l, 107u);
    comprobar(c == LECTURA_PERDIDAS && l.perdidas == 2u, "N = 2: avance de 4 pierde 2");

    /* El contador de anómalas no da la vuelta */
    lectura_iniciar(&l, 2048.0f, 0.001f, 1u, 3u, 5u);
    for (i = 0; i < 70000; i++) {
        lectura_clasificar(&l, 5u);
    }
    comprobar(lectura_falla(&l) == 1, "70000 repetidas seguidas: sigue en falla (sin vuelta)");

    printf("\n%s: %d fallas\n", fallas ? "RESULTADO NEGATIVO" : "RESULTADO POSITIVO", fallas);
    return fallas ? 1 : 0;
}
