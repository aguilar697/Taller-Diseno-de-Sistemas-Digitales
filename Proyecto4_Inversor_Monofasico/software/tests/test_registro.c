/*
 * Prueba del registro circular en PC.
 * Se compila con REGISTRO_N_BUF = 8 para ver la vuelta del buffer con pocos datos.
 */
#include <stdio.h>

#include "registro.h"

static int fallas = 0;

static void comprobar(int condicion, const char *descripcion)
{
    printf("[%s] %s\n", condicion ? "PASA" : "FALLA", descripcion);
    if (!condicion) {
        fallas++;
    }
}

/* Fuera de las funciones: en MicroBlaze un registro_t real no cabe en la pila */
static registro_t reg;

int main(void)
{
    muestra_t m;

    /* 1. Arranque */
    registro_iniciar(&reg, 1);
    comprobar(registro_cantidad(&reg) == 0, "arranca vacío");

    /* 2. Conversión a mA */
    registro_guardar(&reg, 0.5f, -0.2f, 1234, 7);
    m = registro_leer(&reg, 0);
    comprobar(m.i_med_ma == 500 && m.i_ref_ma == -200, "0,5 A -> 500 mA y -0,2 A -> -200 mA");
    comprobar(m.m_q15 == 1234 && m.n == 7, "m y n se guardan sin cambios");

    registro_iniciar(&reg, 1);
    registro_guardar(&reg, 0.0012f, -0.0012f, 0, 0);
    m = registro_leer(&reg, 0);
    comprobar(m.i_med_ma == 1 && m.i_ref_ma == -1, "redondeo simétrico (±1,2 mA -> ±1)");

    registro_guardar(&reg, 100.0f, -100.0f, 0, 0);
    m = registro_leer(&reg, 1);
    comprobar(m.i_med_ma == 32767 && m.i_ref_ma == -32767, "saturación en ±32 767 mA");

    /* 3. Llenado parcial: orden cronológico desde 0 */
    registro_iniciar(&reg, 1);
    for (uint16_t k = 0; k < 5; k++) {
        registro_guardar(&reg, 0.0f, 0.0f, 0, k);
    }
    m = registro_leer(&reg, 0);
    muestra_t ultima = registro_leer(&reg, 4);
    comprobar(registro_cantidad(&reg) == 5 && m.n == 0 && ultima.n == 4,
              "con 5 de 8: cantidad 5, de n = 0 a n = 4");

    /* 4. Vuelta del buffer: 13 escrituras en 8 posiciones -> quedan n = 5..12 */
    registro_iniciar(&reg, 1);
    for (uint16_t k = 0; k < 13; k++) {
        registro_guardar(&reg, 0.0f, 0.0f, 0, k);
    }
    int orden_ok = 1;
    for (uint32_t i = 0; i < registro_cantidad(&reg); i++) {
        if (registro_leer(&reg, i).n != (uint16_t)(5 + i)) {
            orden_ok = 0;
        }
    }
    comprobar(registro_cantidad(&reg) == 8, "lleno: cantidad = N_BUF");
    comprobar(orden_ok, "tras dar la vuelta, se leen las 8 más recientes en orden (5..12)");

    /* 5. Submuestreo */
    registro_iniciar(&reg, 3);
    for (uint16_t k = 1; k <= 9; k++) {
        registro_guardar(&reg, 0.0f, 0.0f, 0, k);
    }
    comprobar(registro_cantidad(&reg) == 3, "k_reg = 3: 9 llamadas guardan 3 muestras");
    comprobar(registro_leer(&reg, 0).n == 3 && registro_leer(&reg, 2).n == 9,
              "se guardan las llamadas 3, 6 y 9");

    /* 6. Congelado */
    registro_iniciar(&reg, 1);
    registro_guardar(&reg, 0.0f, 0.0f, 0, 1);
    registro_congelar(&reg);
    registro_guardar(&reg, 0.0f, 0.0f, 0, 2);
    comprobar(registro_cantidad(&reg) == 1, "congelado: no se escribe");
    registro_descongelar(&reg);
    registro_guardar(&reg, 0.0f, 0.0f, 0, 3);
    comprobar(registro_cantidad(&reg) == 2 && registro_leer(&reg, 1).n == 3,
              "descongelado: vuelve a escribir");

    /* 7. k_reg = 0 se trata como 1 */
    registro_iniciar(&reg, 0);
    registro_guardar(&reg, 0.0f, 0.0f, 0, 1);
    comprobar(registro_cantidad(&reg) == 1, "k_reg = 0 se trata como 1");

    printf("\n%s: %d falla(s)\n", fallas == 0 ? "RESULTADO OK" : "RESULTADO CON FALLAS", fallas);
    return fallas == 0 ? 0 : 1;
}
