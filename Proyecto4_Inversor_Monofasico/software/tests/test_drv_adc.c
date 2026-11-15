/*
 * Prueba del driver del ADC en PC, con un modelo de los registros
 * (docs/diseno/adc/mapa_registros.md). Se compila con -DADC_BASE=0x40000000u.
 */
#include <stdio.h>

#include "adc_regs.h"
#include "drivers.h"
#include "mmio.h"

static int fallas = 0;

static void comprobar(int condicion, const char *descripcion)
{
    printf("[%s] %s\n", condicion ? "PASA" : "FALLA", descripcion);
    if (!condicion) {
        fallas++;
    }
}

/* Modelo del ADC */
static uint32_t token = 0;          /* publicaciones de la sesión */
static uint32_t muestra_viva = 0;   /* ID[31:16] y código[11:0] */
static uint32_t snapshot_token = 0; /* token del último SAMPLE leído */
static int      valido = 0, nuevo = 0;
static uint32_t errores = 0;
static uint32_t control_escrito = 0;
static uint32_t acks = 0;
static int      publicar_en_status = 0;
static uint16_t codigo_en_status = 0;

static void publicar(uint16_t codigo)
{
    token++;
    if (nuevo) {
        errores |= ADC_ERROR_OVERRUN;
    }
    muestra_viva = ((token & 0xFFFFu) << 16) | (codigo & 0x0FFFu);
    valido = 1;
    nuevo = 1;
}

uint32_t mmio_leer32(uintptr_t direccion)
{
    switch (direccion - ADC_BASE) {
    case ADC_STATUS_OFFSET: {
        uint32_t s = (valido ? ADC_STATUS_VALID : 0u) | (nuevo ? ADC_STATUS_NEW_DATA : 0u);
        if (publicar_en_status) {          /* muestra que llega entre STATUS y SAMPLE */
            publicar_en_status = 0;
            publicar(codigo_en_status);
        }
        return s;
    }
    case ADC_SAMPLE_OFFSET:
        snapshot_token = valido ? token : 0u;
        return valido ? muestra_viva : 0u;
    case ADC_ERROR_OFFSET:
        return errores;
    case ADC_ACK_ID_OFFSET:
        return snapshot_token;
    default:
        return 0;
    }
}

void mmio_escribir32(uintptr_t direccion, uint32_t valor)
{
    if (direccion - ADC_BASE == ADC_CONTROL_OFFSET) {
        control_escrito = valor;
    } else if (direccion - ADC_BASE == ADC_ACK_ID_OFFSET) {
        acks++;
        if (valor != 0u && valor == token) {
            nuevo = 0;
        }
    }
}

int main(void)
{
    uint16_t codigo, n;
    uint32_t estado, i;
    int ok;

    /* Configuración */
    comprobar(adc_configurar() == 1, "configurar: sin errores -> 1");
    errores = ADC_ERROR_TIMEOUT;
    comprobar(adc_configurar() == 0, "configurar: con error persistente -> 0");
    errores = 0;

    /* Antes de la primera muestra */
    adc_leer(&codigo, &n, &estado);
    comprobar(!(estado & ADC_ESTADO_VALIDO) && n == 0u && codigo == 0u && acks == 0u,
              "sin muestra: estado no válido y sin ACK");

    /* Inicio por software */
    adc_iniciar_conversion();
    comprobar(control_escrito == ADC_CONTROL_START, "iniciar conversión: CONTROL = START");

    /* Primera muestra */
    publicar(0x123u);
    adc_leer(&codigo, &n, &estado);
    comprobar((estado & ADC_ESTADO_VALIDO) && codigo == 0x123u && n == 1u,
              "muestra 1: código 0x123 y n = 1");
    comprobar(nuevo == 0, "la muestra queda reconocida (new_data = 0)");

    /* Muestra repetida: el mismo n y ningún overrun */
    adc_leer(&codigo, &n, &estado);
    comprobar(n == 1u && errores == 0u, "segunda lectura sin publicar: mismo n, sin overrun");

    /* Muestra que llega entre STATUS y SAMPLE */
    publicar_en_status = 1;
    codigo_en_status = 0x456u;
    adc_leer(&codigo, &n, &estado);
    comprobar(codigo == 0x456u && n == 2u && nuevo == 0,
              "muestra entre STATUS y SAMPLE: se lee y se reconoce");
    publicar(0x789u);
    comprobar(errores == 0u, "la siguiente publicación no produce overrun");

    /* Una muestra por período durante 70 000 períodos: n da la vuelta */
    ok = 1;
    for (i = 0; i < 70000u; i++) {
        adc_leer(&codigo, &n, &estado);
        if (n != (uint16_t)(token & 0xFFFFu)) {
            ok = 0;
        }
        publicar((uint16_t)(i & 0x0FFFu));
    }
    comprobar(ok && errores == 0u, "70 000 muestras: n sigue al ID de 16 bits y nunca hay overrun");

    printf("\n%s: %d fallas\n", fallas ? "RESULTADO NEGATIVO" : "RESULTADO POSITIVO", fallas);
    return fallas ? 1 : 0;
}
