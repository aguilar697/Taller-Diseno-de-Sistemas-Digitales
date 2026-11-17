/* Prueba de la ISR de puesta en marcha con una carga RL y registros simulados. */
#include <assert.h>
#include <math.h>
#include <stdio.h>
#include <string.h>
#define main programa_laboratorio
#include "../embedded/integration/lazo_laboratorio.c"
#undef main

static uint16_t sim_codigo, sim_id;
static uint32_t sim_status, sim_botones, sim_tiempo;
static int sim_pwm, ack, sim_repetir;
static int16_t sim_q, retardo1, retardo2;
static double sim_i;
static float sim_signo;
void gpio_iniciar(void) { }
void uart_iniciar(void) { }
void gpio_escribir_led(uint32_t v) { (void)v; }
void gpio_medicion(int v) { (void)v; }
uint32_t gpio_leer_entradas(void) { return sim_botones; }
int uart_tx_llena(void) { return 0; }
void uart_escribir(uint8_t c) { (void)c; }
void plataforma_iniciar_interrupciones(void (*f)(void)) { (void)f; }
void pwm_apagar(void) { sim_pwm = 0; sim_q = 0; }
int pwm_configurar(uint32_t a, uint32_t b, uint32_t c) { (void)a;(void)b;(void)c;return 1; }
int pwm_habilitar(uint32_t a) { (void)a; assert(ack); sim_pwm = 1; return 1; }
void pwm_escribir_referencia(int16_t q) { sim_q = q; assert(q >= -LAB_MOD_MAX && q <= LAB_MOD_MAX); }
int adc_configurar(void) { return 1; }
void adc_leer(uint16_t *c, uint16_t *id, uint32_t *s) { *c=sim_codigo;*id=sim_id;*s=sim_status;ack=1; }
void adc_iniciar_conversion(void) { assert(!sim_pwm); }
void timer_configurar(uint32_t c) { (void)c; }
void timer_arrancar(void) { }
void timer_reconocer(void) { }
uint32_t timer_contador(void) { return sim_tiempo += 100; }

static void inicializar(float signo)
{
    lab_estado=LAB_CERO; lab_error=lab_irq=lab_ticks=lab_evento=lab_peticion=lab_isr_max=0;
    lab_cero=lab_corriente=lab_referencia=lab_signo_seno=lab_signo_coseno=0;
    suma_cero=muestras_cero=espera_cero=sondeo_fase=0;
    minimo_cero=4095; maximo_cero=0;
    sim_id=0; sim_codigo=1900; sim_status=3; sim_botones=sim_tiempo=0;
    sim_pwm=sim_q=retardo1=retardo2=sim_repetir=0; sim_i=0; sim_signo=signo;
    lectura_iniciar(&lectura,1900,LAB_GANANCIA,1,3,0);
    registro_iniciar(&registro,K_REG);
}
static void paso(int respuesta)
{
    const double r=7.2, l=0.0093, a=exp(-r*0.0001/l);
    double v=(respuesta && sim_pwm) ? 3.0*(double)retardo2/32768.0 : 0;
    sim_i=a*sim_i+(1-a)*v/r;
    retardo2=retardo1; retardo1=sim_q;
    sim_codigo=(uint16_t)lround(1900.0+sim_signo*sim_i/LAB_GANANCIA);
    if (!sim_repetir) ++sim_id;
    ack=0; atender_timer();
}
static void preparar(void)
{
    for (unsigned i=0;i<LAB_CERO_N+1000;i++) paso(0);
    assert(lab_estado==LAB_LISTO && lab_cero==1900 && !sim_pwm);
    lab_peticion=1;
}
static void probar_signo(float signo)
{
    inicializar(signo); preparar();
    for (unsigned i=0;i<LAB_SONDEO_N+20;i++) paso(1);
    assert(lab_estado==LAB_PR);
    assert(lectura.ganancia*signo>0);
    double cuadrado=0;
    for (unsigned i=0;i<LAB_CONTROL_N+20 && lab_estado==LAB_PR;i++) {
        paso(1);
        if (lab_ticks>LAB_CONTROL_N-200) cuadrado+=sim_i*sim_i;
    }
    assert(lab_estado==LAB_FIN && lab_error==0 && !sim_pwm);
    double rms=sqrt(cuadrado/200.0);
    assert(rms>0.060 && rms<0.080);
    assert(registro.congelado && registro_cantidad(&registro)>0);
    unsigned indice=registro.indice;
    paso(0); assert(registro.indice==indice);
    printf("[PASA] signo %+.0f, PR con dos periodos de retardo, RMS=%.4f A y parada finita\n",signo,rms);
}
int main(void)
{
    probar_signo(1); probar_signo(-1);
    inicializar(1); preparar();
    for(unsigned i=0;i<LAB_SONDEO_N+20;i++) paso(0);
    assert(lab_estado==LAB_FALLA && lab_error==ERROR_SIGNO && !sim_pwm);
    puts("[PASA] ausencia de respuesta impide cerrar el lazo");
    inicializar(1); preparar(); paso(1); sim_status=35; paso(1);
    assert(lab_estado==LAB_FALLA && lab_error==ERROR_ADC && !sim_pwm);
    puts("[PASA] overrun del ADC apaga el PWM");
    inicializar(1); preparar(); paso(1); sim_repetir=1;
    for(unsigned i=0;i<3;i++) paso(1);
    assert(lab_estado==LAB_FALLA && lab_error==ERROR_ADC && !sim_pwm);
    puts("[PASA] muestras repetidas apagan el PWM");
    inicializar(1); preparar(); paso(1); sim_botones=BTN_RECONOCER; paso(1);
    assert(lab_estado==LAB_FALLA && lab_error==ERROR_PARADA && !sim_pwm);
    puts("[PASA] boton de parada atendido en la ISR");
    inicializar(1); preparar(); paso(1); sim_i=0.5; paso(1);
    assert(lab_estado==LAB_FALLA && lab_error==ERROR_CORRIENTE && !sim_pwm);
    assert(lab_falla_codigo==sim_codigo && lab_falla_etapa==LAB_SIGNO);
    uint32_t primera=lab_falla_codigo;
    sim_i=0; paso(0);
    assert(lab_falla_codigo==primera && lab_error==ERROR_CORRIENTE);
    puts("[PASA] corriente fuera del limite apaga el PWM");
    return 0;
}
