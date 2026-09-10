# Revisión de diagramas e integración

Revisión: 10 de septiembre de 2026. Alcance: diagramas iniciales, instructivo
del proyecto y contrato compartido por el equipo. No equivale a aprobación del
profesor ni a validación funcional del sistema completo.

## Imagen inicial de niveles 1 y 2

| Hallazgo | Corrección en la versión editable |
|---|---|
| RX y TX tienen flechas en ambos sentidos | Separar PC→FPGA y FPGA→PC |
| Tiempo, intentos y victorias parecen salir del motor | Dibujar su origen en S1 |
| Falta `letter_valid` en la conexión hacia el motor | Incluir el evento junto al byte |
| Faltan `letter_correct` y `letter_repeated` de retorno | Incluir ambos resultados hacia S1 |
| Nivel 2 incluye los bloques internos de cada subsistema | Mostrar solo los cuatro subsistemas; desarrollar sus interiores en nivel 3 |
| La PC aparece fuera de FPGA pero no se indica su responsable | Identificar Python como parte de S3, ejecutada en PC |

El primer dibujo es un contexto de la FPGA. Es válido si ese límite se declara;
si se llama «sistema FPGA+PC completo como caja negra», la PC ya no debería
representarse como un elemento externo a esa caja.

## PDF inicial del motor

La página 1 presenta correctamente el objetivo y los puertos acordados. Es
la vista externa del subsistema, no su descomposición interna. La página 2
contiene una base adecuada de tercer nivel: LFSR, selector, ROM, registros y
validador con funciones identificadas.

Cambios necesarios para que el diagrama sea verificable:

1. Mostrar `used_letters` como registro interno que vuelve al validador.
2. Mostrar la realimentación del patrón actual y su escritura actualizada.
3. Mostrar longitud y validez de ROM hacia el selector: el modo difícil debe
   rechazar palabras cortas y los índices fuera de banco.
4. Separar `revealed_word` (patrón) de `word_complete` (todas las posiciones
   válidas están reveladas). La nota azul bajo el patrón confunde ambas funciones.
5. Incluir `word_ready`, `letter_correct` y `letter_repeated` en la vista interna.
6. Explicar que los registros son propiedad del motor; no son tres periféricos externos.
7. Definir qué ocurre en SELECT si el índice es inválido, qué prioridad tiene
   reset/new_game y en qué ciclo se entrega el resultado de una letra.
8. Evitar usar directamente el estado no nulo de un LFSR de 6 bits como índice
   0–49: el cero no aparecería. La propuesta resta uno y rechaza candidatos ≥50.

El cuarto nivel debe desarrollar los bloques: recurrencia del LFSR,
organización de ROM, ecuaciones de coincidencia, máscaras y registros. Cambiar
el título de un dibujo con los mismos bloques no constituye un nuevo nivel.

## Acuerdos pendientes antes de integrar subsistemas

Kevin autorizó implementar las convenciones propuestas de empaquetado y
evaluación para su motor. Se conservan como propuestas de integración hasta
que los otros responsables revisen su uso; no se cambiaron sus módulos.

| Tema | Situación / propuesta a revisar con el grupo |
|---|---|
| Orden de bytes | UART ya utiliza carácter 0 en `[7:0]`; adoptar y documentar la misma convención en S1, S2 y S4 |
| Relleno | Propuesta: espacios ASCII 0x20 fuera de `word_length`, guiones bajos 0x5F dentro de posiciones ocultas |
| Reset | Propuesta para motor: síncrono activo en alto |
| Resultado de letra | Propuesta: evaluación registrada en el flanco que acepta `letter_valid`; S1 lee los resultados en el siguiente flanco |
| Letra inválida | UART y S1 deben filtrar A–Z antes de solicitar evaluación; S2 descarta defensivamente cualquier otro valor |
| Palabra final | UART espera `final_word_i`; S2 no tiene salida de palabra secreta. No añadir puerto ni reutilizar patrón sin acuerdo explícito |
| Eventos UART | S1 debe conservar evento y datos hasta aceptación `event_valid && event_ready`; definir cola/prioridad si hay eventos consecutivos |
| Fin de tiempo y última letra simultáneos | Definir prioridad en S1 y cubrirla mediante prueba de integración |
| Lenguaje del núcleo recibido | Confirmar si el VHDL proporcionado es excepción al requisito general SystemVerilog |
| Registros UART | Conciliar RX solo lectura y `new_rx` W1C implementados con campos RW descritos en el instructivo |
| Aplicación Python | Coordinar el prototipo de Cortés con Daniel; selección e inicio son por botones locales según instructivo |

## Tareas propuestas para issues

Estas tareas son borradores de planificación, no issues publicados.

- **S2 diseño:** revisar diagramas y aprobar semántica temporal y empaquetado.
- **S2 implementación:** ROM de 50 palabras, selección LFSR y evaluación.
- **S2 verificación:** cobertura del banco, longitudes, repeticiones y límites.
- **Integración S1/S2/S3:** resolver acceso a palabra final y entrega de eventos.
- **Entrega:** simulación temporizada post-implementación y pruebas físicas.

Cada issue debe indicar responsable, criterio de aceptación, commits asociados
y evidencia de validación. El Pull Request debe recibir revisión de otro integrante.
