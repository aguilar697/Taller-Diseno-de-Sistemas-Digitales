/*
 * Prueba de la supervisión de fallas en PC.
 * Valores de prueba: I_MAX = 1,5 A, códigos válidos 16..4079,
 * Ts - MARGEN_ISR = 4000 ciclos (50 us menos 10 us a 100 MHz).
 */
#include <stdio.h>

#include "supervision.h"

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
    supervision_t sup;
    uint16_t bits;

    supervision_iniciar(&sup, 1.5f, 16u, 4079u, 4000u);
    comprobar(sup.causa == 0 && !supervision_hay_falla(&sup), "iniciar: sin causa");

    /* Operación normal */
    bits = supervision_muestra(&sup, 1.0f, 2048u, 0);
    comprobar(bits == 0 && !supervision_hay_falla(&sup), "1 A, código normal: sin falla");
    bits = supervision_muestra(&sup, 1.5f, 16u, 0);
    comprobar(bits == 0, "justo en I_MAX y en CODIGO_MIN: sin falla (límites incluidos)");
    bits = supervision_muestra(&sup, -1.5f, 4079u, 0);
    comprobar(bits == 0, "justo en -I_MAX y en CODIGO_MAX: sin falla");

    /* Cada condición por separado */
    bits = supervision_muestra(&sup, 1.6f, 2048u, 0);
    comprobar(bits == FALLA_SOBRECORRIENTE, "+1,6 A: sobrecorriente");
    supervision_reconocer(&sup);
    bits = supervision_muestra(&sup, -1.6f, 2048u, 0);
    comprobar(bits == FALLA_SOBRECORRIENTE, "-1,6 A: sobrecorriente (ambos signos)");
    supervision_reconocer(&sup);
    bits = supervision_muestra(&sup, 0.0f, 15u, 0);
    comprobar(bits == FALLA_CODIGO, "código 15: fuera de rango por abajo");
    supervision_reconocer(&sup);
    bits = supervision_muestra(&sup, 0.0f, 4080u, 0);
    comprobar(bits == FALLA_CODIGO, "código 4080: fuera de rango por arriba");
    supervision_reconocer(&sup);
    bits = supervision_muestra(&sup, 0.0f, 2048u, 1);
    comprobar(bits == FALLA_MUESTRAS, "muestras anómalas seguidas: falla de muestras");
    supervision_reconocer(&sup);

    /* Tiempo de la ISR */
    comprobar(supervision_tiempo(&sup, 4000u) == 0, "4000 ciclos: dentro del plazo");
    comprobar(supervision_tiempo(&sup, 4001u) == FALLA_TIEMPO, "4001 ciclos: exceso de tiempo");
    supervision_reconocer(&sup);

    /* Configuración */
    supervision_marcar(&sup, FALLA_CONFIGURACION);
    comprobar(sup.causa == FALLA_CONFIGURACION, "marcar: error de configuración");
    supervision_reconocer(&sup);

    /* Varias a la vez y causa guardada */
    bits = supervision_muestra(&sup, 2.0f, 4095u, 1);
    comprobar(bits == (FALLA_SOBRECORRIENTE | FALLA_CODIGO | FALLA_MUESTRAS),
              "tres condiciones a la vez: tres bits");
    bits = supervision_muestra(&sup, 0.5f, 2048u, 0);
    comprobar(bits == 0 && sup.causa == (FALLA_SOBRECORRIENTE | FALLA_CODIGO | FALLA_MUESTRAS),
              "la condición desaparece, pero la causa queda guardada");
    comprobar(supervision_hay_falla(&sup), "sigue en falla hasta reconocer");
    supervision_reconocer(&sup);
    comprobar(sup.causa == 0 && !supervision_hay_falla(&sup), "reconocer borra la causa");

    printf("\n%s: %d fallas\n", fallas ? "RESULTADO NEGATIVO" : "RESULTADO POSITIVO", fallas);
    return fallas ? 1 : 0;
}
