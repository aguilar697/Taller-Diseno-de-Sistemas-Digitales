/* Aplicación de control: estados, ISR y lazo principal */
#include "aplicacion.h"

#include "drivers.h"
#include "parametros.h"

/* ================================================================ */
/* Inicialización                                                   */
/* ================================================================ */

void app_iniciar(aplicacion_t *app)
{
    pr_coef_t coef = { PR_KP, PR_B0, PR_B1, PR_B2, PR_A1, PR_A2 };
    uint16_t codigo, n;
    uint32_t estado_adc;
    int correcto = 1;

    /* CONTROL = 0 primero */
    pwm_apagar();
    gpio_escribir_led(0);
    gpio_medicion(0);

    /* Variables en cero */
    app->estado = ESTADO_INICIO;
    app->solicitud = SOLICITUD_NINGUNA;
    app->iteraciones = 0;
    app->t_isr_max = 0;
    app->q_ultimo = 0;
    app->arranque = 0;

    pr_iniciar(&app->pr, &coef);
    referencia_iniciar(&app->referencia, F_REF_HZ, TS_S);
    referencia_pedir_amplitud(&app->referencia, AMPLITUD_0);
    registro_iniciar(&app->registro, K_REG);
    supervision_iniciar(&app->supervision, I_MAX_A, CODIGO_MIN, CODIGO_MAX,
                        CICLOS_POR_TS - MARGEN_ISR_CICLOS);
    antirrebote_iniciar(&app->entradas, gpio_leer_entradas(), T_REBOTE_ITER, 0);
    exportacion_iniciar(&app->exportacion, &app->registro, uart_tx_llena, uart_escribir);
    if (!modulacion_iniciar(&app->modulacion, VDC_V, MOD_LIMIT_Q15)) {
        correcto = 0;
    }

    /* ADC (fuera de OPERACIÓN: conversión por software, Δn = 1) */
    if (!adc_configurar()) {
        correcto = 0;
    }
    adc_leer(&codigo, &n, &estado_adc);
    lectura_iniciar(&app->lectura, OFFSET_ADC, GANANCIA_ADC, 1u, N_FALLA_MUESTRAS, n);
    adc_iniciar_conversion();

    /* PWM con lectura de comprobación */
    if (!pwm_configurar(FREQ_SEL, DEADTIME_CICLOS, TRIGGER_PHASE)) {
        correcto = 0;
    }
    pwm_escribir_referencia(0);

    /* Timer */
    timer_configurar(CICLOS_POR_TS);

    /* ¿Configuración correcta? */
    if (correcto) {
        app->estado = ESTADO_DETENIDO;
    } else {
        supervision_marcar(&app->supervision, FALLA_CONFIGURACION);
        app->estado = ESTADO_FALLA;
    }
}

/* ================================================================ */
/* Rutina periódica (ISR)                                           */
/* ================================================================ */

/* Ir a FALLA: CONTROL = 0 */
static void ir_a_falla(aplicacion_t *app)
{
    pwm_apagar();
    pr_reiniciar(&app->pr);
    app->lectura.n_por_control = 1u;
    app->estado = ESTADO_FALLA;
}

/* Aplicar solicitudes del lazo principal */
static void aplicar_solicitud(aplicacion_t *app)
{
    solicitud_t s = app->solicitud;
    app->solicitud = SOLICITUD_NINGUNA;

    /* Habilitar: DETENIDO -> OPERACIÓN */
    if (s == SOLICITUD_HABILITAR && app->estado == ESTADO_DETENIDO) {
        pr_reiniciar(&app->pr);
        app->q_ultimo = 0;
        app->arranque = N_ARRANQUE;
        pwm_escribir_referencia(0);
        if (pwm_habilitar(FREQ_SEL)) {
            app->lectura.n_por_control = N_PWM_POR_CONTROL;
            app->estado = ESTADO_OPERACION;
        } else {
            supervision_marcar(&app->supervision, FALLA_CONFIGURACION);
            ir_a_falla(app);
        }

    /* Apagar: OPERACIÓN -> DETENIDO */
    } else if (s == SOLICITUD_APAGAR && app->estado == ESTADO_OPERACION) {
        pwm_apagar();
        pr_reiniciar(&app->pr);
        app->lectura.n_por_control = 1u;
        app->estado = ESTADO_DETENIDO;
    }
}

void app_isr(aplicacion_t *app)
{
    uint32_t t0, duracion, estado_adc;
    uint16_t codigo, n;
    lectura_clase_t clase;
    float i_med, i_ref = 0.0f;
    int16_t q = 0;

    /* Salida de medición = 1 */
    gpio_medicion(1);
    t0 = timer_contador();

    /* Aplicar solicitudes del lazo principal */
    aplicar_solicitud(app);

    /* Leer ADC: código, n y estado */
    adc_leer(&codigo, &n, &estado_adc);

    /* Convertir a A y supervisar (sin muestra válida solo cuenta Δn) */
    clase = lectura_clasificar(&app->lectura, n);
    if (estado_adc & ADC_ESTADO_VALIDO) {
        i_med = lectura_a_amperios(&app->lectura, codigo);
        supervision_muestra(&app->supervision, i_med, codigo, lectura_falla(&app->lectura));
    } else {
        i_med = 0.0f;
        if (lectura_falla(&app->lectura)) {
            supervision_marcar(&app->supervision, FALLA_MUESTRAS);
        }
    }

    /* ¿Condición de falla? */
    if (supervision_hay_falla(&app->supervision) && app->estado != ESTADO_FALLA) {
        ir_a_falla(app);
    }

    /* ¿Estado = OPERACIÓN? */
    if (app->estado == ESTADO_OPERACION && app->arranque > 0u) {
        /* Arranque: m = 0 para cargar el bootstrap */
        app->arranque--;
        pwm_escribir_referencia(0);
        app->q_ultimo = 0;
        if (app->arranque == 0u) {
            referencia_arrancar(&app->referencia);
        }

    } else if (app->estado == ESTADO_OPERACION) {
        /* Referencia: θ += Δθ en cada iteración */
        i_ref = referencia_paso(&app->referencia);

        /* ¿Muestra nueva? */
        if (clase == LECTURA_REPETIDA) {
            /* No ejecutar el PR: mantener REFERENCE */
            q = app->q_ultimo;
        } else {
            int saturado;

            /* PR: r* y v_PR */
            float v_pr = pr_calcular(&app->pr, i_ref - i_med);

            /* m = sat(v_PR / Vdc) en Q1.15 */
            q = modulacion_calcular(&app->modulacion, v_pr, &saturado);

            /* Escribir REFERENCE */
            pwm_escribir_referencia(q);
            app->q_ultimo = q;

            /* Actualizar estados del PR */
            pr_actualizar(&app->pr, saturado);
        }

    } else {
        /* Estados del PR en cero */
        pr_reiniciar(&app->pr);
    }

    /* Registrar (fuera de OPERACIÓN: i_ref = m = 0) */
    registro_guardar(&app->registro, i_med, i_ref, q, n);
    if (app->estado != ESTADO_OPERACION) {
        adc_iniciar_conversion();
    }

    /* Medir duración y supervisar */
    duracion = timer_contador() - t0;
    if (duracion > app->t_isr_max) {
        app->t_isr_max = duracion;
    }
    if (supervision_tiempo(&app->supervision, duracion) && app->estado != ESTADO_FALLA) {
        ir_a_falla(app);
    }

    app->iteraciones++;

    /* Reconocer la interrupción */
    timer_reconocer();

    /* Salida de medición = 0 */
    gpio_medicion(0);
}

/* ================================================================ */
/* Lazo principal                                                   */
/* ================================================================ */

/* Amplitud según los interruptores */
static float amplitud_de(uint32_t entradas)
{
    uint32_t sel = (entradas >> SW_AMPLITUD_POS) & 0x3u;
    if (sel == 0u) {
        return AMPLITUD_0;
    }
    return (sel == 1u) ? AMPLITUD_1 : AMPLITUD_2;
}

/* Amperios a mA sin signo */
static uint16_t a_miliamperios(float a)
{
    return (uint16_t)(a * 1000.0f + 0.5f);
}

void app_lazo_paso(aplicacion_t *app)
{
    uint32_t ahora = app->iteraciones;
    uint32_t estables, flancos, leds;
    estado_t estado = app->estado;

    /* Leer botones e interruptores */
    estables = antirrebote_actualizar(&app->entradas, gpio_leer_entradas(), ahora);
    flancos = antirrebote_flancos(&app->entradas);

    /* Evento: habilitar o apagar */
    if (flancos & BTN_HABILITAR) {
        if (estado == ESTADO_DETENIDO) {
            app->solicitud = SOLICITUD_HABILITAR;
        } else if (estado == ESTADO_OPERACION) {
            app->solicitud = SOLICITUD_APAGAR;
        }
    }

    /* Evento: reconocer falla (FALLA -> DETENIDO) */
    if ((flancos & BTN_RECONOCER) && estado == ESTADO_FALLA) {
        supervision_reconocer(&app->supervision);
        app->estado = ESTADO_DETENIDO;
    }

    /* Evento: amplitud pendiente */
    referencia_pedir_amplitud(&app->referencia, amplitud_de(estables));

    /* Evento: exportar */
    if ((flancos & BTN_EXPORTAR) && !exportacion_en_curso(&app->exportacion)) {
        trama_info_t info;
        info.estado = (uint8_t)app->estado;
        info.f_sw = F_SW_HZ;
        info.ts_ns = TS_NS;
        info.k_reg = (uint16_t)K_REG;
        info.n = 0;
        info.amplitud_ma = a_miliamperios(app->referencia.amplitud);
        info.causa = app->supervision.causa;
        info.t_isr_max = app->t_isr_max;
        info.perdidas = app->lectura.perdidas;
        exportacion_solicitar(&app->exportacion, &info);
    }

    /* Actualizar LED */
    leds = 0;
    if (app->estado == ESTADO_OPERACION) {
        leds |= LED_OPERACION;
    }
    if (app->estado == ESTADO_FALLA) {
        leds |= LED_FALLA;
    }
    if (exportacion_en_curso(&app->exportacion)) {
        leds |= LED_EXPORTANDO;
    }
    if ((ahora / LATIDO_ITER) & 1u) {
        leds |= LED_LATIDO;
    }
    gpio_escribir_led(leds);

    /* Un paso de la exportación */
    exportacion_paso(&app->exportacion);
}
