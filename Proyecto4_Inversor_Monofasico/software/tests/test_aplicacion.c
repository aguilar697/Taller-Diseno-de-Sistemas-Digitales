/*
 * Prueba de la aplicación completa en PC, en lazo cerrado con un modelo de
 * la carga RL. Simula los drivers: el PWM aplica la referencia en el período
 * siguiente (retardo de un período), el ADC muestrea en el valle y numera las
 * conversiones, y la UART se vacía a 115200 bit/s.
 *
 * Carga de Potencia/01 (Aguilar): dos resistencias de 3,3 ohm más 0,6 ohm del
 * devanado (7,2 ohm) y L = 9,3 mH, con inductancia lineal. El cambio de carga
 * agrega la tercera resistencia: 9,9 + 0,6 = 10,5 ohm.
 * Criterio del enunciado: error de amplitud de la fundamental <= 10 %.
 */
#include <math.h>
#include <stdio.h>
#include <string.h>

#include "aplicacion.h"
#include "drivers.h"
#include "parametros.h"

#define R_CARGA        7.2
#define R_CARGA_ALTA   10.5
#define L_CARGA        0.0093
#define PI        3.14159265358979

static int fallas = 0;

static void comprobar(int condicion, const char *descripcion)
{
    printf("[%s] %s\n", condicion ? "PASA" : "FALLA", descripcion);
    if (!condicion) {
        fallas++;
    }
}

/* ---------------------------------------------------------------- */
/* Hardware simulado                                                 */
/* ---------------------------------------------------------------- */

static double   i_carga = 0.0;          /* corriente de la carga, A           */
static double   r_carga = R_CARGA;
static int      pwm_habilitado = 0;
static int16_t  q_escrito = 0;          /* REFERENCE escrita en este período  */
static int16_t  q_aplicado = 0;         /* REFERENCE vigente en este período  */
static uint32_t escrituras_ref = 0;
static int      sim_config_ok = 1;
static int      sim_running_ok = 1;

static uint16_t adc_codigo = 2048;
static uint16_t adc_n = 0;
static int      conversion_pendiente = 0;
static int      congelar_n = 0;         /* simula muestras repetidas          */
static int      adc_valido = 1;         /* STATUS.valid                       */

static uint32_t entradas = 0;
static uint32_t leds = 0;
static int      medicion = 0;

static uint32_t t_base = 0;
static uint32_t duracion_isr = 1500;    /* ciclos que tarda la ISR simulada   */
static int      lectura_timer = 0;

#define FIFO_TAM   16u
#define SALIDA_MAX 9000u
static uint32_t fifo = 0;
static double   vaciado = 0.0;
static uint8_t  salida[SALIDA_MAX];
static uint32_t n_salida = 0;

void pwm_apagar(void) { pwm_habilitado = 0; }
int  pwm_configurar(uint32_t f, uint32_t d, uint32_t p) { (void)f; (void)d; (void)p; return sim_config_ok; }
int  pwm_habilitar(uint32_t f) { (void)f; pwm_habilitado = sim_running_ok; return sim_running_ok; }
void pwm_escribir_referencia(int16_t q) { q_escrito = q; escrituras_ref++; }

int  adc_configurar(void) { return 1; }
void adc_leer(uint16_t *codigo, uint16_t *n, uint32_t *estado)
{
    *codigo = adc_valido ? adc_codigo : 0u;
    *n = adc_n;
    *estado = adc_valido ? ADC_ESTADO_VALIDO : 0u;
}
void adc_iniciar_conversion(void) { conversion_pendiente = 1; }

uint32_t gpio_leer_entradas(void) { return entradas; }
void     gpio_escribir_led(uint32_t m) { leds = m; }
void     gpio_medicion(int nivel) { medicion = nivel; }

int  uart_tx_llena(void) { return fifo >= FIFO_TAM; }
void uart_escribir(uint8_t b) { fifo++; if (n_salida < SALIDA_MAX) { salida[n_salida++] = b; } }

void     timer_configurar(uint32_t carga) { (void)carga; }
uint32_t timer_contador(void)
{
    lectura_timer = !lectura_timer;
    return lectura_timer ? t_base : t_base + duracion_isr;
}
void     timer_reconocer(void) { }

static uint16_t codigo_de(double i)
{
    double c = i / (double)GANANCIA_ADC + (double)OFFSET_ADC;
    if (c < 0.0) { c = 0.0; }
    if (c > 4095.0) { c = 4095.0; }
    return (uint16_t)(c + 0.5);
}

static aplicacion_t app;   /* global: contiene el registro de 8 KB */

/* Un período de control completo */
static void periodo(void)
{
    double ts = (double)TS_S;
    double a = exp(-r_carga * ts / L_CARGA);
    double b = (1.0 - a) / r_carga;
    double v = pwm_habilitado ? (double)VDC_V * q_aplicado / 32768.0 : 0.0;

    /* Muestra en el valle: por disparo del PWM o por software */
    if (!congelar_n && (pwm_habilitado || conversion_pendiente)) {
        adc_n++;
        adc_codigo = codigo_de(i_carga);
        conversion_pendiente = 0;
    }

    app_isr(&app);
    app_lazo_paso(&app);

    /* UART: 11 520 bytes/s */
    vaciado += 11520.0 * ts;
    while (vaciado >= 1.0 && fifo > 0) { fifo--; vaciado -= 1.0; }
    if (fifo == 0 && vaciado > 1.0) { vaciado = 1.0; }

    /* Carga RL con la tensión del período (retenedor de orden cero) */
    i_carga = a * i_carga + b * v;
    if (!pwm_habilitado) {
        i_carga = 0.0;   /* puente apagado: la corriente se extingue (simplificado) */
    }
    q_aplicado = q_escrito;
    t_base += CICLOS_POR_TS;
}

static void correr(uint32_t n)
{
    while (n--) {
        periodo();
    }
}

static void presionar(uint32_t boton)
{
    entradas |= boton;
    correr(T_REBOTE_ITER + 100u);
    entradas &= ~boton;
    correr(T_REBOTE_ITER + 100u);
}

static void elegir_amplitud(uint32_t sel)
{
    entradas = (entradas & ~(0x3u << SW_AMPLITUD_POS)) | (sel << SW_AMPLITUD_POS);
}

/* Fundamental de 50 Hz de las últimas 1000 entradas del registro
 * (5 períodos a 10 kHz): error relativo de amplitud y desfase en grados */
static void medir(double *error, double *desfase)
{
    double re_m = 0, im_m = 0, re_r = 0, im_r = 0;
    uint32_t total = registro_cantidad(&app.registro);
    uint32_t i, inicio = total - 1000u;
    double muestras_por_periodo = 1.0 / (50.0 * (double)TS_S * K_REG);

    for (i = 0; i < 1000u; i++) {
        muestra_t m = registro_leer(&app.registro, inicio + i);
        double ang = 2.0 * PI * i / muestras_por_periodo;
        re_m += m.i_med_ma * cos(ang); im_m -= m.i_med_ma * sin(ang);
        re_r += m.i_ref_ma * cos(ang); im_r -= m.i_ref_ma * sin(ang);
    }
    *error = (sqrt(re_m * re_m + im_m * im_m) - sqrt(re_r * re_r + im_r * im_r))
             / sqrt(re_r * re_r + im_r * im_r);
    *desfase = (atan2(im_m, re_m) - atan2(im_r, re_r)) * 180.0 / PI;
    if (*desfase > 180.0) { *desfase -= 360.0; }
    if (*desfase < -180.0) { *desfase += 360.0; }
}

static void ensayo(const char *nombre, double *error_out)
{
    double error, desfase;
    char texto[160];

    correr(20000u);                       /* 1 s para llegar al régimen permanente */
    medir(&error, &desfase);
    snprintf(texto, sizeof(texto), "%s: error de amplitud %+.2f %%, desfase %+.2f grados (<= 10 %%)",
             nombre, 100.0 * error, desfase);
    comprobar(fabs(error) <= 0.10, texto);
    if (error_out) {
        *error_out = error;
    }
}

static uint16_t leer_16(const uint8_t *p) { return (uint16_t)(p[0] | (p[1] << 8)); }

int main(void)
{
    uint32_t k;
    int ok;

    /* ---------- Inicialización ---------- */
    app_iniciar(&app);
    comprobar(app.estado == ESTADO_DETENIDO && !pwm_habilitado, "iniciar: DETENIDO con el PWM apagado");

    /* ---------- DETENIDO: mide sin controlar ---------- */
    correr(2000u);
    comprobar(app.estado == ESTADO_DETENIDO && app.supervision.causa == 0,
              "DETENIDO: conversiones por software, sin fallas de muestras");
    {
        muestra_t m = registro_leer(&app.registro, registro_cantidad(&app.registro) - 1u);
        comprobar(m.i_ref_ma == 0 && m.m_q15 == 0, "DETENIDO: se registran i_ref = 0 y m = 0");
    }
    comprobar(app.t_isr_max == duracion_isr, "t_isr_max = duración medida de la ISR");

    /* ---------- Habilitar ---------- */
    elegir_amplitud(2u);
    entradas |= BTN_HABILITAR;
    for (k = 0; k < 2000u && app.estado != ESTADO_OPERACION; k++) {
        periodo();
    }
    comprobar(app.estado == ESTADO_OPERACION && pwm_habilitado, "botón habilitar: OPERACIÓN con el PWM en marcha");
    {
        /* Arranque: N_ARRANQUE períodos con m = 0 para cargar el bootstrap */
        int ceros = 1;
        for (k = 0; k < N_ARRANQUE; k++) {
            if (q_escrito != 0 || app.referencia.theta != 0u) {
                ceros = 0;
            }
            periodo();
        }
        comprobar(ceros, "arranque: los primeros N_ARRANQUE períodos con REFERENCE = 0 y sin referencia");
        correr(100u);
        comprobar(q_escrito != 0, "después del arranque, el PR aplica tensión");
    }
    entradas &= ~BTN_HABILITAR;
    elegir_amplitud(0u);
    correr(T_REBOTE_ITER + 100u);
    comprobar((leds & LED_OPERACION) != 0, "LED de operación encendido");

    /* ---------- Seguimiento de las tres amplitudes ---------- */
    ensayo("0,2 A", NULL);

    /* El cambio 0,2 -> 0,5 A ocurre solo cuando theta da la vuelta */
    elegir_amplitud(1u);
    ok = 1;
    for (k = 0; k < 2000u; k++) {
        uint32_t theta_ant = app.referencia.theta;
        float amp_ant = app.referencia.amplitud;
        periodo();
        if (app.referencia.amplitud != amp_ant && !(app.referencia.theta < theta_ant)) {
            ok = 0;
        }
    }
    comprobar(ok && app.referencia.amplitud == AMPLITUD_1, "cambio 0,2 -> 0,5 A en el cruce por cero");
    ensayo("0,5 A", NULL);

    elegir_amplitud(2u);
    ensayo("1,0 A", NULL);

    /* ---------- Cambio de carga: resistencia externa de 6,6 a 9,9 ohm ---------- */
    elegir_amplitud(1u);
    r_carga = R_CARGA_ALTA;
    ensayo("0,5 A con R externa de 6,6 a 9,9 ohm", NULL);
    r_carga = R_CARGA;
    correr(20000u);

    /* ---------- Muestra repetida: REFERENCE se mantiene, theta avanza ---------- */
    {
        uint32_t escrituras = escrituras_ref;
        uint32_t theta = app.referencia.theta;
        congelar_n = 1;
        periodo();
        congelar_n = 0;
        comprobar(escrituras_ref == escrituras, "muestra repetida: no se escribe REFERENCE");
        comprobar(app.referencia.theta == theta + app.referencia.delta_theta,
                  "muestra repetida: la fase de la referencia avanza igual");
        comprobar(app.estado == ESTADO_OPERACION, "una muestra repetida no es falla");
    }
    correr(10u);

    /* ---------- Tres repetidas seguidas: FALLA ---------- */
    congelar_n = 1;
    correr(3u);
    congelar_n = 0;
    comprobar(app.estado == ESTADO_FALLA && !pwm_habilitado &&
              (app.supervision.causa & FALLA_MUESTRAS), "3 muestras repetidas: FALLA con el PWM apagado");
    correr(100u);
    comprobar(app.estado == ESTADO_FALLA && (leds & LED_FALLA), "FALLA se mantiene hasta reconocer");
    presionar(BTN_HABILITAR);
    comprobar(app.estado == ESTADO_FALLA && !pwm_habilitado, "en FALLA, habilitar no hace nada");

    /* ---------- Reconocer ---------- */
    presionar(BTN_RECONOCER);
    comprobar(app.estado == ESTADO_DETENIDO && app.supervision.causa == 0, "reconocer: DETENIDO y causa borrada");
    correr(1000u);
    comprobar(app.estado == ESTADO_DETENIDO, "después de reconocer no vuelve a fallar");

    /* ---------- Sobrecorriente ---------- */
    elegir_amplitud(2u);
    presionar(BTN_HABILITAR);
    correr(5000u);
    i_carga = 1.8;
    periodo();
    comprobar(app.estado == ESTADO_FALLA && !pwm_habilitado &&
              (app.supervision.causa & FALLA_SOBRECORRIENTE), "1,8 A: FALLA en la misma iteración");
    presionar(BTN_RECONOCER);

    /* ---------- Exportación durante el control ---------- */
    elegir_amplitud(1u);
    presionar(BTN_HABILITAR);
    correr(20000u);
    n_salida = 0;
    entradas |= BTN_EXPORTAR;
    ok = 1;
    for (k = 0; k < 40000u; k++) {
        periodo();
        if (k == T_REBOTE_ITER + 100u) {
            entradas &= ~BTN_EXPORTAR;
        }
        if (app.estado != ESTADO_OPERACION) {
            ok = 0;
        }
        if (k > T_REBOTE_ITER + 100u && !exportacion_en_curso(&app.exportacion)) {
            break;
        }
    }
    comprobar(ok, "el control sigue en OPERACIÓN durante toda la exportación");
    comprobar(n_salida == 28u + 8u * REGISTRO_N_BUF + 2u, "trama completa: 8222 bytes");
    {
        uint16_t crc = TRAMA_CRC_INICIAL;
        uint32_t i;
        int continuo = 1;
        for (i = 2; i < n_salida - 2u; i++) {
            crc = trama_crc(crc, salida[i]);
        }
        comprobar(salida[0] == 0xA5u && salida[1] == 0x5Au && leer_16(&salida[n_salida - 2u]) == crc,
                  "sincronismo y CRC correctos");
        comprobar(salida[3] == ESTADO_OPERACION && leer_16(&salida[16]) == 500u,
                  "encabezado: estado OPERACIÓN y amplitud 500 mA");
        for (i = 1; i < REGISTRO_N_BUF; i++) {
            uint16_t n0 = leer_16(&salida[28u + 8u * (i - 1u) + 6u]);
            uint16_t n1 = leer_16(&salida[28u + 8u * i + 6u]);
            if ((uint16_t)(n1 - n0) != K_REG) {
                continuo = 0;
            }
        }
        comprobar(continuo, "números de muestra continuos: sin pérdidas en la ventana exportada");

        /* La trama queda en un archivo para probar la aplicación de PC con ella */
        {
            FILE *f = fopen("build/trama_aplicacion.bin", "wb");
            if (f) {
                fwrite(salida, 1, n_salida, f);
                fclose(f);
            }
        }
    }
    comprobar(!app.registro.congelado, "al terminar, el registro vuelve a guardar");

    /* ---------- Exceso de tiempo de la ISR ---------- */
    duracion_isr = CICLOS_POR_TS - MARGEN_ISR_CICLOS + 1u;
    periodo();
    comprobar(app.estado == ESTADO_FALLA && !pwm_habilitado &&
              (app.supervision.causa & FALLA_TIEMPO), "ISR más larga que Ts - MARGEN_ISR: FALLA");
    duracion_isr = 1500u;
    presionar(BTN_RECONOCER);

    /* ---------- running no sube al habilitar ---------- */
    sim_running_ok = 0;
    presionar(BTN_HABILITAR);
    comprobar(app.estado == ESTADO_FALLA && (app.supervision.causa & FALLA_CONFIGURACION),
              "running = 0 al habilitar: FALLA de configuración");
    sim_running_ok = 1;

    /* ---------- ADC sin muestra válida ---------- */
    presionar(BTN_RECONOCER);
    comprobar(app.estado == ESTADO_DETENIDO, "reconocer: vuelve a DETENIDO");
    adc_valido = 0;
    congelar_n = 1;
    periodo();
    comprobar(app.estado == ESTADO_DETENIDO, "sin muestra válida: no se marca falla de código");
    correr(3u);
    comprobar(app.estado == ESTADO_FALLA && (app.supervision.causa & FALLA_MUESTRAS) &&
              !(app.supervision.causa & FALLA_CODIGO), "ADC sin responder: falla de muestras");
    adc_valido = 1;
    congelar_n = 0;

    /* ---------- Lectura de comprobación incorrecta al iniciar ---------- */
    sim_config_ok = 0;
    app_iniciar(&app);
    comprobar(app.estado == ESTADO_FALLA && (app.supervision.causa & FALLA_CONFIGURACION),
              "lectura de comprobación incorrecta: INICIO -> FALLA");

    printf("\n%s: %d fallas\n", fallas ? "RESULTADO NEGATIVO" : "RESULTADO POSITIVO", fallas);
    return fallas ? 1 : 0;
}
