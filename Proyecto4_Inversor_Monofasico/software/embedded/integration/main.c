/* Diagnostico conjunto: Timer, AXI, ADC y PWM.
 * La prueba de inversion usa modulacion fija, sin interpretar el ADC como
 * corriente ni ejecutar el PR. El arranque siempre queda detenido. */
#include <stdint.h>
#include "drivers.h"
#include "plataforma.h"
#include "parametros.h"
#include "tabla_seno.h"

/* A 10 kHz, 200 actualizaciones completan un ciclo de 50 Hz.
 * La modulacion se limita a 0.10 y la prueba dura como maximo cinco segundos. */
#define ENSAYO_AMPLITUD_Q15 3277
#define ENSAYO_ARRANQUE 5u
#define ENSAYO_DURACION 50000u

volatile uint32_t integracion_irq;
volatile uint32_t integracion_sample;
volatile uint32_t integracion_estado_adc;
volatile uint32_t integracion_isr_max;
volatile uint32_t integracion_pwm;
volatile uint32_t integracion_config_ok;
volatile uint32_t integracion_modo_seno;
volatile uint32_t integracion_ciclos_ensayo;
volatile uint32_t integracion_arranque_pendiente;
static uint32_t fase_ensayo;

static void actualizar_ensayo(void)
{
    uint32_t ciclo = integracion_ciclos_ensayo++;
    if (ciclo >= ENSAYO_DURACION) {
        pwm_apagar();
        integracion_pwm = 0;
        return;
    }
    if (ciclo < ENSAYO_ARRANQUE) {
        pwm_escribir_referencia(0);
        return;
    }
    uint32_t indice = fase_ensayo * TABLA_SENO_N / 200u;
    int16_t q = (int16_t)((int32_t)TABLA_SENO[indice] * ENSAYO_AMPLITUD_Q15 / 32768);
    pwm_escribir_referencia(q);
    if (++fase_ensayo == 200u) fase_ensayo = 0;
}

static void texto(const char *s)
{
    while (*s) {
        while (uart_tx_llena()) { }
        uart_escribir((uint8_t)*s++);
    }
}
static void numero(uint32_t n)
{
    char digits[10]; unsigned count = 0;
    do { digits[count++] = (char)('0' + n % 10u); n /= 10u; } while (n);
    while (count) { char c[2] = {digits[--count], 0}; texto(c); }
}
static void atender_timer(void)
{
    uint16_t codigo, id; uint32_t estado, inicio, duracion;
    gpio_medicion(1);
    inicio = timer_contador();
    adc_leer(&codigo, &id, &estado);
    integracion_sample = ((uint32_t)id << 16) | codigo;
    integracion_estado_adc = estado;
    /* Cambiar de disparo por software a PWM solo despues del ACK de la muestra
     * anterior. Asi no se publica una segunda conversion antes de consumirla,
     * y la fase entre el Timer y el inicio del PWM queda fija. */
    if (integracion_arranque_pendiente) {
        integracion_arranque_pendiente = 0;
        fase_ensayo = 0;
        integracion_ciclos_ensayo = 0;
        pwm_escribir_referencia(0);
        integracion_pwm = (uint32_t)pwm_habilitar(FREQ_SEL);
    }
    if (integracion_pwm && integracion_modo_seno) actualizar_ensayo();
    if (!integracion_pwm) adc_iniciar_conversion();
    ++integracion_irq;
    duracion = timer_contador() - inicio;
    if (duracion > integracion_isr_max) integracion_isr_max = duracion;
    timer_reconocer();
    gpio_medicion(0);
}
int main(void)
{
    uint32_t anterior = 0, ultimo_reporte = 0, ultimo_boton = 0;
    gpio_iniciar(); uart_iniciar(); pwm_apagar();
    integracion_config_ok = adc_configurar() && pwm_configurar(FREQ_SEL, DEADTIME_CICLOS, TRIGGER_PHASE);
    pwm_escribir_referencia(0);
    texto("EL3313 sistema integrado: 100 MHz, PWM 10 kHz, ADC, Timer, INTC\r\n");
    texto("DIAGNOSTICO: sin PR. BTN L selecciona cero/seno estando detenido.\r\n");
    texto("SENO: 50 Hz, m=0.10, cinco segundos. SW15 bloquea salidas.\r\n");
    if (!integracion_config_ok) {
        texto("ERROR de lectura de registros AXI\r\n");
        gpio_escribir_led(LED_FALLA);
        for (;;) { }
    }
    timer_configurar(CICLOS_POR_TS);
    adc_iniciar_conversion();
    plataforma_iniciar_interrupciones(atender_timer);
    timer_arrancar();
    for (;;) {
        uint32_t ahora = integracion_irq;
        uint32_t botones = gpio_leer_entradas();
        uint32_t flancos = botones & ~anterior;
        anterior = botones;
        if ((flancos & (BTN_HABILITAR | BTN_RECONOCER | BTN_EXPORTAR)) && ahora-ultimo_boton >= 200u) {
            ultimo_boton = ahora;
            if ((flancos & BTN_RECONOCER) || integracion_pwm || integracion_arranque_pendiente) {
                integracion_arranque_pendiente = 0;
                pwm_apagar(); integracion_pwm = 0;
            } else if (flancos & BTN_HABILITAR) {
                integracion_arranque_pendiente = 1;
            } else if (!integracion_pwm && (flancos & BTN_EXPORTAR)) {
                integracion_modo_seno ^= 1u;
            }
        }
        gpio_escribir_led((integracion_pwm ? LED_OPERACION : 0u) |
                          (integracion_modo_seno ? 2u : 0u) |
                          (((ahora / 5000u) & 1u) ? LED_LATIDO : 0u));
        if (ahora-ultimo_reporte >= 5000u) {
            uint32_t muestra = integracion_sample;
            ultimo_reporte = ahora;
            texto("IRQ="); numero(ahora);
            texto(" ADC="); numero(muestra & 0xFFFu);
            texto(" ID="); numero(muestra >> 16);
            texto(" STATUS="); numero(integracion_estado_adc);
            texto(" PWM="); numero(integracion_pwm);
            texto(" SENO="); numero(integracion_modo_seno);
            texto(" ISR_MAX_CICLOS="); numero(integracion_isr_max);
            texto("\r\n");
        }
    }
}
