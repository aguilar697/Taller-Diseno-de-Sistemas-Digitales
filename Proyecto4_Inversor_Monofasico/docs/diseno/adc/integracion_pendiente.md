# Integración y validación del ADC

`adc_system_axi` está conectado al Block Design de MicroBlaze V, con base `0x44A00000`, reloj de 100 MHz y reset AXI activo bajo. El PWM envía un pulso de un ciclo en fase 5000 a 10 kHz. La ISR del Timer consulta la muestra y reconoce su token por AXI. El periférico ADC opera sin IRQ dedicada.

| Área | Verificación pendiente |
|---|---|
| Plataforma | Comprobar reconstrucción y compatibilidad del XADC con Vivado/Vitis 2025.1. |
| Temporización y software | Medir el presupuesto de adquisición, ISR y actuación en FPGA. Comprobar la recuperación tras fallas y reset coordinado durante la prueba integrada. |
| Instrumentación | Calibrar cero y ganancia con signo en VAUX6. Verificar el escalamiento, el ruido y la corriente medida bajo conmutación. |

## Límites explícitos

- Solo se conserva la última muestra. Una publicación pendiente sobrescrita deja `overrun` persistente; no se garantiza entrega sin pérdidas.
- SAMPLE y ACK_ID forman una pareja coherente únicamente con accesos ordenados y exclusión entre lectores. Otro maestro, ISR o depurador que lea SAMPLE puede reemplazar el snapshot.
- El ACK antiguo de CONTROL.bit1 devuelve SLVERR. La constante del header solo permite identificar código legado; el software definitivo debe escribir ACK_ID.
- El token de 32 bits no se reutiliza dentro de una sesión. Después de `0xFFFFFFFF`, pasa a cero y bloquea ACK hasta un reset coordinado. A 20 k publicaciones/s esto ocurre aproximadamente a las 59,65 horas.
- Reset reutiliza la numeración. La plataforma debe cancelar operaciones anteriores y coordinar el reset con captura y ACK. Un reset externo no comunicado al driver no queda resuelto por estos registros.
- El header declara la interfaz de registros. El acceso MMIO corresponde al driver y la aplicación debe coordinar la captura, el reconocimiento y el reset.

Las interfaces directas de `adc_control` y `adc_top` incluyen `ack_id_i[31:0]` y `sample_token_o[31:0]`. `adc_system_axi` conecta esos puertos internamente. El [mapa de registros](mapa_registros.md) especifica el protocolo y la [guía de Basys 3](../integracion_basys3.md) detalla la conexión física.
