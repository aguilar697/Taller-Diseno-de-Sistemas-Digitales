# Proyecto 3 — Batalla Naval

Juego de Batalla Naval para dos jugadores, ejecutado por un procesador RISC-V de 32 bits en una FPGA Basys 3. El Jugador 1 utiliza un monitor VGA y los controles de la tarjeta; el Jugador 2 utiliza una terminal de PC conectada por UART.

El programa ensamblador administra tableros de 8 × 8 casillas, flotas de tres barcos, colocación, turnos, disparos y victoria. La CPU, las memorias y los periféricos proporcionan los recursos necesarios para ejecutarlo. El diseño utiliza un reloj principal de 100 MHz, video de 640 × 480 a 60 Hz nominales y comunicación UART a 115200 baud.

## Documentación

| Documento | Contenido |
|---|---|
| [Diseño del sistema](docs/diseno/README.md) | Diagramas de niveles 1–4, interfaces y decisiones de arquitectura |
| [Informe técnico](docs/informe/informe_general.md) | Objetivos, metodología, resultados, análisis y conclusiones |
| [Fundamentación teórica](docs/informe/fundamentacion_teorica.md) | RISC-V, MMIO, VGA, entradas y comunicación serial |
| [Plan de verificación](docs/diseno/estrategia_implementacion_verificacion.md) | Requisitos, pruebas y criterios de aceptación |
| [Informes por subsistema](docs/informe/README.md) | Análisis detallado y evidencias de CPU, VGA, MMIO e integración |
| [Instalación y uso](docs/uso_basys3.md) | Proyecto Vivado, simulación, programación de la tarjeta y controles del juego |
| [Protocolo UART](docs/diseno/protocolo_uart_batalla_naval.md) | Mensajes intercambiados entre la FPGA y la terminal |

## Requisitos

- Vivado con soporte para Artix-7 `xc7a35tcpg236-1`. Las pruebas documentadas se realizaron con Vivado/XSim 2026.1.
- Python 3.10 o posterior y `pyserial` para la terminal.
- Basys 3, cable USB, monitor VGA y buzzer conectado a JA1.

## Instalación, compilación y ejecución

Desde la raíz del repositorio, entrar en la carpeta del proyecto e instalar la dependencia de la terminal:

```powershell
cd Proyecto3_Batalla_Naval
python -m pip install -r src/software_pc/requirements.txt
```

Comprobar la imagen de programa y ejecutar las pruebas:

```powershell
python scripts/ensamblar_programa.py --check
python -m unittest discover -s src/software_pc -v
python -m unittest discover -s scripts -p "test_*.py" -v
python scripts/verificar_sistema_completo.py --all
python scripts/verificar_partida_j2.py
```

Crear el proyecto para trabajar desde Vivado:

```powershell
python scripts/implementar_basys3.py --project-only
```

El comando muestra la ruta del archivo `.xpr`. Para ejecutar también síntesis, implementación y generación de bitstream, utilizar el mismo comando sin `--project-only`. Los scripts buscan Vivado en `PATH` y en sus directorios habituales; `--vivado-bin` permite indicar otra instalación.

Después de programar la tarjeta desde **Hardware Manager**, abrir la terminal, sustituyendo `COM6` por el puerto correspondiente:

```powershell
python src/software_pc/naval_terminal.py COM6
```

Con la terminal abierta, subir SW15 para iniciar el sistema. Los pulsadores direccionales mueven el cursor; SW0 cambia la orientación y SW1 confirma. Ambos switches deben volver a cero entre acciones. BTNC inicia otra partida conservando el marcador. La [guía de uso](docs/uso_basys3.md) describe las conexiones y el procedimiento completo.

## Organización

| Carpeta | Contenido |
|---|---|
| `docs/diseno/` | Arquitectura, diagramas e interfaces |
| `docs/informe/` | Informe técnico, análisis por subsistema y evidencias |
| `src/design/` | Módulos RTL e IP de reloj |
| `src/testbench/` | Pruebas unitarias y de integración |
| `src/constraints/` | Restricciones de reloj y asignación de pines |
| `src/software_riscv/` | Programa ensamblador e imagen de ROM |
| `src/software_pc/` | Terminal del Jugador 2 y pruebas Python |
| `scripts/` | Ensamblado, simulación y creación del proyecto Vivado |

Los scripts generan sus resultados en `build/`, carpeta excluida de Git que se crea al ejecutar las herramientas. Las evidencias que acompañan al informe se conservan en `docs/informe/resultados/`.

## Pruebas y resultados

El proyecto incluye pruebas unitarias y de integración para la CPU, las memorias, los periféricos y el programa del juego. La verificación comprende 34 testbenches RTL, 31 pruebas de la terminal y cinco del ensamblador. Las partidas simuladas comprueban la victoria de ambos jugadores, los mensajes UART, el estado de RAM y el marcador. Una prueba con error deliberado comprueba que el banco general identifica el fallo y detiene la ejecución.

La implementación de `basys3_top` ocupa 1812 LUT, 1692 flip-flops y cuatro bloques RAM de 36 Kb. El análisis temporal registra WNS de 0,219 ns y WHS de 0,122 ns bajo las restricciones aplicadas. Los resultados, sus condiciones y el alcance experimental se presentan en el [informe técnico](docs/informe/informe_general.md).

## Integrantes

| Responsable | Subsistema |
|---|---|
| Kevin Aguilar | CPU RISC-V y ROM |
| Kenneth Campos | VGA y entradas del Jugador 1 |
| Daniel Puentes | Plataforma de datos, comunicación y periféricos MMIO; terminal de PC |
| Kevin Cortés | Programa del juego en ensamblador |

[Repositorio del curso](../README.md)
