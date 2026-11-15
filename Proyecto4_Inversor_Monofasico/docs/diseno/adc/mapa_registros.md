# Registros AXI y procedimiento de reconocimiento

Datos 32 bits, direcciones locales en bytes; ADDR_WIDTH predeterminado 6, mínimo 5 para representar 0x10. La dirección base sigue pendiente de Address Editor. No se modifican los cuatro offsets existentes.

| Offset | Registro | Lectura | Escritura |
|---|---|---|---|
| 0x00 | CONTROL | 0, OKAY | Bit 0 START por pulso; bit 1 ACK antiguo rechazado con SLVERR |
| 0x04 | STATUS | Estado, OKAY | SLVERR |
| 0x08 | SAMPLE | Instantánea de muestra, OKAY; captura también su token | SLVERR |
| 0x0C | ERROR | Diagnóstico, OKAY | SLVERR |
| 0x10 | ACK_ID | Token 32 asociado al último SAMPLE leído, OKAY | Token 32 de la muestra consumida; emite un pulso ACK |

STATUS: bit 0 valid, 1 new_data, 2 busy del controlador, 3 xadc_busy, 4 missed_trigger, 5 overrun, 6 timeout; resto 0. ERROR: bit 0 missed_trigger, 1 overrun, 2 timeout; resto 0. Los errores son persistentes hasta reset; ACK no los limpia.

SAMPLE: ID[31:16], ceros[15:12], código[11:0]. La lectura es atómica. STATUS/ERROR son instantáneas separadas, no una lectura multirregistro atómica.

## Escrituras y respuestas

- CONTROL usa WSTRB[0]. START conserva su posición y genera un pulso de un ciclo. Bits 2..31 reservados se ignoran.
- Si CONTROL.bit1=1 y WSTRB[0]=1, se rechaza la escritura completa con SLVERR, incluso START+ACK. No se emite ninguno de esos comandos. Con byte 0 deshabilitado no hay acciones. No hay fallback inseguro.
- ACK_ID requiere WSTRB=4'b1111 y token no nulo: OKAY y un pulso `ack_sample_o` con `ack_id_o` estable. WSTRB=0 es un no-op OKAY. Cualquier máscara parcial no nula o token 0 con escritura completa devuelve SLVERR y no emite ACK.
- Un token no nulo atrasado puede recibir OKAY: significa que el comando fue transportado, no que se consumió la muestra. El controlador vuelve a comparar en el flanco del efecto y lo ignora si dejó de coincidir.
- Accesos no alineados, direcciones no definidas y escrituras RO devuelven SLVERR. Lecturas inválidas devuelven además 0.
- AW/W se capturan independientemente en cualquier orden. Una escritura se ejecuta una sola vez; BVALID/BRESP y RVALID/RDATA/RRESP se conservan bajo backpressure.

## Concurrencia, duplicados y prioridad

Un token coincidente limpia solo new_data; SAMPLE, valid y ERROR se conservan. Un ACK duplicado no tiene efecto después de consumirse la muestra. Un ACK antiguo no coincide con el token de una muestra nueva, aun cuando ID16 haya dado una vuelta completa. En publicación y ACK simultáneos gana la publicación: el nuevo dato queda pendiente. Un ACK de un valor futuro no consume una publicación del mismo flanco.

ACK_ID leído es el token de la última lectura SAMPLE, no un registro que siga al conversor ni un espejo del último valor escrito. Leerlo antes de leer SAMPLE devuelve 0 después de reset. Si otro consumidor intercala una lectura SAMPLE entre las dos lecturas, modifica ese snapshot: el software debe serializar la pareja de accesos.

## Reset y agotamiento

Reset cancela capturas AW/W y respuestas B/R pendientes, elimina el snapshot AXI, borra muestras/estados/tokens y reinicia la numeración. Un comando ejecutado antes del reset no se revierte, pero no se conserva para ejecutarlo después. La plataforma y el driver deben abortar operaciones pendientes y descartar tokens de la sesión anterior; no se garantiza reconocer tokens a través de reset/reconfiguración.

Después de 2^32−1 publicaciones reconocibles, el token pasa a 0 y queda bloqueado hasta reset. No se reutilizan valores dentro de una sesión; las conversiones continúan y new_data permanece pendiente. ACK_ID=0 tras una lectura de SAMPLE válida identifica esa condición. Debe gestionarse un reset coordinado, nunca truncar el token a 16 bits. A 20 k conversiones/s este límite se alcanza aproximadamente a las 59.65 h; el límite real se cuenta por publicaciones, no por tiempo.

## Procedimiento para MicroBlaze V

El [header adc_regs.h](../../../software/embedded/drivers/adc/adc_regs.h) contiene offsets/máscaras y comentarios del protocolo. No se implementó ni validó un BSP. Las primitivas siguientes representan accesos IO de 32 bits ordenados que debe proporcionar la plataforma:

El pseudoflujo definitivo con exclusión y sesión se encuentra al final de este documento.

Las funciones de exclusión, sesión, MMIO y consumo son contratos por implementar en la plataforma. El procesador debe aplicar el orden y las barreras de E/S necesarios; no basta una lectura cacheada. Tras capturar ambos valores puede procesarlos después y devolver exactamente ese token: si llegó una muestra nueva, el ACK antiguo se ignora y esa nueva notificación permanece.

Volver a consultar STATUS y SAMPLE permite consumir la publicación pendiente; no inferir entrega sin pérdidas a partir de BRESP. La pérdida por sobrescritura sigue indicada en overrun. Las diferencias de ID16 se interpretan modularmente para diagnóstico, pero jamás sustituyen el token 32 al reconocer.

No se implementa conversión a corriente, PR, ISR, PWM ni UART. La base, las primitivas BSP, el bloqueo entre consumidores y la política de reset deben aprobarse en integración.

## Lecturas separadas por una publicación: garantía comprobada

Las lecturas AXI no son una transacción atómica conjunta. La coherencia proviene del registro interno `read_sample_token`: al aceptar AR para SAMPLE, el mismo bloque secuencial captura RDATA desde `sample_i` y ese registro desde `sample_token_i`. Publicar otra muestra no escribe ese snapshot. AR para ACK_ID devuelve el snapshot, no `sample_token_i`.

| Evento | Muestra viva | SAMPLE que recibió el procesador | ACK_ID que devolverá el snapshot |
|---|---|---|---|
| Leer SAMPLE de ID2 | ID2 | ID2 | token de ID 2 |
| Publicar ID3 | ID3 | ID2, guardado localmente | Sigue token de ID 2 |
| Leer ACK_ID | ID3 | ID2 | token de ID 2 |
| Escribir token de ID 2 | ID3 | ID2 procesado | ACK obsoleto; new_data de ID3 permanece 1 |

`tb_adc_read_coherence` reprodujo esta secuencia con lecturas completadas, no solo con RDATA detenido. También publicó después de la lectura del token y antes de ACK: el comparador del controlador preservó la notificación posterior.

No se sustituye este contrato por “token, muestra, token”. En este mapa ACK_ID no es un contador vivo: el primer token pertenecería al SAMPLE anterior, y la lectura de SAMPLE renueva ese snapshot. El patrón clásico presupone un contador vivo. Aplicarlo aquí puede provocar reintentos innecesarios porque la lectura de SAMPLE renueva el snapshot; no se necesita para la coherencia de la pareja capturada bajo exclusión. [Prueba y límites](verificacion.md).

### Exclusión y reset en el procedimiento definitivo

La plataforma debe serializar SAMPLE→ACK_ID entre todos los lectores, incluidos ISR, tareas y maestros de depuración que accedan a SAMPLE. Una lectura SAMPLE intercalada sí cambia el snapshot. Comparar solo ID16 no reemplaza esa exclusión, especialmente al envolver el identificador.

El driver también necesita un identificador de sesión de software y coordinación con reset. Debe capturarlo bajo la misma exclusión que la pareja y comprobarlo de nuevo antes de escribir ACK, sin permitir un reset coordinado entre la comprobación y el acceso MMIO. La rutina que reinicie el periférico incrementará esa sesión e invalidará las operaciones pendientes. Es un requisito de integración; estas funciones aún no forman parte de un BSP probado.

```c
/* Pseudoflujo, con accesos de 32 bits ordenados proporcionados por el BSP. */
have_sample = false;
lock_reader_and_reset();
session = current_session();
status = mmio_read32(base + ADC_STATUS_OFFSET);
if ((status & (ADC_STATUS_VALID | ADC_STATUS_NEW_DATA)) ==
    (ADC_STATUS_VALID | ADC_STATUS_NEW_DATA)) {
    sample = mmio_read32(base + ADC_SAMPLE_OFFSET);
    token  = mmio_read32(base + ADC_ACK_ID_OFFSET);
    have_sample = token != ADC_ACK_ID_INVALID;
}
unlock_reader_and_reset();
if (have_sample) {
    consume_raw_sample(sample);
    lock_reader_and_reset();
    if (session == current_session())
        mmio_write32(base + ADC_ACK_ID_OFFSET, token);
    unlock_reader_and_reset();
}
```

Los locks deben cubrir efectivamente todos los lectores y el mecanismo de reset de la plataforma. Un reset externo no comunicado al driver puede reutilizar el mismo token numérico; estos registros no contienen una época persistente entre resets. No se declara resuelto ese caso por comparar números ni por repetir lecturas.
