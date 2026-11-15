/*
 * Prueba de la trama y la máquina de exportación en PC.
 * Se compila con -DREGISTRO_N_BUF=8u. La UART se simula con una FIFO de
 * 16 bytes que se vacía de a 3 bytes por vuelta del lazo.
 */
#include <stdio.h>
#include <string.h>

#include "exportacion.h"

#define FIFO_TAM   16u
#define SALIDA_MAX 512u

static int fallas = 0;

static uint32_t fifo_ocupada = 0;
static uint8_t  salida[SALIDA_MAX];
static uint32_t n_salida = 0;
static int      escritura_con_fifo_llena = 0;

static int uart_llena(void)
{
    return fifo_ocupada >= FIFO_TAM;
}

static void uart_escribir(uint8_t byte)
{
    if (fifo_ocupada >= FIFO_TAM) {
        escritura_con_fifo_llena = 1;
    }
    fifo_ocupada++;
    if (n_salida < SALIDA_MAX) {
        salida[n_salida++] = byte;
    }
}

static void uart_vaciar(uint32_t bytes)
{
    fifo_ocupada = (fifo_ocupada > bytes) ? fifo_ocupada - bytes : 0;
}

static void comprobar(int condicion, const char *descripcion)
{
    printf("[%s] %s\n", condicion ? "PASA" : "FALLA", descripcion);
    if (!condicion) {
        fallas++;
    }
}

static uint16_t leer_16(const uint8_t *p)
{
    return (uint16_t)(p[0] | (p[1] << 8));
}

static uint32_t leer_32(const uint8_t *p)
{
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

/* Corre el lazo hasta terminar; devuelve las vueltas usadas */
static int exportar_todo(exportacion_t *e)
{
    int vueltas = 0;
    while (exportacion_en_curso(e) && vueltas < 10000) {
        exportacion_paso(e);
        uart_vaciar(3u);
        vueltas++;
    }
    return vueltas;
}

int main(void)
{
    static registro_t reg;
    exportacion_t e;
    trama_info_t info;
    uint16_t crc;
    uint32_t i;
    int vueltas;
    const char *texto = "123456789";

    /* CRC-16/CCITT-FALSE: valor de verificación estándar */
    crc = TRAMA_CRC_INICIAL;
    for (i = 0; i < 9u; i++) {
        crc = trama_crc(crc, (uint8_t)texto[i]);
    }
    comprobar(crc == 0x29B1u, "CRC de \"123456789\" = 0x29B1");

    /* Registro con 10 muestras: el buffer de 8 da la vuelta */
    registro_iniciar(&reg, 1u);
    for (i = 0; i < 10u; i++) {
        registro_guardar(&reg, 0.001f * (float)i, -0.002f * (float)i, (int16_t)(100 * i), (uint16_t)(65530u + i));
    }

    memset(&info, 0, sizeof(info));
    info.estado = 2u;
    info.f_sw = 20000u;
    info.ts_ns = 50000u;
    info.k_reg = 2u;
    info.n = 999u;                 /* lo reemplaza la cantidad real del registro */
    info.amplitud_ma = 500u;
    info.causa = 0x0005u;
    info.t_isr_max = 1234u;
    info.perdidas = 0x01020304u;

    exportacion_iniciar(&e, &reg, uart_llena, uart_escribir);
    comprobar(!exportacion_en_curso(&e), "iniciar: en reposo");
    comprobar(exportacion_solicitar(&e, &info) == 1, "solicitar: aceptada");
    comprobar(reg.congelado == 1u, "al solicitar se congela el buffer");
    comprobar(exportacion_solicitar(&e, &info) == 0, "segunda solicitud en curso: rechazada");

    /* Un paso con la FIFO llena no escribe nada */
    fifo_ocupada = FIFO_TAM;
    exportacion_paso(&e);
    comprobar(n_salida == 0u, "FIFO llena: el paso vuelve sin escribir");
    fifo_ocupada = 0;

    /* Un paso escribe como máximo lo que cabe en la FIFO */
    exportacion_paso(&e);
    comprobar(n_salida == FIFO_TAM, "un paso escribe 16 bytes (lo que cabe) y vuelve");

    vueltas = exportar_todo(&e);
    comprobar(!exportacion_en_curso(&e), "termina y vuelve a reposo");
    comprobar(reg.congelado == 0u, "al terminar se descongela el buffer");
    comprobar(!escritura_con_fifo_llena, "nunca escribe con la FIFO llena");
    comprobar(vueltas > 1, "la trama se envía en varias vueltas del lazo");

    /* Contenido de la trama */
    comprobar(n_salida == TRAMA_ENCABEZADO + 8u * TRAMA_MUESTRA + 2u, "largo = 28 + 8*8 + 2 = 94 bytes");
    comprobar(salida[0] == 0xA5u && salida[1] == 0x5Au && salida[2] == TRAMA_VERSION, "sincronismo y versión");
    comprobar(salida[3] == 2u && leer_32(&salida[4]) == 20000u && leer_32(&salida[8]) == 50000u,
              "estado, f_sw y Ts en little-endian");
    comprobar(leer_16(&salida[12]) == 2u && leer_16(&salida[14]) == 8u, "K_REG y N = 8 (cantidad real)");
    comprobar(leer_16(&salida[16]) == 500u && leer_16(&salida[18]) == 0x0005u, "amplitud y causa");
    comprobar(leer_32(&salida[20]) == 1234u && leer_32(&salida[24]) == 0x01020304u, "t_isr_max y pérdidas");

    /* Muestras en orden cronológico: la más antigua es la número 2 */
    comprobar(leer_16(&salida[28 + 6]) == (uint16_t)65532u, "primera muestra: n = 65532 (la más antigua)");
    comprobar((int16_t)leer_16(&salida[28]) == 2 && (int16_t)leer_16(&salida[28 + 2]) == -4 &&
              (int16_t)leer_16(&salida[28 + 4]) == 200, "primera muestra: i_med, i_ref y m (con signo)");
    comprobar(leer_16(&salida[28 + 7 * 8 + 6]) == 3u, "última muestra: n = 3 (vuelta de 16 bits)");

    /* CRC de los bytes 2 a 91 */
    crc = TRAMA_CRC_INICIAL;
    for (i = 2; i < n_salida - 2u; i++) {
        crc = trama_crc(crc, salida[i]);
    }
    comprobar(leer_16(&salida[n_salida - 2u]) == crc, "CRC al final coincide con el recalculado");

    /* Un byte alterado cambia el CRC */
    salida[40] ^= 0x01u;
    crc = TRAMA_CRC_INICIAL;
    for (i = 2; i < n_salida - 2u; i++) {
        crc = trama_crc(crc, salida[i]);
    }
    comprobar(leer_16(&salida[n_salida - 2u]) != crc, "un bit alterado se detecta");

    /* Registro vacío: encabezado y CRC */
    registro_iniciar(&reg, 1u);
    n_salida = 0;
    fifo_ocupada = 0;
    exportacion_solicitar(&e, &info);
    exportar_todo(&e);
    comprobar(n_salida == TRAMA_ENCABEZADO + 2u && leer_16(&salida[14]) == 0u,
              "registro vacío: 30 bytes con N = 0");

    printf("\n%s: %d fallas\n", fallas ? "RESULTADO NEGATIVO" : "RESULTADO POSITIVO", fallas);
    return fallas ? 1 : 0;
}
