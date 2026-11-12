/*
 * Prueba del driver del PWM en PC, con un modelo de los registros
 * (docs/diseno/nivel_3_pwm.md y nivel_4_pwm.md). Se compila con -DPWM_BASE=0x44000000u.
 */
#include <stdio.h>

#include "drivers.h"
#include "mmio.h"
#include "pwm_regs.h"

static int fallas = 0;

static void comprobar(int condicion, const char *descripcion)
{
    printf("[%s] %s\n", condicion ? "PASA" : "FALLA", descripcion);
    if (!condicion) {
        fallas++;
    }
}

/* Modelo del PWM */
#define LIMITE 27853
static const uint32_t PERIODO[3] = { 10000u, 5000u, 4000u };
static uint32_t enable = 0, running = 0, freq = 0, deadtime = 0, fase = 0;
static int32_t  referencia = 0;
static int      deadtime_atascado = 0;   /* simula un registro que no se escribe */
static uint32_t rechazos = 0;            /* escrituras que darían SLVERR */

uint32_t mmio_leer32(uintptr_t direccion)
{
    switch (direccion - PWM_BASE) {
    case PWM_CONTROL_OFFSET:
        return enable | (freq << PWM_CONTROL_FREQ_SHIFT) | (running ? PWM_CONTROL_RUNNING : 0u);
    case PWM_REFERENCE_OFFSET:
        return (uint32_t)(uint16_t)(int16_t)referencia;
    case PWM_DEADTIME_OFFSET:
        return deadtime;
    case PWM_TRIGGER_PHASE_OFFSET:
        return fase;
    default:
        return 0;
    }
}

void mmio_escribir32(uintptr_t direccion, uint32_t valor)
{
    uint32_t f = (valor & PWM_CONTROL_FREQ_MASK) >> PWM_CONTROL_FREQ_SHIFT;

    switch (direccion - PWM_BASE) {
    case PWM_CONTROL_OFFSET:
        if (enable) {
            if (!(valor & PWM_CONTROL_ENABLE)) {          /* apagado prioritario */
                enable = 0;
                running = 0;
            } else if (f != freq) {
                rechazos++;
            }
        } else if (f == PWM_FREQ_INVALIDA) {
            rechazos++;
        } else if (valor & PWM_CONTROL_ENABLE) {
            if (deadtime >= 1u && fase < PERIODO[f]) {
                freq = f;
                enable = 1;
                running = 1;
            } else {
                rechazos++;                               /* parámetros incoherentes */
            }
        } else {
            freq = f;
        }
        break;
    case PWM_REFERENCE_OFFSET: {
        int32_t q = (int16_t)(valor & 0xFFFFu);
        referencia = (q > LIMITE) ? LIMITE : (q < -LIMITE) ? -LIMITE : q;
        break;
    }
    case PWM_DEADTIME_OFFSET:
        if (enable) {
            rechazos++;
        } else if (!deadtime_atascado) {
            deadtime = valor;
        }
        break;
    case PWM_TRIGGER_PHASE_OFFSET:
        if (enable) {
            rechazos++;
        } else {
            fase = valor;
        }
        break;
    default:
        break;
    }
}

int main(void)
{
    /* Configuración correcta */
    comprobar(pwm_configurar(0u, 100u, 5000u) == 1, "configurar 10 kHz, D = 100, fase = 5000: correcto");
    comprobar(freq == 0u && deadtime == 100u && fase == 5000u && referencia == 0 && !enable,
              "registros escritos y PWM apagado");

    /* Habilitar */
    comprobar(pwm_habilitar(0u) == 1 && running, "habilitar: running sube");

    /* Referencia con signo */
    pwm_escribir_referencia(-16384);
    comprobar(referencia == -16384, "REFERENCE = -16384 (m = -0,5)");
    pwm_escribir_referencia(16384);
    comprobar(referencia == 16384, "REFERENCE = +16384 (m = +0,5)");

    /* Reconfigurar en marcha: el driver apaga primero */
    rechazos = 0;
    comprobar(pwm_configurar(1u, 120u, 1000u) == 1 && rechazos == 0u,
              "configurar con el PWM en marcha: apaga primero, sin rechazos");
    comprobar(!running && freq == 1u, "queda apagado a 20 kHz");

    /* Apagado */
    pwm_habilitar(1u);
    pwm_apagar();
    comprobar(!enable && !running && freq == 1u, "apagar: CONTROL = 0, conserva la frecuencia");

    /* Frecuencia inválida */
    comprobar(pwm_configurar(PWM_FREQ_INVALIDA, 100u, 0u) == 0, "freq_sel = 11: rechazado");

    /* Registro que no se escribe: la comprobación lo detecta */
    deadtime_atascado = 1;
    comprobar(pwm_configurar(0u, 150u, 0u) == 0, "DEADTIME no coincide al leerlo: configuración incorrecta");
    deadtime_atascado = 0;

    /* D = 0: no arranca */
    comprobar(pwm_configurar(0u, 0u, 0u) == 1, "D = 0 se puede escribir en reposo");
    comprobar(pwm_habilitar(0u) == 0 && !running && !enable, "con D = 0 running no sube: habilitar falla y queda apagado");

    /* Fase fuera del período */
    comprobar(pwm_configurar(0u, 100u, 12000u) == 1, "fase 12000 se puede escribir en reposo");
    comprobar(pwm_habilitar(0u) == 0 && !running, "fase mayor que el período de 10 kHz: no arranca");

    printf("\n%s: %d fallas\n", fallas ? "RESULTADO NEGATIVO" : "RESULTADO POSITIVO", fallas);
    return fallas ? 1 : 0;
}
