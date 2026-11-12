/*
 * Prueba de la referencia sinusoidal en PC.
 * Simula 1 s de iteraciones con Ts = 50 us y comprueba frecuencia,
 * amplitud y que el cambio de amplitud ocurra solo en el cruce por cero.
 */
#include <math.h>
#include <stdio.h>

#include "referencia.h"

#define F_REF   50.0f
#define TS      50e-6f
#define N_ITER  20000      /* 1 s */

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
    referencia_t ref;

    /* 1. Avance de fase */
    referencia_iniciar(&ref, F_REF, TS);
    comprobar(ref.delta_theta == 10737418u, "delta_theta = 10 737 418 para 50 Hz y 50 us");
    comprobar(referencia_paso(&ref) == 0.0f, "la referencia vale 0 sin amplitud pedida");

    /* 2. Frecuencia: 50 vueltas en 1 s. La vuelta 50 cae justo en t = 1 s;
     * como delta_theta se redondeó hacia abajo (,24), llega una iteración
     * después, por eso se simula N_ITER + 1. */
    referencia_iniciar(&ref, F_REF, TS);
    int vueltas = 0;
    for (int k = 0; k < N_ITER + 1; k++) {
        uint32_t anterior = ref.theta;
        referencia_paso(&ref);
        if (ref.theta < anterior) {
            vueltas++;
        }
    }
    comprobar(vueltas == 50, "50 cruces por cero en 1 s");

    /* 3. Amplitud: el pico es la amplitud pedida */
    referencia_iniciar(&ref, F_REF, TS);
    referencia_pedir_amplitud(&ref, 0.5f);
    float maximo = 0.0f;
    float minimo = 0.0f;
    for (int k = 0; k < N_ITER; k++) {
        float i_ref = referencia_paso(&ref);
        if (i_ref > maximo) maximo = i_ref;
        if (i_ref < minimo) minimo = i_ref;
    }
    comprobar(fabsf(maximo - 0.5f) < 0.001f, "pico positivo = 0,5 A");
    comprobar(fabsf(minimo + 0.5f) < 0.001f, "pico negativo = -0,5 A");

    /* 4. Cambio de amplitud a mitad de período: debe esperar al cruce por cero */
    referencia_iniciar(&ref, F_REF, TS);
    referencia_pedir_amplitud(&ref, 0.2f);
    for (int k = 0; k < 500; k++) {          /* 1,25 períodos: la fase queda en 90° */
        referencia_paso(&ref);
    }
    referencia_pedir_amplitud(&ref, 0.5f);   /* se pide el cambio en el pico */
    float siguiente = referencia_paso(&ref);
    comprobar(fabsf(siguiente) <= 0.2001f, "el cambio no se aplica en el pico (sin salto)");

    int iteraciones_hasta_cambio = 0;
    while (ref.amplitud != 0.5f && iteraciones_hasta_cambio < 1000) {
        uint32_t anterior = ref.theta;
        referencia_paso(&ref);
        iteraciones_hasta_cambio++;
        if (ref.amplitud == 0.5f) {
            comprobar(ref.theta < anterior, "el cambio ocurre justo cuando theta da la vuelta");
        }
    }
    comprobar(ref.amplitud == 0.5f, "la amplitud nueva se aplica en menos de un período");

    /* Arranque: θ en cero y la amplitud pedida activa desde la primera iteración */
    referencia_iniciar(&ref, F_REF, TS);
    referencia_pedir_amplitud(&ref, 1.0f);
    ref.theta = 0x80000000u;
    referencia_arrancar(&ref);
    comprobar(ref.theta == 0u && ref.amplitud == 1.0f, "arrancar: theta = 0 y amplitud = la pedida");
    {
        float pico = 0.0f;
        for (int k = 0; k < 100; k++) {          /* primer cuarto de período */
            float v = referencia_paso(&ref);
            if (v > pico) {
                pico = v;
            }
        }
        comprobar(fabsf(pico - 1.0f) < 0.001f, "arrancar: llega al pico de 1 A sin esperar un cruce");
    }

    printf("\n%s: %d falla(s)\n", fallas == 0 ? "RESULTADO OK" : "RESULTADO CON FALLAS", fallas);
    return fallas == 0 ? 0 : 1;
}
