/* Parámetros de configuración (PRUEBA = provisional) */
#ifndef PARAMETROS_H
#define PARAMETROS_H

/* Frecuencia y período de control (simulación de Aguilar; falta cerrar) */
#define F_SW_HZ             10000u       /* conmutación */
#define FREQ_SEL            0u           /* 00/01/10 = 10/20/25 kHz */
#define N_PWM_POR_CONTROL   1u           /* períodos PWM por período de control */
#define TS_S                100e-6f      /* período de control */
#define TS_NS               100000u
#define CICLOS_POR_TS       10000u       /* carga del Timer, 100 MHz */
#define F_REF_HZ            50.0f

/* PWM (tiempo muerto inicial de Aguilar para el IR2110) */
#define DEADTIME_CICLOS     100u         /* 1 us */
#define TRIGGER_PHASE       0u           /* PRUEBA: Aguilar y Campos */
#define N_ARRANQUE          5u           /* períodos con m = 0: carga del bootstrap */

/* Controlador PR (Kp = 12, Kr = 200, wc = 2*pi*2; Tustin con pre-warping, Ts = 100 us) */
#define PR_KP               12.0f
#define PR_B0               2.509707454e-01f
#define PR_B1               0.0f
#define PR_B2               (-2.509707454e-01f)
#define PR_A1               (-1.996504651667f)
#define PR_A2               0.997490292546f

/* Conversión a modulación (si cambia el bus, cambiar VDC_V y no las ganancias) */
#define VDC_V               12.0f
#define MOD_LIMIT_Q15       27853        /* m = 0,85; mismo límite que el PWM */

/* Medición (divisor 4,7k/1k del ACS712, nominal; falta calibrar) */
#define OFFSET_ADC          1796.5f      /* código para 0 A */
#define GANANCIA_ADC        0.0075222f   /* A por código */
#define CODIGO_MIN          16u          /* PRUEBA: Campos */
#define CODIGO_MAX          4079u        /* PRUEBA: Campos */
#define I_MAX_A             1.5f         /* PRUEBA: PEDP */

/* Software */
#define K_REG               1u           /* 1024 · 100 us = 102,4 ms */
#define N_FALLA_MUESTRAS    3u
#define MARGEN_ISR_CICLOS   1000u        /* 10 us */
#define T_REBOTE_ITER       200u         /* 20 ms */
#define LATIDO_ITER         5000u        /* 0,5 s */

/* Amplitudes del enunciado */
#define AMPLITUD_0          0.2f
#define AMPLITUD_1          0.5f
#define AMPLITUD_2          1.0f

/* Bits de entradas y LED (PRUEBA: Puentes) */
#define BTN_HABILITAR       (1u << 0)
#define BTN_RECONOCER       (1u << 1)
#define BTN_EXPORTAR        (1u << 2)
#define SW_AMPLITUD_POS     4u           /* 00 = 0,2 A; 01 = 0,5 A; 1x = 1,0 A */
#define LED_OPERACION       (1u << 0)
#define LED_FALLA           (1u << 1)
#define LED_EXPORTANDO      (1u << 2)
#define LED_LATIDO          (1u << 3)

#endif
