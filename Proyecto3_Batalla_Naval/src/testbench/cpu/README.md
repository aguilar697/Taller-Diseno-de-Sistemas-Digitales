# Verificación del CPU y la ROM

Cada módulo tiene un testbench autoverificable. Las pruebas finalizan con `PASS` cuando se cumplen las comprobaciones y con `$fatal` ante discrepancias o timeout. Los tiempos se expresan en nanosegundos; el reloj secuencial tiene período de 10 ns.

| Módulo | Testbench | Cobertura principal |
|---|---|---|
| alu | [alu_tb.sv](alu_tb.sv) | Diez operaciones, valores límite, signo y desplazamientos |
| immediate_generator | [immediate_generator_tb.sv](immediate_generator_tb.sv) | Formatos I/S/B completos; U/J con extremos y muestras |
| register_file | [register_file_tb.sv](register_file_tb.sv) | 32 índices, dos lecturas, x0, habilitación y reset |
| instruction_decoder | [instruction_decoder_tb.sv](instruction_decoder_tb.sv) | 131072 combinaciones opcode/funct3/funct7 y controles esperados |
| cpu_control | [cpu_control_tb.sv](cpu_control_tb.sv) | Transiciones, habilitaciones, FAULT y reset en diez estados |
| cpu_datapath | [cpu_datapath_tb.sv](cpu_datapath_tb.sv) | Registros, ALU, carga, STORE, alineación y retención del PC |
| program_rom | [program_rom_tb.sv](../memory/program_rom_tb.sv) | Inicialización, lectura síncrona, extremos del rango y rechazo de alias |
| cpu | [cpu_tb.sv](cpu_tb.sv) | Modelo arquitectónico, 29 operaciones, latencias, fallos, dependencias y reset |

## Fuentes y orden de compilación

`src/design/cpu/cpu_pkg.sv` precede a los módulos del núcleo. `cpu_tb_pkg.sv` precede a los testbenches que utilizan sus codificadores de instrucciones. Ambos archivos son paquetes; no son módulos de hardware ni tops de simulación.

El conjunto de simulación contiene los ocho módulos de diseño, los dos paquetes y los ocho testbenches. El top de simulación selecciona la prueba que se ejecuta; `cpu` es el top del núcleo para síntesis. `program_rom_tb.hex` es un archivo de datos exclusivo de la prueba de ROM y debe estar disponible en el directorio de ejecución de esa simulación. No es el programa de Batalla Naval.

## Ejecución en Vivado

La simulación se configura en un proyecto RTL de Vivado para el dispositivo `xc7a35tcpg236-1`. Los archivos del proyecto y los resultados generados se guardan fuera del repositorio.

Las fuentes de diseño pertenecen a **Design Sources**, los testbenches y `cpu_tb_pkg.sv` a **Simulation Sources**, y `program_rom_tb.hex` se incorpora como archivo de inicialización de memoria. El orden de compilación sitúa los paquetes antes de las fuentes que los utilizan.

Cada testbench se selecciona como top de simulación mediante **Set as Top** y se ejecuta con **Run Behavioral Simulation**. La opción **Run All** permite completar la prueba hasta `$finish`; el tiempo predeterminado de 1000 ns no alcanza para las pruebas más largas. El registro de ejecución conserva el mensaje final `PASS` o el diagnóstico de fallo.

Las señales de interés se incorporan a la ventana de ondas antes de la ejecución completa. El archivo `.wdb` contiene los datos de simulación y el `.wcfg` conserva la configuración de visualización.

## Señales para evidencia de ondas

| Prueba | Señales o sucesos representativos |
|---|---|
| ALU | a, b, op, y, expected; diferencia entre SRL/SRA y SLT/SLTU |
| Inmediatos | instruction, format, imm; desplazamientos de bits B/J y extensión de signo |
| Registros | clk, rst, we, rd, wd, rs1, rs2, a, b; x0 y escritura por flanco |
| Decoder | ins, legal, kind, op, asel, bs, wb; codificación válida e ilegal |
| Control | dut.state_q, ir, oper, exe, ld, pc, rf, access_mem, store, fault |
| Datapath | pa, da, wd, ins, execok; operandos, resultado, dato de carga y enlace internos |
| ROM | clk, addr, data; cambio después del flanco y direcciones límite |
| CPU | pa, pi, da, wd, di, we; dut.control.state_q, reference_pc y registros de destino |

En `cpu_tb`, el primer programa reúne los casos dirigidos; después se ejecuta una secuencia reproducible de operaciones y accesos a RAM, seguida de programas de fallo y reinicios. El modelo de referencia comprueba el estado arquitectónico en COMMIT, mientras que el modelo externo registra las escrituras en su flanco real. Esto permite detectar escrituras duplicadas aunque el valor final de RAM coincida.

Las aserciones funcionales no sustituyen las pruebas de integración con el bus, RAM, periféricos y ensamblador finales, ni el análisis temporal posterior al enrutamiento.
