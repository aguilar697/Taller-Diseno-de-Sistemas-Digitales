/* Aplicación de control: estados, ISR y lazo principal */
#ifndef APLICACION_H
#define APLICACION_H

#include <stdint.h>

#include "antirrebote.h"
#include "control_pr.h"
#include "exportacion.h"
#include "lectura.h"
#include "modulacion.h"
#include "referencia.h"
#include "registro.h"
#include "supervision.h"

/* Estados de la aplicación */
typedef enum {
    ESTADO_INICIO,
    ESTADO_DETENIDO,
    ESTADO_OPERACION,
    ESTADO_FALLA
} estado_t;

/* Solicitudes del lazo principal a la ISR */
typedef enum {
    SOLICITUD_NINGUNA,
    SOLICITUD_HABILITAR,
    SOLICITUD_APAGAR
} solicitud_t;

/* Estado completo de la aplicación (se declara global: incluye 8 KB de registro) */
typedef struct {
    /* Compartidas ISR / lazo */
    volatile estado_t    estado;
    volatile solicitud_t solicitud;
    volatile uint32_t    iteraciones;   /* base de tiempo del lazo */
    volatile uint32_t    t_isr_max;     /* ciclos */

    /* Bloques del lazo */
    lectura_t      lectura;
    supervision_t  supervision;
    referencia_t   referencia;
    pr_t           pr;
    modulacion_t   modulacion;
    registro_t     registro;
    int16_t        q_ultimo;            /* última REFERENCE */
    uint32_t       arranque;            /* períodos con m = 0 que faltan */

    /* Lazo principal */
    antirrebote_t  entradas;
    exportacion_t  exportacion;
} aplicacion_t;

void app_iniciar(aplicacion_t *app);
void app_isr(aplicacion_t *app);
void app_lazo_paso(aplicacion_t *app);

#endif
