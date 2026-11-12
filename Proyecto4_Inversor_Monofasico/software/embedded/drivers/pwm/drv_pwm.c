/* Driver del PWM (registros de pwm_regs.h) */
#include "drivers.h"
#include "mmio.h"
#include "pwm_regs.h"

/* Dirección base (en la PC la define la prueba) */
#ifndef PWM_BASE
#include "direcciones.h"
#endif

/* Lecturas de running tras habilitar (sin espera indefinida) */
#define PWM_INTENTOS_RUNNING  8u

/* Lectura y escritura de un registro */
static uint32_t leer(uint32_t offset)
{
    return mmio_leer32(PWM_BASE + offset);
}

static void escribir(uint32_t offset, uint32_t valor)
{
    mmio_escribir32(PWM_BASE + offset, valor);
}

/* Apagado: CONTROL = 0 (siempre aceptado) */
void pwm_apagar(void)
{
    escribir(PWM_CONTROL_OFFSET, 0u);
}

/* Configuración en reposo con lectura de comprobación */
int pwm_configurar(uint32_t freq_sel, uint32_t deadtime, uint32_t phase)
{
    uint32_t control_freq = (freq_sel << PWM_CONTROL_FREQ_SHIFT) & PWM_CONTROL_FREQ_MASK;

    if (freq_sel >= PWM_FREQ_INVALIDA) {
        return 0;
    }

    /* Apagar y comprobar running = 0 */
    pwm_apagar();
    if (leer(PWM_CONTROL_OFFSET) & PWM_CONTROL_RUNNING) {
        return 0;
    }

    /* Frecuencia, tiempo muerto, fase del disparo y referencia en cero */
    escribir(PWM_CONTROL_OFFSET, control_freq);
    escribir(PWM_DEADTIME_OFFSET, deadtime);
    escribir(PWM_TRIGGER_PHASE_OFFSET, phase);
    escribir(PWM_REFERENCE_OFFSET, 0u);

    /* Lectura de comprobación (no depende del SLVERR) */
    return (leer(PWM_CONTROL_OFFSET) & (PWM_CONTROL_FREQ_MASK | PWM_CONTROL_ENABLE)) == control_freq
        && leer(PWM_DEADTIME_OFFSET) == deadtime
        && leer(PWM_TRIGGER_PHASE_OFFSET) == phase
        && (leer(PWM_REFERENCE_OFFSET) & PWM_REFERENCE_MASK) == 0u;
}

/* Habilitación: 1 si running sube */
int pwm_habilitar(uint32_t freq_sel)
{
    uint32_t i;

    escribir(PWM_CONTROL_OFFSET,
             ((freq_sel << PWM_CONTROL_FREQ_SHIFT) & PWM_CONTROL_FREQ_MASK) | PWM_CONTROL_ENABLE);

    for (i = 0; i < PWM_INTENTOS_RUNNING; i++) {
        if (leer(PWM_CONTROL_OFFSET) & PWM_CONTROL_RUNNING) {
            return 1;
        }
    }

    /* No arrancó: dejarlo apagado */
    pwm_apagar();
    return 0;
}

/* Referencia de modulación Q1.15 (una escritura de 32 bits) */
void pwm_escribir_referencia(int16_t q)
{
    escribir(PWM_REFERENCE_OFFSET, (uint32_t)(uint16_t)q);
}
