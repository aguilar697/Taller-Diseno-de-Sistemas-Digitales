/* Registros del PWM (docs/diseno/nivel_3_pwm.md y nivel_4_pwm.md) */
#ifndef PWM_REGS_H
#define PWM_REGS_H

#include <stdint.h>

/* Offsets */
#define PWM_CONTROL_OFFSET        UINT32_C(0x00)
#define PWM_REFERENCE_OFFSET      UINT32_C(0x04)
#define PWM_DEADTIME_OFFSET       UINT32_C(0x08)
#define PWM_TRIGGER_PHASE_OFFSET  UINT32_C(0x0C)

/* CONTROL */
#define PWM_CONTROL_ENABLE        UINT32_C(0x01)
#define PWM_CONTROL_FREQ_SHIFT    1u
#define PWM_CONTROL_FREQ_MASK     UINT32_C(0x06)
#define PWM_CONTROL_RUNNING       UINT32_C(0x08)    /* solo lectura */

/* freq_sel: 00/01/10 = 10/20/25 kHz; 11 inválido */
#define PWM_FREQ_INVALIDA         3u

/* REFERENCE: Q1.15 en bits 15:0 */
#define PWM_REFERENCE_MASK        UINT32_C(0xFFFF)

#endif
