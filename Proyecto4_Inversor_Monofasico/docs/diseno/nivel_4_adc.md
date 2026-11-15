# Cuarto nivel — Control de conversión y captura ADC/XADC

Este documento resume la implementación digital de la [arquitectura de adquisición](nivel_3_adc.md). El detalle de registros y reconocimiento se mantiene en un único [contrato implementado](adc/mapa_registros.md). Se desarrolló y verificó aisladamente en Vivado 2026.1; la compatibilidad con 2025.1, la plataforma MicroBlaze V y las pruebas físicas siguen pendientes.

![Cuarto nivel del subsistema ADC/XADC](img/nivel_4_adc.svg)

**Figura 1.** Vista funcional de adquisición y acceso AXI. El diagrama conserva la descomposición del sistema; los puertos, offsets y prioridades definitivos se especifican en la documentación del RTL, incluido ACK_ID en 0x10.

## Control y adquisición

`adc_system_axi` conecta `adc_axi_lite` con `adc_top`; este último instancia `adc_control` y `xadc_wiz_0`. El controlador usa IDLE → WAIT_EOC → SEND_READ → WAIT_DRDY: emite CONVST, espera un flanco EOC posterior, solicita una lectura DRP con DEN y publica únicamente al recibir DRDY.

La configuración entregada usa VAUX6, dirección DRP `0x16`, modo por evento y reloj de 100 MHz. Se normaliza DO[15:4] a un código de 12 bits. El reset externo es activo bajo y se invierte para XADC. La liberación sincronizada del reset corresponde a la plataforma. No se incluye transferencia entre dominios de reloj.

El evento PWM y START por software producen una conversión cuando el controlador está libre. Si coinciden se acepta una sola y se marca `missed_trigger`; si llegan durante `busy`, se conserva la conversión en curso y se diagnostica el evento no atendido. No se implementa una cola. Cada espera de EOC o DRDY tiene un límite configurable de 1024 ciclos; el timeout conserva la última muestra y no publica datos incompletos.

## Publicación y acceso AXI

SAMPLE publica juntos ID modular de 16 bits, cuatro ceros y código de 12 bits. El primer resultado tras reset tiene ID 1. `valid` persiste hasta reset; `new_data` permanece hasta un ACK válido o reset. `missed_trigger`, `overrun` y `timeout` son persistentes hasta reset.

El esclavo acepta AW y W independientemente y mantiene B/R estables bajo espera del receptor. CONTROL, STATUS, SAMPLE y ERROR conservan offsets 0x00, 0x04, 0x08 y 0x0C; ACK_ID ocupa 0x10. El [mapa](adc/mapa_registros.md) define bits, WSTRB, SLVERR y valores de reset.

Leer SAMPLE captura simultáneamente su palabra y el token completo de 32 bits. Leer ACK_ID devuelve ese snapshot aunque llegue otra publicación. El driver debe serializar SAMPLE → ACK_ID entre lectores, procesar la palabra y devolver exactamente su token. El controlador compara el token en el flanco del reconocimiento; un ACK atrasado no consume la muestra nueva y una publicación simultánea tiene prioridad.

El ID de 16 bits puede envolver sin reutilizar el token de 32 bits dentro de la sesión. Tras agotar este último se bloquea ACK con token cero hasta reset coordinado. Reset inicia una sesión nueva y cancela las operaciones anteriores; la plataforma debe impedir reconocer un token antiguo después de un reinicio.

## Integración y evidencia

Las seis [pruebas ejecutadas](adc/verificacion.md) comprueban control, modelo XADC, interfaz AXI, concurrencia y coherencia SAMPLE/ACK_ID. La síntesis aislada y sus [advertencias](adc/advertencias_sintesis.md) no sustituyen la implementación y ruteo del sistema.

La base AXI, el empaquetado, MMIO y exclusión de lectores, la política de reset, el disparo PWM definitivo y el presupuesto adquisición–ISR–actuación requieren integración con los responsables. El canal físico, acondicionamiento, escala, signo y calibración requieren validación de instrumentación. El código bruto no representa directamente amperios. Ver [pendientes](adc/integracion_pendiente.md) y [temporización](adc/temporizacion_y_sincronizacion.md).

[Tercer nivel de adquisición](nivel_3_adc.md) · [Fuentes y reproducción](adc/README.md) · [Índice del diseño](README.md)
