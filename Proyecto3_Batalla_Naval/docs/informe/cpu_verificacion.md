# Verificación del procesador y la ROM

## Alcance

La verificación del subsistema CPU/ROM se organiza mediante testbenches autoverificables por módulo y una prueba integrada del procesador. Las pruebas secuenciales utilizan un reloj de 10 ns y reset síncrono activo alto.

La prueba del núcleo incluye la ROM de programa y un modelo síncrono de RAM y registros externos. No incluye el bus, VGA, UART ni el programa final de Batalla Naval. La metodología y las fuentes se describen en [Verificación del CPU y la ROM](../../src/testbench/cpu/README.md).

## Entorno de simulación

| Dato | Registro |
|---|---|
| Versión de Vivado | 2026.1 (Vivado Simulator / XSim) |
| Fecha de ejecución | 28 de septiembre de 2026 |
| Dispositivo del proyecto | xc7a35tcpg236-1 |

## Resultados funcionales

| Testbench | Aspecto evaluado | Resultado observado |
|---|---|---|
| alu_tb | Aritmética, lógica, comparaciones y desplazamientos | PASS; 3296 comprobaciones; finalización a 3296 ns |
| immediate_generator_tb | Formatos de inmediato y extensión de signo | PASS; 14298 comprobaciones; finalización a 14298 ns |
| register_file_tb | Lecturas, escritura, x0, habilitación y reset | PASS; 256 lecturas y prioridad de reset; finalización a 832 ns |
| instruction_decoder_tb | Decodificación y rechazo de instrucciones no soportadas | PASS; 131072 codificaciones; finalización a 131072 ns |
| cpu_control_tb | Estados, transiciones, habilitaciones y reset | **EN PROCESO** |
| cpu_datapath_tb | Rutas de datos, registros intermedios y alineación | **EN PROCESO** |
| program_rom_tb | Inicialización, lectura síncrona y límites de dirección | **EN PROCESO** |
| cpu_tb | Ejecución de programas, estado arquitectónico, accesos y latencias | **EN PROCESO** |

### Registros de ejecución

- [Registro de simulación de la ALU](resultados/cpu/alu_simulacion.txt).
- [Registro de simulación del generador de inmediatos](resultados/cpu/inmediatos_simulacion.txt).
- [Registro de simulación del banco de registros](resultados/cpu/registros_simulacion.txt).
- [Registro de simulación del decodificador](resultados/cpu/decoder_simulacion.txt).

## Capturas de ondas de Vivado

### ALU

#### Suma y resta

![Simulación de ADD](resultados/cpu/alu_add.png)

**Figura 1.** Casos dirigidos de ADD (`op=0`, intervalo de 0 a 6 ns). El resultado `y` coincide con `expected`. La suma `FFFFFFFF + 00000001` produce `00000000`, conservando los 32 bits inferiores.

![Simulación de SUB](resultados/cpu/alu_sub.png)

**Figura 2.** Casos dirigidos de SUB (`op=1`, intervalo de 206 a 212 ns). Se observan, entre otros, `80000000 - 7FFFFFFF = 00000001` y `12345678 - 00000020 = 12345658`, con coincidencia entre resultado y referencia.

#### Desplazamientos a la derecha

![Simulación de SRL](resultados/cpu/alu_srl.png)

**Figura 3.** Desplazamiento lógico SRL (`op=6`, intervalo de 1236 a 1242 ns). El operando `80000000` desplazado 31 posiciones produce `00000001`. La cantidad se obtiene de `b[4:0]`: un valor de 32 equivale a un desplazamiento efectivo de cero.

![Simulación de SRA](resultados/cpu/alu_sra.png)

**Figura 4.** Desplazamiento aritmético SRA (`op=7`, intervalo de 1442 a 1448 ns). Para `80000000` y una cantidad de 31 posiciones, el resultado es `FFFFFFFF` por extensión del signo. El mismo desplazamiento aplicado a `7FFFFFFF` produce cero.

#### Comparaciones

![Simulación de SLT](resultados/cpu/alu_slt.png)

**Figura 5.** Comparación con signo SLT (`op=8`, intervalo de 1648 a 1654 ns). `FFFFFFFF` representa -1 y resulta menor que `00000001`; la salida es `00000001`. El resultado coincide con la referencia.

![Simulación de SLTU](resultados/cpu/alu_sltu.png)

**Figura 6.** Comparación sin signo SLTU (`op=9`, intervalo de 1854 a 1860 ns). `FFFFFFFF` resulta mayor que `00000001`, por lo que la salida es cero. Para `7FFFFFFF < FFFFFFFF`, la salida es `00000001`. Estos casos distinguen SLTU de la comparación con signo.

### Generación de inmediatos

![Simulación de inmediatos I y S](resultados/cpu/inmediatos_i_s.png)

**Figura 7.** Formatos I (`format=0`) y S (`format=1`) entre 4092 y 4104 ns. Aunque cambia la distribución de bits en `instruction`, ambos formatos reconstruyen los valores -2, -1, 0, 1, 2 y 3. Los valores negativos se extienden con signo hasta 32 bits.

![Simulación de inmediatos B](resultados/cpu/inmediatos_b.png)

**Figura 8.** Formato B (`format=2`) entre 10238 y 10244 ns. Se observa la transición de desplazamientos negativos a cero y positivos, con valores `FFFFFFFC`, `FFFFFFFE`, `00000000`, `00000002`, `00000004` y `00000006`. El inmediato reordena los campos de instrucción y mantiene el bit menos significativo en cero.

![Simulación de inmediatos J y U](resultados/cpu/inmediatos_j_u.png)

**Figura 9.** Formatos J (`format=4`) y U (`format=3`) entre 12288 y 12295 ns. J reconstruye `FFF00000`, `000FFFFE`, `FFFFFFFE` y cero, incluyendo los límites con signo del desplazamiento. U produce `80000000`, `FFFFF000` y cero, manteniendo los doce bits inferiores en cero.

### Banco de registros

![Escritura y prioridad de reset en el banco de registros](resultados/cpu/registros_escritura_reset.png)

**Figura 10.** Entre 775 y 805 ns, ambas lecturas seleccionan x5 antes de escribir `0000007B`. Las salidas conservan `80000005` hasta el flanco ascendente de 785 ns. El reset se activa a 790 ns y borra los registros al flanco de 795 ns, aunque existe una solicitud de escritura a x7.

![Protección del registro x0](resultados/cpu/registros_x0.png)

**Figura 11.** Entre 55 y 95 ns se observa una solicitud de escritura a x0 con `we=1` y `wd=80000000`. La salida `b`, seleccionada mediante `rs2=0`, permanece en cero después del flanco ascendente de 65 ns. Las escrituras a x0 se descartan.

![Conservación del registro con escritura deshabilitada](resultados/cpu/registros_we.png)

**Figura 12.** Entre 730 y 748 ns, una solicitud a x5 presenta `wd=FFFFFFFF` con `we=0`. En el cursor de 745,5 ns, `rs1=5` y `a=80000005`, lo que confirma que el registro conserva el patrón previamente escrito.

### Decodificación

![Decodificación de ADD y rechazo de funct7 no soportado](resultados/cpu/decoder_add.png)

**Figura 13.** Entre 52223 y 52228 ns, la instrucción `007281B3` presenta `opcode=33`, `funct3=0` y `funct7=00`, con `legal=1` y `op=0` (ADD). Las codificaciones contiguas con valores de funct7 no soportados producen `legal=0` y selecciones de control en cero.

![Decodificación de SUB](resultados/cpu/decoder_sub.png)

**Figura 14.** Entre 52254 y 52260 ns, la instrucción `407281B3` se reconoce como SUB: `opcode=33`, `funct3=0`, `funct7=20`, `legal=1` y `op=1`. Los valores contiguos de funct7 se rechazan. Los campos opcode y funct7 se muestran en hexadecimal.

![Decodificación de LW y rechazo de una carga no soportada](resultados/cpu/decoder_lw.png)

**Figura 15.** Entre 3452 y 3460 ns, `opcode=03` y `funct3=2` seleccionan LW, con `kind=1`, `fmt=0`, `bs=1` y `wb=1`. A 3456 ns, funct3 cambia a 3 y la codificación se rechaza mediante `legal=0`. En las cargas, los bits superiores mostrados como funct7 pertenecen al inmediato.

#### Salto JAL

![Decodificación del salto JAL](resultados/cpu/decoder_jal.png)

**Figura 16.** Entre 113662 y 113670 ns, el cambio de opcode de `6E` a `6F` activa la decodificación de JAL. En el cursor de 113664,5 ns, `007281EF` produce `legal=1`, `kind=4`, `fmt=4` y `wb=2`. Esta última selección corresponde al enlace PC + 4. Los campos mostrados como funct3 y funct7 forman parte del inmediato J; la captura verifica las selecciones del decodificador, mientras que la ejecución del salto y la escritura en rd corresponden a las pruebas del procesador.

### Control y ruta de datos

**EN PROCESO**

### ROM de programa

**EN PROCESO**

### Ejecución integrada del CPU

**EN PROCESO**

## Análisis de resultados funcionales

### ALU

La simulación de `alu_tb` finalizó mediante `$finish` a 3296 ns y registró `PASS alu_tb: 3296 comprobaciones`. El testbench compara el resultado de la ALU con un valor de referencia tras cada estímulo y detiene la ejecución mediante `$fatal` si detecta una discrepancia.

La prueba recorre las diez operaciones implementadas y las seis codificaciones restantes, cuya salida prevista es cero. Cada código recibe seis pares de operandos dirigidos y doscientos pares pseudoaleatorios. Los casos dirigidos incluyen cero, desbordamiento modular de 32 bits, operandos negativos, límites con signo y cantidades de desplazamiento de 31 y 32.

### Generador de inmediatos

La simulación de `immediate_generator_tb` registró `PASS immediate_generator_tb: 14298 comprobaciones` y terminó a 14298 ns. La referencia compara cada inmediato reconstruido con el valor utilizado para codificar la instrucción de prueba.

Los formatos I y S recorren todos los valores de -2048 a 2047; el formato B recorre los valores pares de -4096 a 4094. Para J se comprueban extremos, -2 y cero; para U se incluyen los valores `80000000`, `FFFFF000` y cero. La prueba añade mil pares de casos pseudoaleatorios U/J y comprueba salida cero para los tres códigos de formato no utilizados.

### Banco de registros

La simulación de `register_file_tb` registró `PASS register_file_tb: 256 lecturas y prioridad de reset` y finalizó a 832 ns. El testbench realiza cuatro recorridos de los 32 índices por ambos puertos de lectura: tras el reset inicial, tras la escritura de patrones, tras una solicitud con escritura deshabilitada y después del reset final.

Además, se comprueba que una escritura dirigida a x0 se descarta y que la lectura del registro de destino cambia únicamente después del flanco ascendente habilitado. El reset final coincide con una solicitud de escritura y tiene prioridad sobre ella. Las 256 lecturas contabilizadas se complementan con comprobaciones específicas de la lectura antes y después del flanco de escritura.

### Decodificador de instrucciones

La simulación de `instruction_decoder_tb` finalizó a 131072 ns con `PASS instruction_decoder_tb: 131072 codificaciones`. Se recorren las 128 posibilidades de opcode, ocho de funct3 y 128 de funct7, manteniendo fijos los índices de registros del estímulo. Esta cobertura corresponde a los campos de decodificación, no a las 2^32 palabras de instrucción.

Cada caso compara la validez, clase de instrucción, formato de inmediato, operación ALU, selección de operandos y selección de retorno contra una referencia del testbench. Las codificaciones no soportadas deben producir `legal=0` y selecciones seguras en cero. Las capturas representativas se presentan en la sección de ondas.

### Módulos restantes

**EN PROCESO**

## Síntesis e implementación

La utilización de recursos y el cumplimiento temporal se documentan a partir de los reportes de síntesis e implementación. La simulación de comportamiento no determina estos valores. El análisis aislado del CPU se distingue del correspondiente al sistema completo; en el caso de la ROM, se identifica la imagen de instrucciones utilizada.

| Condición del análisis | Registro |
|---|---|
| Módulo superior y alcance | **EN PROCESO** |
| Dispositivo | **EN PROCESO** |
| Período de reloj y restricciones de entrada/salida | **EN PROCESO** |
| Imagen de ROM | **EN PROCESO** |

| Métrica | Resultado |
|---|---|
| LUT después de síntesis | **EN PROCESO** |
| LUT después de enrutamiento | **EN PROCESO** |
| Registros | **EN PROCESO** |
| Latches | **EN PROCESO** |
| Memorias de bloque | **EN PROCESO** |
| WNS y TNS después de enrutamiento | **EN PROCESO** |
| WHS y THS después de enrutamiento | **EN PROCESO** |
| Estado del enrutamiento | **EN PROCESO** |

### Reportes y análisis temporal

**EN PROCESO**

## Integración y simulación temporal

**EN PROCESO**
