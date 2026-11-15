# Pendientes antes de integrar el ADC

La simulación y síntesis del periférico aislado no acreditan una plataforma MicroBlaze V ni pruebas físicas.

| Área / responsable | Acuerdo o implementación pendiente |
|---|---|
| Plataforma / Daniel Puentes | Resolver Vivado 2026.1 frente a 2025.1; empaquetar o conectar el RTL; asignar base y segmento AXI que cubra al menos 0x00–0x13; reloj de 100 MHz y reset coordinado; revisar restricciones y temporización integrada. |
| Control / Kevin Cortés | Implementar y probar MMIO ordenado/no cacheado de 32 bits, exclusión de todos los lectores, sesiones de reset, ACK con token completo y tratamiento de token cero, overrun y timeout. Integrar ISR y control PR por separado. |
| PWM / Kevin Aguilar | Conectar el evento de un ciclo en el mismo dominio de 100 MHz; acordar fase, frecuencia, reset y disable; medir el presupuesto adquisición–ISR–actuación. No existe CDC en este periférico. |
| Instrumentación / PEDP y adquisición | Confirmar VAUX6, pinout, rango eléctrico, acondicionamiento, signo, escala y calibración; verificar mediciones físicas antes de interpretar código bruto como corriente. |

## Límites explícitos

- Solo se conserva la última muestra. Una publicación pendiente sobrescrita deja `overrun` persistente; no se garantiza entrega sin pérdidas.
- SAMPLE y ACK_ID forman una pareja coherente únicamente con accesos ordenados y exclusión entre lectores. Otro maestro, ISR o depurador que lea SAMPLE puede reemplazar el snapshot.
- El ACK antiguo de CONTROL.bit1 devuelve SLVERR. La constante del header solo permite identificar código legado; el software definitivo debe escribir ACK_ID.
- El token de 32 bits no se reutiliza dentro de una sesión. Después de `0xFFFFFFFF`, pasa a cero y bloquea ACK hasta un reset coordinado. A 20 k publicaciones/s esto ocurre aproximadamente a las 59,65 horas.
- Reset reutiliza la numeración. La plataforma debe cancelar operaciones anteriores y coordinar el reset con captura y ACK. Un reset externo no comunicado al driver no queda resuelto por estos registros.
- El header no implementa BSP, barreras, bloqueos ni gestión de sesiones. No se ha compilado o ejecutado software MicroBlaze V.
- Faltan restricciones de E/S, reloj superior, implementación y ruteo. No hay bitstream, ensayos eléctricos, pruebas de potencia ni validación física.

Las interfaces directas de `adc_control` y `adc_top` requieren `ack_id_i[31:0]` y `sample_token_o[31:0]`; `adc_system_axi` ya conecta esos puertos internamente. Ver el [mapa definitivo](mapa_registros.md).
