/* Puesta en marcha del control de corriente con bus de 3 V.
 * El cero se obtiene al arrancar, con el bus apagado. Antes del PR se verifica
 * el signo del sensor mediante una excitacion sinusoidal de baja amplitud.
 * La sensibilidad es nominal: este ensayo no sustituye la calibracion en A.
 */
#include <stdint.h>
#include "drivers.h"
#include "plataforma.h"
#include "parametros.h"
#include "control_pr.h"
#include "referencia.h"
#include "lectura.h"
#include "modulacion.h"
#include "registro.h"
#include "tabla_seno.h"

#define LAB_VDC 3.0f
#define LAB_I_REF 0.10f
#define LAB_I_MAX 0.30f
#define LAB_MOD_MAX 14746 /* 0.45 en Q1.15 */
#define LAB_GANANCIA (1.0f / (0.185f * (4.924f / 5.0f) * (1000.0f / 5700.0f) * 4096.0f))
#define LAB_CERO_N 2048u
#define LAB_SONDEO_N 10000u
#define LAB_CONTROL_N 50000u
#define LAB_ADC_ERROR 0x70u

enum { LAB_CERO, LAB_LISTO, LAB_SIGNO, LAB_PR, LAB_FIN, LAB_FALLA };
enum { ERROR_CONFIG=1, ERROR_ADC, ERROR_CERO, ERROR_CORRIENTE,
       ERROR_SIGNO, ERROR_PLAZO, ERROR_PARADA };

volatile uint32_t lab_estado, lab_error, lab_irq, lab_isr_max, lab_status;
volatile uint32_t lab_codigo, lab_peticion, lab_ticks, lab_evento;
volatile float lab_cero, lab_corriente, lab_referencia;
volatile int16_t lab_q;
volatile float lab_signo_seno, lab_signo_coseno;
volatile uint32_t lab_falla_codigo, lab_falla_ticks, lab_falla_status, lab_falla_etapa;
volatile float lab_falla_corriente;
volatile int16_t lab_falla_q;
static lectura_t lectura;
static pr_t pr;
static referencia_t referencia;
static modulacion_t modulacion;
static registro_t registro;
static uint32_t suma_cero, muestras_cero, espera_cero, sondeo_fase;
static uint16_t minimo_cero, maximo_cero;
static float correlacion_seno, correlacion_coseno;

static float absoluto(float x) { return x < 0.0f ? -x : x; }

static void detener(uint32_t error)
{
    /* Conservar la primera causa y su muestra; las conversiones posteriores
     * en reposo no deben reemplazar la evidencia de la parada. */
    if (lab_estado == LAB_FALLA || lab_estado == LAB_FIN) return;
    if (error) {
        lab_falla_codigo = lab_codigo;
        lab_falla_ticks = lab_ticks;
        lab_falla_status = lab_status;
        lab_falla_etapa = lab_estado;
        lab_falla_corriente = lab_corriente;
        lab_falla_q = lab_q;
    }
    pwm_apagar();
    lab_q = 0;
    lab_error = error;
    lab_estado = error ? LAB_FALLA : LAB_FIN;
    registro_congelar(&registro);
    lab_evento = 1;
}

static void iniciar_control(void)
{
    /* Los coeficientes discretos coinciden con el controlador del proyecto. */
    pr_coef_t coef = {PR_KP, PR_B0, PR_B1, PR_B2, PR_A1, PR_A2};
    pr_iniciar(&pr, &coef);
    referencia_iniciar(&referencia, F_REF_HZ, TS_S);
    referencia_pedir_amplitud(&referencia, LAB_I_REF);
    referencia_arrancar(&referencia);
    modulacion_iniciar(&modulacion, LAB_VDC, LAB_MOD_MAX);
    registro_iniciar(&registro, K_REG);
    lab_ticks = 0;
    lab_estado = LAB_PR;
    lab_evento = 1;
    pwm_escribir_referencia(0);
}

static void adquirir_cero(uint16_t codigo, lectura_clase_t clase)
{
    if (clase != LECTURA_NUEVA) return;
    if (++espera_cero <= 1000u) return;
    if (codigo < 1000u || codigo > 3000u) { detener(ERROR_CERO); return; }
    if (codigo < minimo_cero) minimo_cero = codigo;
    if (codigo > maximo_cero) maximo_cero = codigo;
    suma_cero += codigo;
    if (++muestras_cero == LAB_CERO_N) {
        if ((uint32_t)(maximo_cero - minimo_cero) > 80u) { detener(ERROR_CERO); return; }
        lab_cero = (float)suma_cero / (float)LAB_CERO_N;
        lectura.offset = lab_cero;
        lab_corriente = ((float)codigo - lab_cero) * lectura.ganancia;
        lab_estado = LAB_LISTO;
        lab_evento = 1;
    }
}

static void verificar_signo(uint16_t codigo)
{
    uint32_t t = lab_ticks++;
    if (t < N_ARRANQUE) { pwm_escribir_referencia(0); return; }
    if (t < LAB_SONDEO_N + N_ARRANQUE) {
        uint32_t indice = sondeo_fase * TABLA_SENO_N / 200u;
        float seno = (float)TABLA_SENO[indice] / 32768.0f;
        float coseno = (float)TABLA_SENO[(indice + 64u) & 255u] / 32768.0f;
        /* Se descartan 100 ms. La correlacion usa ciclos completos, por lo que
         * un pequeno desplazamiento del cero no determina el signo obtenido. */
        if (t >= N_ARRANQUE + 1000u) {
            float d = (float)codigo - lab_cero;
            correlacion_seno += d * seno;
            correlacion_coseno += d * coseno;
        }
        lab_q = (int16_t)(seno * 6554.0f); /* m = 0.20 */
        pwm_escribir_referencia(lab_q);
        if (++sondeo_fase == 200u) sondeo_fase = 0;
    } else {
        lab_signo_seno = correlacion_seno * (2.0f / 9000.0f);
        lab_signo_coseno = correlacion_coseno * (2.0f / 9000.0f);
        /* Exigir respuesta medible y fase compatible con una carga RL.
         * Si el bus o los drivers siguen bloqueados, no se habilita el PR. */
        if (absoluto(lab_signo_seno) < 3.0f ||
            absoluto(lab_signo_coseno) > 2.0f * absoluto(lab_signo_seno)) {
            detener(ERROR_SIGNO);
            return;
        }
        lectura.ganancia = lab_signo_seno > 0.0f ? LAB_GANANCIA : -LAB_GANANCIA;
        iniciar_control();
    }
}

static void atender_timer(void)
{
    uint16_t codigo, id;
    uint32_t estado, inicio = timer_contador();
    lectura_clase_t clase;
    gpio_medicion(1);
    /* adc_leer captura SAMPLE y escribe ACK_ID antes de habilitar el PWM. */
    adc_leer(&codigo, &id, &estado);
    lab_codigo = codigo; lab_status = estado;
    clase = lectura_clasificar(&lectura, id);
    if ((estado & LAB_ADC_ERROR) || lectura_falla(&lectura)) detener(ERROR_ADC);
    lab_corriente = lectura_a_amperios(&lectura, codigo);

    /* El boton de parada se atiende en la ISR sin esperar antirrebote. */
    if ((gpio_leer_entradas() & BTN_RECONOCER) &&
        (lab_estado == LAB_SIGNO || lab_estado == LAB_PR)) detener(ERROR_PARADA);

    if (lab_estado == LAB_CERO && (estado & ADC_ESTADO_VALIDO)) adquirir_cero(codigo, clase);
    if (lab_estado == LAB_LISTO && lab_peticion) {
        lab_peticion = 0;
        correlacion_seno = correlacion_coseno = 0.0f;
        sondeo_fase = 0; lab_ticks = 0;
        pwm_escribir_referencia(0);
        if (pwm_habilitar(FREQ_SEL)) { lab_estado = LAB_SIGNO; lab_evento = 1; }
        else detener(ERROR_CONFIG);
    }

    if (lab_estado == LAB_SIGNO || lab_estado == LAB_PR) {
        if (!(estado & ADC_ESTADO_VALIDO) || codigo <= 16u || codigo >= 4079u)
            detener(ERROR_ADC);
        else if (absoluto(lab_corriente) > LAB_I_MAX) detener(ERROR_CORRIENTE);
    }
    if (lab_estado == LAB_SIGNO) {
        registro_guardar(&registro, lab_corriente, 0.0f, lab_q, id);
        verificar_signo(codigo);
    } else if (lab_estado == LAB_PR) {
        uint32_t t = lab_ticks++;
        if (t >= LAB_CONTROL_N + N_ARRANQUE) {
            detener(0);
        } else if (t < N_ARRANQUE) {
            pwm_escribir_referencia(0);
        } else {
            int saturado;
            /* Subida de amplitud durante 200 ms; el PR usa la ultima muestra
             * completa. La escritura se aplica en el siguiente periodo PWM. */
            float rampa = (float)(t - N_ARRANQUE) / 2000.0f;
            if (rampa > 1.0f) rampa = 1.0f;
            lab_referencia = referencia_paso(&referencia) * rampa;
            if (clase == LECTURA_NUEVA) {
                float v = pr_calcular(&pr, lab_referencia - lab_corriente);
                lab_q = modulacion_calcular(&modulacion, v, &saturado);
                pr_actualizar(&pr, saturado);
                pwm_escribir_referencia(lab_q);
            }
            registro_guardar(&registro, lab_corriente, lab_referencia, lab_q, id);
        }
    }
    if (lab_estado != LAB_SIGNO && lab_estado != LAB_PR) adc_iniciar_conversion();
    ++lab_irq;
    uint32_t duracion = timer_contador() - inicio;
    if (duracion > lab_isr_max) lab_isr_max = duracion;
    if (duracion > 9000u) detener(ERROR_PLAZO);
    timer_reconocer();
    gpio_medicion(0);
}

static void texto(const char *s)
{
    while (*s) { while (uart_tx_llena()) { } uart_escribir((uint8_t)*s++); }
}
static void numero(int32_t n)
{
    char d[12]; unsigned k = 0;
    uint32_t u = n < 0 ? (uint32_t)(-(int64_t)n) : (uint32_t)n;
    if (n < 0) texto("-");
    do { d[k++] = (char)('0' + u % 10u); u /= 10u; } while (u);
    while (k) { char c[2] = {d[--k], 0}; texto(c); }
}
static void informe(void)
{
    /* Copiar antes de transmitir: la UART tarda mas que un periodo de control. */
    uint32_t codigo = lab_codigo, estado_adc = lab_status;
    float corriente = lab_corriente, consigna = lab_referencia;
    int16_t q = lab_q;
    texto("ESTADO="); numero((int32_t)lab_estado);
    texto(" ERROR="); numero((int32_t)lab_error);
    texto(" CERO_x100="); numero((int32_t)(lab_cero * 100.0f));
    texto(" ADC="); numero((int32_t)codigo);
    texto(" STATUS="); numero((int32_t)estado_adc);
    texto(" I_mA="); numero((int32_t)(corriente * 1000.0f));
    texto(" REF_mA="); numero((int32_t)(consigna * 1000.0f));
    texto(" Q="); numero(q);
    texto(" SIGNO="); numero(lectura.ganancia < 0.0f ? -1 : 1);
    texto(" CORR_S_x100="); numero((int32_t)(lab_signo_seno * 100.0f));
    texto(" CORR_C_x100="); numero((int32_t)(lab_signo_coseno * 100.0f));
    texto(" ISR_MAX="); numero((int32_t)lab_isr_max); texto("\r\n");
    if (lab_estado == LAB_FALLA) {
        texto("PARADA: ADC="); numero((int32_t)lab_falla_codigo);
        texto(" I_mA="); numero((int32_t)(lab_falla_corriente * 1000.0f));
        texto(" Q="); numero(lab_falla_q);
        texto(" TICKS="); numero((int32_t)lab_falla_ticks);
        texto(" ETAPA="); numero((int32_t)lab_falla_etapa);
        texto(" STATUS="); numero((int32_t)lab_falla_status); texto("\r\n");
    }
}
static void exportar(void)
{
    /* Solo con el PWM detenido: la UART no bloquea la ISR de control. */
    texto("MUESTRAS_BEGIN\r\nindice,i_mA,ref_mA,q15,id\r\n");
    for (uint32_t i = 0; i < registro_cantidad(&registro); ++i) {
        muestra_t m = registro_leer(&registro, i);
        numero((int32_t)i); texto(","); numero(m.i_med_ma); texto(",");
        numero(m.i_ref_ma); texto(","); numero(m.m_q15); texto(",");
        numero(m.n); texto("\r\n");
    }
    texto("MUESTRAS_END\r\n");
}
int main(void)
{
    uint16_t codigo, id; uint32_t status;
    uint32_t anterior = 0, ultimo = 0;
    gpio_iniciar(); uart_iniciar(); pwm_apagar();
    registro_iniciar(&registro, K_REG);
    minimo_cero = 4095u;
    texto("LAB PR: bus 3 V, limite fuente 100 mA, referencia 100 mA pico.\r\n");
    texto("Cero inicial: bus apagado y SD altos. No conectar bus hasta ESTADO=1.\r\n");
    texto("Estados: 0=cero 1=listo 2=signo 3=PR 4=fin 5=falla.\r\n");
    texto("BTN U inicia una vez; BTN D detiene; BTN L exporta al terminar.\r\n");
    if (!adc_configurar() || !pwm_configurar(FREQ_SEL, DEADTIME_CICLOS, TRIGGER_PHASE)) {
        detener(ERROR_CONFIG);
    }
    adc_leer(&codigo, &id, &status);
    lectura_iniciar(&lectura, 1900.0f, LAB_GANANCIA, 1u, 3u, id);
    adc_iniciar_conversion();
    timer_configurar(CICLOS_POR_TS);
    plataforma_iniciar_interrupciones(atender_timer);
    timer_arrancar();
    for (;;) {
        uint32_t ahora = lab_irq, botones = gpio_leer_entradas();
        uint32_t flancos = botones & ~anterior;
        anterior = botones;
        if ((flancos & BTN_HABILITAR) && lab_estado == LAB_LISTO) lab_peticion = 1;
        if ((flancos & BTN_EXPORTAR) && (lab_estado == LAB_FIN || lab_estado == LAB_FALLA)) exportar();
        gpio_escribir_led((lab_estado == LAB_SIGNO || lab_estado == LAB_PR ? LED_OPERACION : 0u) |
                          (lab_estado == LAB_FALLA ? LED_FALLA : 0u) |
                          (lab_estado == LAB_LISTO ? 4u : 0u) |
                          ((ahora / 5000u) & 1u ? LED_LATIDO : 0u));
        if (lab_evento || ahora - ultimo >= 5000u) {
            lab_evento = 0; ultimo = ahora; informe();
        }
    }
}
