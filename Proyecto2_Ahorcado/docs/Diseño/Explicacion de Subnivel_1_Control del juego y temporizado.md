# Proyecto 2 — Ahorcado FPGA–PC por UART

## Descripción general

Este proyecto implementa un juego de **Ahorcado** sobre una FPGA Basys 3, con comunicación hacia una computadora mediante UART. La idea principal es dividir el sistema en bloques bien definidos para que cada parte tenga una responsabilidad clara y pueda desarrollarse, probarse e integrarse de forma independiente.

El diseño utiliza un único reloj de **100 MHz** y se implementa en **SystemVerilog** dentro de Vivado. La arquitectura general se organiza en cuatro subsistemas principales:

1. **Control del juego y temporización**
2. **Word Engine**
3. **UART y protocolo**
4. **Interfaz local**

Cada subsistema cumple una función específica y se comunica con los demás mediante señales previamente definidas.

---

## 1. Control del juego y temporización

Este subsistema es el encargado de coordinar la partida completa. En términos simples, es el bloque que decide **qué debe pasar y en qué momento**.

Sus responsabilidades principales son:

- permitir la selección entre modo **FÁCIL** y **DIFÍCIL**;
- detectar la confirmación del modo seleccionado;
- solicitar al Word Engine una nueva palabra;
- iniciar la partida únicamente cuando la palabra ya está lista;
- recibir letras desde UART durante una partida activa;
- decidir cuándo una letra debe ser evaluada;
- llevar el control de los intentos restantes;
- administrar el tiempo disponible;
- detectar victoria;
- detectar derrota por intentos;
- detectar derrota por tiempo;
- mantener el resultado final visible durante al menos tres segundos;
- regresar automáticamente al modo de selección;
- llevar un contador acumulado de partidas ganadas.

Internamente, este subsistema se divide en varios bloques funcionales.

### Controlador principal

El controlador principal contiene la lógica que organiza el flujo del juego. Su función es decidir cuál es la etapa actual de la partida y qué acciones deben ejecutarse.

Por ejemplo, determina cuándo:

- se está seleccionando la dificultad;
- se debe pedir una nueva palabra;
- se está esperando una letra;
- una letra debe enviarse al Word Engine;
- se debe revisar el resultado de una letra;
- la partida terminó en victoria;
- la partida terminó por falta de intentos;
- la partida terminó por tiempo.

Este bloque es el que más adelante se implementa mediante la **máquina de estados finitos principal**.

### Datapath del juego

El datapath almacena la información que cambia durante el juego.

Entre los valores que conserva se encuentran:

- dificultad seleccionada;
- intentos restantes;
- número de victorias acumuladas;
- última letra recibida;
- longitud de la palabra actual.

El controlador no modifica directamente estos valores. En su lugar, genera órdenes para indicar cuándo deben cargarse, incrementarse, decrementarse o mantenerse.

Esta separación permite que la lógica de control y los datos del juego no estén mezclados en un único bloque.

### Temporización del juego

La parte de temporización se encarga de manejar dos tiempos diferentes.

El primero es el **temporizador regresivo de la partida**, que carga:

- **60 segundos** en modo fácil;
- **45 segundos** en modo difícil.

El segundo es el temporizador utilizado para mantener visible el resultado final durante al menos **3 segundos**.

Ambos trabajan con el reloj principal de 100 MHz y utilizan señales de habilitación, evitando crear relojes secundarios.

### Acondicionamiento de entradas

Los botones físicos de la Basys 3 no se utilizan directamente.

Este bloque se encarga de:

- sincronizar las entradas con el reloj;
- eliminar el rebote mecánico de los botones;
- generar pulsos limpios de un solo ciclo;
- producir un reset sincronizado para los bloques internos.

Las entradas físicas asociadas a este bloque son:

- `BTN_SEL`
- `BTN_OK`
- `BTN_RST`

---

## 2. Word Engine

El Word Engine es el subsistema encargado de manejar la palabra del juego.

Su responsabilidad no es controlar el flujo general de la partida, sino trabajar directamente con la palabra seleccionada.

Entre sus tareas se encuentran:

- seleccionar una nueva palabra;
- tomar en cuenta la dificultad indicada por el controlador;
- informar cuándo la palabra está lista;
- entregar la longitud de la palabra;
- evaluar cada letra recibida;
- indicar si una letra es correcta;
- indicar si una letra ya había sido utilizada;
- actualizar la representación visible de la palabra;
- indicar cuándo la palabra ha sido completada.

### Señales recibidas desde Control

El Word Engine recibe:

- `new_game`
- `difficulty`
- `letter_valid`
- `letter_ascii[7:0]`

### Señales enviadas hacia Control

El Word Engine entrega:

- `word_ready`
- `word_length[3:0]`
- `revealed_word[95:0]`
- `letter_correct`
- `letter_repeated`
- `word_complete`

Una parte importante del diseño es que el Control **no compara letras ni modifica directamente la palabra**. Esa responsabilidad pertenece por completo al Word Engine.

---

## 3. UART y protocolo

Este subsistema se encarga de la comunicación entre la FPGA y la computadora.

Por un lado, recibe los datos enviados desde el PC. Por otro, transmite información sobre el estado de la partida.

Desde el punto de vista del controlador, las señales más importantes recibidas son:

- `rx_letter_valid`
- `rx_letter[7:0]`

`rx_letter_valid` indica que se recibió una nueva letra válida desde la comunicación serial, mientras que `rx_letter[7:0]` contiene el valor ASCII recibido.

Durante la partida, el subsistema de control utiliza estas señales para decidir cuándo una letra puede ser aceptada.

En sentido contrario, el controlador entrega al subsistema UART información relacionada con:

- estado actual del juego;
- dificultad;
- palabra revelada;
- longitud de la palabra;
- intentos restantes;
- tiempo restante;
- número de victorias;
- eventos de acierto;
- eventos de error;
- fin de partida;
- resultado de victoria o derrota.

El subsistema UART utiliza esta información para construir y transmitir los mensajes correspondientes hacia la computadora.

Es importante remarcar que el bloque de Control **no genera directamente las tramas UART**. Su función es entregar los datos y eventos necesarios para que el subsistema UART se encargue de la comunicación.

---

## 4. Interfaz local

La interfaz local es la parte del sistema encargada de mostrar información directamente en la Basys 3 y generar realimentación al usuario.

Este subsistema recibe información desde el controlador y la utiliza para manejar los dispositivos disponibles.

Entre los elementos de salida considerados se encuentran:

- LCD;
- displays de siete segmentos;
- LED;
- buzzer.

La interfaz local puede utilizar información como:

- estado actual del juego;
- dificultad seleccionada;
- palabra revelada;
- intentos restantes;
- tiempo restante;
- contador de victorias;
- eventos de letra correcta;
- eventos de letra incorrecta;
- resultado final.

El controlador no genera directamente los patrones del LCD, los segmentos o los tonos del buzzer. Solamente entrega información de estado y eventos; la interfaz local decide cómo representarlos físicamente.

---

## Relación entre los subsistemas

La arquitectura busca que cada bloque tenga una responsabilidad bien definida.

El flujo general puede entenderse así:

1. El usuario selecciona la dificultad mediante los botones.
2. El subsistema de Control confirma la selección y solicita una nueva palabra.
3. El Word Engine prepara la palabra y avisa cuando está lista.
4. El Control inicia los intentos y el temporizador.
5. La computadora envía letras mediante UART.
6. El Control acepta una letra y la envía al Word Engine.
7. El Word Engine evalúa la letra y devuelve el resultado.
8. El Control actualiza intentos, tiempo y estado de la partida.
9. UART e Interfaz Local muestran el progreso al usuario.
10. Si se completa la palabra, se registra una victoria.
11. Si se terminan los intentos o el tiempo llega a cero, se registra una derrota.
12. El resultado permanece visible durante al menos tres segundos.
13. Finalmente, el sistema regresa automáticamente a la selección de dificultad.

---

## Decisiones generales de diseño

El proyecto se organiza siguiendo una estructura jerárquica y modular.

Se utiliza:

- un único reloj de **100 MHz**;
- SystemVerilog sintetizable;
- separación entre lógica de control y almacenamiento de datos;
- temporizadores mediante **clock enable**;
- señales sincronizadas;
- módulos independientes;
- testbenches para verificar cada bloque antes de la integración completa.

La intención es que cada subsistema pueda desarrollarse y probarse de forma independiente, pero manteniendo interfaces claras para facilitar la integración final en Vivado.

---

## Enfoque del Subsistema 1

Dentro del trabajo asignado, el enfoque principal está en **Control del juego y temporización**.

Por esa razón, el desarrollo asociado a este subsistema incluye:

- definición de la FSM principal;
- selección de dificultad;
- manejo de botones;
- control de tiempo;
- control de intentos;
- detección de victoria y derrota;
- retención del resultado final;
- contador acumulado de victorias;
- coordinación con Word Engine;
- coordinación con UART;
- coordinación con la interfaz local;
- implementación de módulos en SystemVerilog;
- creación de testbenches;
- integración final en Vivado.

Los demás subsistemas se consideran interfaces externas al bloque de Control, aunque su comportamiento debe conocerse lo suficiente para definir correctamente las señales de comunicación.
