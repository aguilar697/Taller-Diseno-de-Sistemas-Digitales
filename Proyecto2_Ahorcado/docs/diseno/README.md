# Planteamiento de diseño — Ahorcado

Esta arquitectura expresa la división acordada por el equipo. Los diagramas
Mermaid son editables y GitHub los presenta dentro de este documento. Las
convenciones temporales todavía pendientes se identifican explícitamente en
el [diseño del motor](nivel_3_motor_del_juego.md).

## Objetivo y límites

La FPGA implementa las reglas y conserva el estado del juego. La terminal
Python permite enviar letras y visualizar respuestas. Todo el diseño del
equipo utiliza un único reloj de 100 MHz; las temporizaciones lentas deben
usar habilitaciones, no relojes derivados.

## Diagramas generales

- [Primer nivel: sistema, entradas y salidas](nivel_1.md).
- [Segundo nivel: subsistemas e interconexiones](nivel_2.md).

Cada documento incluye objetivo, entradas, salidas y explicación de
funcionamiento siguiendo la guía de diseño modular. Los diagramas se presentan
en Mermaid dentro del Markdown, sin depender de una imagen externa.

## Contrato de datos acordado

| Dato | Ancho | Significado |
|---|---:|---|
| Carácter | 8 | ASCII A–Z |
| Palabra secreta / patrón | 96 | 12 posiciones de 8 bits |
| Longitud | 4 | 4–12 posiciones válidas |
| Letras utilizadas | 26 | bit 0=A, …, bit 25=Z |
| Índice de ROM | al menos 6 | Identifica una entrada del banco |
| Intentos restantes | 3 | 0–6 |
| Tiempo restante | 7 | Segundos; valores definitivos pendientes |
| Victorias | 7 | Contador; comportamiento al alcanzar 99 pendiente de definición |
| Dificultad | 1 | 0=FACIL, 1=DIFICIL |

## Flujo de partida y responsabilidades

S1 selecciona dificultad, solicita una palabra a S2 y espera `word_ready`.
Después inicializa tiempo e intentos y entrega a S2 las letras recibidas de S3
que correspondan a una partida activa. S2 identifica repetición y coincidencia,
actualiza todas las posiciones acertadas y comunica si la palabra está completa.
S1 aplica las reglas de derrota/victoria y mantiene el resultado al menos 3 s.
S4 presenta el estado y genera la retroalimentación sonora.

Los bytes inválidos se descartan sin modificar la partida. S1 no entrega letras
al motor en selección de modo ni durante el resultado final. La recepción UART
debe seguir siendo atendida para no dejar bytes antiguos pendientes.

## Detalle por subsistema

- [S2: tercer nivel e interfaces del motor](nivel_3_motor_del_juego.md).
- [S2: cuarto nivel y FSM del motor](nivel_4_motor_del_juego.md).
- [S3: UART y protocolo](../diseño/uart_protocolo.md).
- S1 y S4: documentación pendiente de integración.
