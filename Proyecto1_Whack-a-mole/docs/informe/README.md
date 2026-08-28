# Informe técnico – Proyecto 1: Whack-a-Mole híbrido FPGA / lógica discreta

## 1. Introducción

En este proyecto se desarrolló una versión del juego Whack-a-Mole mediante una arquitectura híbrida compuesta por un subsistema de lógica discreta y un subsistema implementado en FPGA.

El circuito discreto se encarga de generar de forma pseudoaleatoria la posición activa del topo y transmitirla a la FPGA mediante comunicación serial UART. La FPGA se encarga del control general del juego, incluyendo la recepción de la posición, temporización de cada turno, procesamiento de botones, conteo de aciertos y fallos, control de dificultad, fin de partida y visualización de resultados.

La comunicación entre ambos subsistemas se realiza utilizando referencias de tiempo independientes, por lo que fue necesario implementar mecanismos de sincronización y recepción serial confiables.

---

## 2. Objetivos

### 2.1 Objetivo general

Implementar un sistema digital híbrido capaz de ejecutar el funcionamiento del juego Whack-a-Mole mediante lógica discreta y una FPGA Basys 3.

### 2.2 Objetivos específicos

- Generar una posición pseudoaleatoria entre las posiciones disponibles del juego.
- Transmitir la posición generada desde el circuito discreto hacia la FPGA mediante UART.
- Implementar en FPGA la lógica de control de cada turno.
- Detectar aciertos, fallos y expiración del tiempo disponible.
- Implementar una dificultad progresiva reduciendo la ventana de tiempo después de cada acierto.
- Registrar y mostrar los aciertos y fallos acumulados.
- Finalizar la partida después de tres fallos consecutivos.
- Verificar el comportamiento del diseño mediante simulaciones e implementación física.

---

## 3. Fundamentación teórica

### 3.1 Diseño digital modular

El diseño modular consiste en dividir un sistema complejo en bloques funcionales independientes que pueden diseñarse, verificarse e integrarse progresivamente.

Esta metodología facilita la identificación de errores, la reutilización de módulos y la comprensión del funcionamiento general del sistema.

En este proyecto se empleó una estructura jerárquica de diseño, desde la representación global del sistema hasta la descripción específica de los módulos implementados.

### 3.2 FPGA

Una FPGA (*Field Programmable Gate Array*) es un circuito integrado reconfigurable que permite implementar sistemas digitales utilizando recursos internos como LUTs, flip-flops, multiplexores, bloques de memoria y redes de interconexión programables.

Para este proyecto se utilizó una tarjeta Basys 3 basada en una FPGA Xilinx Artix-7.

La FPGA funciona con un reloj principal de 100 MHz y ejecuta toda la lógica de control del juego.

### 3.3 Máquinas de estados finitos

Una máquina de estados finitos o FSM (*Finite State Machine*) permite controlar sistemas cuyo comportamiento depende de su estado actual y de las entradas recibidas.

En este proyecto la FSM coordina las principales etapas del juego:

- reinicio;
- solicitud de una nueva posición;
- espera de respuesta UART;
- turno activo;
- evaluación del resultado;
- revisión de fallos consecutivos;
- estado de fin de partida.

### 3.4 Comunicación UART

UART es un protocolo de comunicación serial asíncrono en el cual transmisor y receptor no comparten una señal de reloj.

La comunicación empleada en este proyecto utiliza formato 8N1:

- 1 bit de inicio;
- 8 bits de datos;
- sin bit de paridad;
- 1 bit de parada.

La tasa nominal seleccionada fue de 9600 baud.

Durante las mediciones realizadas al circuito discreto se obtuvo una tasa aproximada de 9616 baud, correspondiente a una diferencia de aproximadamente 0.17 % respecto al valor nominal.

### 3.5 Sincronización de señales asíncronas

La señal serial proveniente del circuito discreto pertenece a un dominio temporal independiente del reloj de la FPGA.

Por esta razón, antes de ser procesada se utiliza un sincronizador de dos flip-flops.

Esta estructura reduce la probabilidad de que un estado metaestable producido al muestrear una señal asíncrona se propague hacia la lógica interna del sistema.

### 3.6 Clock Enable

Todo el diseño FPGA utiliza únicamente el reloj principal de 100 MHz.

Para implementar eventos de menor frecuencia se utiliza una señal de habilitación temporal de 1 ms generada mediante un contador.

Esta señal no constituye un nuevo reloj, sino un *clock enable*, lo cual permite mantener el sistema dentro de un único dominio de reloj.

### 3.7 Debounce de botones

Los pulsadores mecánicos pueden producir varias transiciones durante una única pulsación debido al rebote de sus contactos.

Para evitar que una pulsación sea interpretada como múltiples eventos, las entradas de los botones son sincronizadas, filtradas mediante *debounce* y posteriormente procesadas mediante detección de flanco.

---

## 4. Implementación del sistema

### 4.1 Arquitectura general

El sistema se divide en dos subsistemas principales:

- subsistema de lógica discreta;
- subsistema FPGA.

El subsistema discreto genera la posición del topo, la muestra mediante LEDs y transmite la información hacia la FPGA.

La FPGA recibe dicha posición y ejecuta toda la lógica correspondiente al control de la partida.

![Arquitectura general del sistema](img/01_arquitectura_general.png)

**Figura 1.** Arquitectura general del sistema híbrido Whack-a-Mole.

### 4.2 Subsistema FPGA

El subsistema FPGA se compone de los siguientes bloques funcionales:

- acondicionamiento y sincronización de botones;
- generador de base de tiempo;
- receptor UART;
- máquina de estados principal;
- evaluador de golpes;
- controlador de dificultad;
- temporizador de turno;
- contadores de aciertos y fallos;
- temporizador de GAME OVER;
- controlador de displays de siete segmentos.

Todos estos bloques utilizan como referencia el reloj principal de 100 MHz.

![Diagrama de tercer nivel del subsistema FPGA](img/02_diagrama_nivel_3_fpga.png)

**Figura 2.** Diagrama de tercer nivel del subsistema FPGA.

El diseño del subsistema FPGA se desarrolló además hasta un cuarto nivel de detalle. En este nivel se representa de forma más específica la relación entre los módulos internos, las señales de control, los registros principales y las interfaces externas utilizadas durante el funcionamiento del juego.

En el diagrama se incluyen, entre otros, el acondicionamiento de los ocho botones, el generador de `tick_1ms`, el receptor UART, la FSM principal, el evaluador de golpes, el controlador de dificultad, el temporizador de turno, los contadores de puntaje, el temporizador de GAME OVER y el controlador de displays de siete segmentos.

![Diagrama de cuarto nivel del subsistema FPGA](img/10_diagrama_nivel_4_fpga.png)

**Figura 3.** Diagrama de cuarto nivel del subsistema FPGA.

### 4.3 Subsistema discreto

El subsistema discreto se encarga de generar las posiciones utilizadas durante el juego.

Entre sus principales bloques se encuentran:

- oscilador;
- lógica de control de solicitud;
- generador pseudoaleatorio;
- decodificador para indicación mediante LEDs;
- sistema de transmisión serial.

El subsistema responde a la señal `mole_request` generada por la FPGA y posteriormente transmite la posición mediante `serial_data`.

![Diagrama de tercer nivel del subsistema discreto](img/03_diagrama_nivel_3_discreto.png)

**Figura 4.** Diagrama de tercer nivel del subsistema de lógica discreta.

---

## 5. Resultados

### 5.1 Simulación del receptor UART

El receptor UART fue verificado mediante simulación antes de realizar la integración completa del sistema.

Las pruebas permitieron comprobar la recepción de diferentes valores enviados mediante una trama 8N1 y verificar que la señal `data_valid` se genera al recibir correctamente un byte.

Para el funcionamiento del juego, únicamente los tres bits menos significativos del byte recibido, `data[2:0]`, son utilizados para representar la posición del topo.

![Simulación del receptor UART](img/04_simulacion_uart_rx.png)

**Figura 5.** Verificación funcional del receptor UART mediante simulación.

### 5.2 Simulación de integración y respuesta UART temprana

Durante las primeras pruebas físicas se detectó una condición de integración que no había sido reproducida inicialmente en el testbench.

El circuito discreto era capaz de transmitir y finalizar la trama UART mientras la señal `mole_request` de la FPGA todavía permanecía activa.

El receptor UART procesaba correctamente el byte; sin embargo, `data_valid` tiene una duración de solamente un ciclo del reloj de 100 MHz. Debido a esto, la indicación podía producirse mientras la FSM todavía permanecía en el estado `S_REQUEST`.

Cuando posteriormente la FSM entraba en `S_WAIT_UART`, el pulso de `data_valid` ya había desaparecido.

Para corregir esta condición se incorporaron las señales internas:

- `uart_pending`;
- `pending_position`.

Si una respuesta se recibe durante `S_REQUEST`, la posición queda almacenada temporalmente. Al terminar el período de solicitud, la FSM utiliza dicha posición y continúa directamente hacia el turno activo.

Se implementó posteriormente un testbench específico para reproducir esta condición.

La prueba verificó que:

- la trama UART finalizaba mientras `mole_request` continuaba activo;
- la posición recibida era almacenada correctamente;
- la FSM iniciaba posteriormente el turno;
- los siguientes turnos podían ejecutarse con normalidad.

![Simulación de respuesta UART temprana](img/05_simulacion_uart_temprana.png)

**Figura 6.** Simulación específica de la recepción UART mientras `mole_request` continúa activo.

### 5.3 Medición experimental de la comunicación UART

La comunicación entre el circuito discreto y la FPGA también fue analizada mediante osciloscopio.

Se observó una duración aproximada de:

- 104 µs por bit;
- aproximadamente 1.04 ms para una trama completa de 10 bits.

A partir de la medición realizada se obtuvo una velocidad de transmisión aproximada de:

\[
Baud \approx 9616
\]

La diferencia respecto al valor nominal de 9600 baud es:

\[
Error =
\frac{9616-9600}{9600}
\times 100
\approx 0.17\%
\]

La diferencia observada fue suficientemente pequeña para mantener una comunicación estable entre ambos subsistemas.

En la medición también se verificó que la trama UART podía completarse antes de finalizar el pulso de `mole_request`, confirmando experimentalmente la condición temporal identificada durante la integración.

![Medición de UART en osciloscopio](img/06_osciloscopio_uart.png)

**Figura 7.** Medición experimental de la comunicación UART entre el circuito discreto y la FPGA.

### 5.4 Síntesis e implementación FPGA

El diseño completo fue sintetizado e implementado utilizando Vivado.

Los resultados obtenidos mostraron una utilización reducida de los recursos disponibles en la FPGA.

| Recurso | Utilización |
|---|---:|
| LUT | 208 |
| Registros | 203 |
| Slices | 88 |
| IOB | 24 |
| BUFGCTRL | 1 |

La utilización de LUTs representa aproximadamente un 1 % de los recursos disponibles del dispositivo.

Esto indica que la implementación del sistema requiere solamente una pequeña fracción de la capacidad lógica disponible en la FPGA utilizada.

### 5.5 Análisis temporal y DRC

Después de la implementación se realizó el análisis de temporización del diseño.

Los resultados obtenidos fueron:

| Parámetro | Resultado |
|---|---:|
| WNS | +4.421 ns |
| TNS | 0 ns |
| WHS | +0.129 ns |
| THS | 0 ns |
| WPWS | +4.500 ns |

Los valores positivos de WNS y WHS indican que no se presentaron violaciones de *setup* ni de *hold* en las restricciones temporales utilizadas.

Asimismo, la verificación DRC posterior a la implementación no reportó violaciones.

![Resultados de timing y DRC](img/07_timing_y_drc.png)

**Figura 8.** Resultados posteriores a la implementación: análisis temporal y verificación DRC.

### 5.6 Verificación mediante linter

También se utilizó el linter de Vivado para verificar posibles problemas estructurales del código RTL.

No se identificaron problemas que impidieran la síntesis o implementación del sistema.

Se presentó una advertencia asociada al uso de únicamente los tres bits menos significativos del byte recibido por UART.

Este comportamiento es intencional, debido a que solamente `data[2:0]` se utiliza para codificar las posiciones disponibles del topo.

### 5.7 Estimación de potencia

Vivado realizó una estimación del consumo de potencia del diseño implementado.

Los valores obtenidos fueron aproximadamente:

| Componente | Potencia |
|---|---:|
| Potencia dinámica | 0.018 W |
| Potencia estática | 0.072 W |
| Potencia total | 0.089 W |

La herramienta indicó un nivel de confianza bajo en la estimación, por lo cual estos resultados se utilizan principalmente como referencia del orden de magnitud del consumo esperado.

![Estimación de potencia](img/08_reporte_potencia.png)

**Figura 9.** Estimación de potencia del diseño implementado en la FPGA.

### 5.8 Implementación física

Después de completar la síntesis e implementación se generó el bitstream correspondiente y se programó la tarjeta Basys 3.

Durante las pruebas físicas se verificó la interacción entre el circuito discreto y la FPGA, incluyendo:

- generación de `mole_request`;
- transmisión de la posición mediante UART;
- recepción de la posición en la FPGA;
- procesamiento de botones;
- detección de aciertos y fallos;
- actualización de los contadores;
- generación de nuevas solicitudes;
- funcionamiento del estado GAME OVER;
- reinicio del juego;
- visualización mediante displays de siete segmentos.

![Implementación física en Basys 3](img/09_implementacion_fisica_basys3.png)

**Figura 10.** Implementación y verificación física del subsistema FPGA en la tarjeta Basys 3.

---

## 6. Análisis e interpretación de resultados

Los resultados obtenidos muestran la importancia de realizar la verificación del sistema en diferentes niveles.

Inicialmente se verificaron individualmente los diferentes módulos implementados en FPGA. Esto permitió comprobar de forma aislada el funcionamiento del receptor UART, acondicionamiento de botones, temporizadores, contadores, control de dificultad, evaluación de golpes, visualización y FSM.

Posteriormente, las pruebas de integración permitieron evaluar la interacción entre los módulos.

A pesar de que las simulaciones iniciales mostraban un funcionamiento correcto, durante la integración física apareció una condición temporal que no había sido considerada en el testbench original.

El circuito discreto podía completar la transmisión UART antes de que finalizara la señal `mole_request`. Como consecuencia, `data_valid` se generaba mientras la FSM todavía se encontraba en `S_REQUEST`.

Este problema permitió identificar una diferencia importante entre una simulación funcional y las condiciones temporales reales de integración.

La solución implementada mediante `uart_pending` y `pending_position` permitió desacoplar temporalmente la recepción del byte UART de la transición de estado de la FSM. De esta forma se conserva la respuesta recibida aunque esta llegue antes de entrar en `S_WAIT_UART`.

La medición experimental de aproximadamente 9616 baud también permitió comparar la implementación física del transmisor con los 9600 baud nominales configurados en la FPGA.

La diferencia aproximada de 0.17 % no produjo errores de recepción, demostrando que ambos subsistemas podían comunicarse correctamente aun sin compartir una referencia de reloj.

Por otra parte, el análisis temporal posterior a la implementación presentó márgenes positivos tanto para *setup* como para *hold*, indicando que el diseño cumple con las restricciones temporales establecidas para el reloj de 100 MHz.

La utilización reducida de LUTs y registros muestra además que la implementación ocupa una pequeña fracción de los recursos disponibles en la FPGA Artix-7 utilizada.

Finalmente, las pruebas físicas permitieron complementar la verificación realizada mediante simulación y comprobar el funcionamiento del sistema completo bajo las condiciones reales de interacción entre la FPGA, el circuito discreto y las entradas del usuario.

---

## 7. Problemas encontrados y correcciones

### 7.1 Pérdida de respuesta UART durante `mole_request`

Durante las pruebas físicas se observó que un primer turno podía completarse correctamente, pero posteriormente el sistema podía quedar esperando una nueva respuesta aun cuando el circuito discreto sí había realizado la transmisión.

Utilizando el osciloscopio se verificó que el problema no estaba relacionado con la ausencia de una trama UART.

La causa se encontraba en la relación temporal entre la transmisión y la FSM.

La trama podía finalizar mientras `mole_request` permanecía activo y, por tanto, `data_valid` podía producirse antes de que la FSM llegara a `S_WAIT_UART`.

La solución consistió en almacenar cualquier posición recibida durante `S_REQUEST`.

Para ello se incorporaron:

- `uart_pending`, utilizado para indicar que existe una respuesta almacenada;
- `pending_position`, utilizado para conservar `data[2:0]`.

Al terminar `S_REQUEST`, la FSM revisa si existe una respuesta pendiente y, de ser así, utiliza dicha posición e inicia el turno sin esperar una nueva transmisión.

Posteriormente se diseñó una simulación específica para reproducir esta situación y se verificó que la corrección funcionaba correctamente.

### 7.2 Correspondencia de los displays de siete segmentos

Durante las pruebas también se identificó una diferencia entre la correspondencia lógica de las señales `seg[6:0]` y la asignación física de los segmentos de la tarjeta Basys 3.

Esta condición provocaba que determinados valores no se visualizaran correctamente.

Se revisó la asignación de pines del archivo de *constraints* y se corrigió la correspondencia de los segmentos para obtener la representación numérica esperada.

---

## 8. Conclusiones

El proyecto permitió implementar un sistema digital híbrido en el cual lógica discreta y FPGA trabajan conjuntamente mediante una interfaz de comunicación serial.

La metodología modular facilitó el desarrollo y la verificación de cada bloque antes de la integración completa del sistema.

La comunicación UART permitió transferir correctamente la posición generada por el circuito discreto hacia la FPGA a pesar de que ambos subsistemas utilizan referencias temporales independientes.

Las mediciones experimentales mostraron una velocidad aproximada de 9616 baud frente a los 9600 baud nominales, presentando una diferencia cercana al 0.17 % que no afectó el funcionamiento de la comunicación.

Las pruebas físicas fueron fundamentales para detectar una condición temporal relacionada con la llegada de `data_valid` durante `S_REQUEST`, la cual no había sido considerada inicialmente en la simulación de integración.

La incorporación de almacenamiento temporal mediante `uart_pending` y `pending_position` permitió solucionar este comportamiento y mantener la duración definida para `mole_request`.

Los resultados de implementación mostraron además una baja utilización de recursos de la FPGA y márgenes temporales positivos, confirmando que la arquitectura implementada puede operar correctamente con el reloj principal de 100 MHz.

Finalmente, el proyecto permitió comprobar que la simulación, síntesis y análisis temporal son etapas fundamentales del diseño digital, pero deben complementarse con pruebas físicas para identificar condiciones que solamente aparecen durante la interacción real entre diferentes subsistemas.

---

## 9. Referencias

- Instructivo del Proyecto 1: Whack-a-Mole, EL3313 Taller de Diseño Digital.
- Material del curso EL3313 Taller de Diseño Digital.
- Documentación de AMD/Xilinx Vivado.
- Manual de referencia de la tarjeta Basys 3.