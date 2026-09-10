# Proyecto 2 — Ahorcado

EL3313 Taller de Diseño Digital · II Semestre 2026 · Grupo 3.

Juego con control en FPGA Basys 3 y terminal remota Python por UART a
115200 baud. La FPGA selecciona la palabra, evalúa letras, controla el tiempo
y los intentos y determina el resultado. La PC recibe entradas y presenta el
estado enviado por la FPGA.

## Documentación

- [Planteamiento y arquitectura del sistema](docs/diseno/README.md).
- [Motor del juego — diseño de Kevin Aguilar](docs/diseno/motor_del_juego.md).
- [Revisión de diagramas y acuerdos pendientes](docs/diseno/revision_diagramas.md).
- [Comunicación UART y protocolo — Daniel Puentes](docs/diseño/uart_protocolo.md).

## Responsabilidades

| Subsistema | Responsable | Función |
|---|---|---|
| 1. Control y temporización | Kenneth Campos | FSM de partida, botones, dificultad, tiempo, intentos y victorias |
| 2. Motor del juego | Kevin Aguilar | ROM, LFSR, selección, letras utilizadas y patrón revelado |
| 3. UART, protocolo y Python | Daniel Puentes | Comunicación serial, registros y terminal remota |
| 4. Interfaz local | Kevin Cortés | LCD, siete segmentos, LED y buzzer |

Los archivos de otras ramas no se consideran integrados por el solo hecho de
existir en GitHub. La documentación y las pruebas de cada entrega deben
corresponder al contenido de la rama revisada.

## Organización

```text
docs/diseno/              Arquitectura general, motor y revisión de diagramas
docs/diseño/              Documentación UART existente
src/design/uart/cod/      UART de trabajo y protocolo
src/design/uart/Codigo administrado UART/  Núcleo original proporcionado
src/testbench/uart/       Pruebas del subsistema de comunicación
src/design/word_engine/   Motor, ROM, LFSR, evaluador y banco ASCII
src/testbench/word_engine/ Pruebas autoverificables del motor
scripts/                 Generación de ROM, simulación y síntesis del motor
docs/informe/            Evidencia de verificación del motor
```

Por ahora se conservan las dos carpetas de documentación para no romper los
enlaces de los compañeros. Su unificación debe realizarse en una revisión
conjunta de rutas y referencias.

## Requisitos de entrega

- Diseño e informe en Markdown, con diagramas, interfaces y decisiones justificadas.
- ROM de al menos 50 palabras distintas, de 4–12 letras A–Z.
- Fácil: cualquier palabra; difícil: solo longitudes de 6 o más.
- Seis letras incorrectas como máximo; repetidas sin penalización.
- Temporizador, resultado final durante al menos 3 s y regreso a selección.
- Pruebas autoverificables y evidencia en hardware.
- Simulación temporizada post-implementación de recepción y validación de una letra.

60 s y 45 s son sugerencias del instructivo, no valores confirmados aquí.
La presentación funcional requiere el visto bueno previo del diseño.

## Flujo de trabajo

Trabajar en la rama personal, actualizar desde `origin/main`, registrar avances
reales con commits descriptivos y subir la rama. Abrir un Pull Request hacia
`main` y solicitar revisión de otro integrante antes de integrar. Usar issues
asignados para diseño, implementación, pruebas y problemas de integración.

No hay todavía instrucciones de ejecución del sistema completo: deben añadirse
cuando el top, los constraints y la terminal Python estén integrados y probados.

## Verificar el motor del juego

Desde la raíz del repositorio, con Python 3 e Icarus Verilog instalados:

```text
python Proyecto2_Ahorcado/scripts/test_word_engine.py
```

El script detecta Icarus en PATH o en `C:/iverilog/bin`. Acepta `--icarus-bin`
para otra instalación. Comprueba la ROM, compila los cuatro módulos y ejecuta
el testbench con resultados PASS/FAIL. Los archivos generados quedan en
`Proyecto2_Ahorcado/build/word_engine/`.

Para síntesis independiente, desde la raíz del repositorio:

```text
python Proyecto2_Ahorcado/scripts/synth_word_engine.py
```

[Resultados y límites de esta verificación](docs/informe/motor_verificacion.md).

El script acepta `--vivado` con la ruta del ejecutable. Utiliza una copia
temporal para aislar la síntesis de las rutas de OneDrive y guarda los reportes
en `build/word_engine/`. El Tcl también puede ejecutarse directamente desde Vivado.
