/* Funciones de los drivers que usa la aplicación */
#ifndef DRIVERS_H
#define DRIVERS_H

#include <stdint.h>

/* PWM */
void     pwm_apagar(void);
int      pwm_configurar(uint32_t freq_sel, uint32_t deadtime, uint32_t phase);  /* 1 si la comprobación coincide */
int      pwm_habilitar(uint32_t freq_sel);                                      /* 1 si running sube */
void     pwm_escribir_referencia(int16_t q);

/* Adquisición */
#define ADC_ESTADO_VALIDO  0x01u                                                /* ya hay muestra */
int      adc_configurar(void);
void     adc_leer(uint16_t *codigo, uint16_t *n, uint32_t *estado);
void     adc_iniciar_conversion(void);

/* GPIO */
void     gpio_iniciar(void);
uint32_t gpio_leer_entradas(void);
void     gpio_escribir_led(uint32_t mascara);
void     gpio_medicion(int nivel);

/* UART (sin espera) */
void     uart_iniciar(void);
int      uart_tx_llena(void);
void     uart_escribir(uint8_t byte);

/* Timer */
void     timer_configurar(uint32_t carga);
void     timer_arrancar(void);
uint32_t timer_contador(void);                                                  /* ciclos, ascendente */
void     timer_reconocer(void);

#endif
