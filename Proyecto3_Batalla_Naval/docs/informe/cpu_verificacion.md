# Verificación del procesador y la ROM

## Alcance

La verificación del subsistema CPU/ROM se organiza mediante testbenches autoverificables por módulo y una prueba integrada del procesador. Las pruebas secuenciales utilizan un reloj de 10 ns y reset síncrono activo alto.

La prueba del núcleo incluye la ROM de programa y un modelo síncrono de RAM y registros externos. No incluye el bus, VGA, UART ni el programa final de Batalla Naval. La metodología y las fuentes se describen en [Verificación del CPU y la ROM](../../src/testbench/cpu/README.md).

## Entorno de simulación

| Dato | Registro |
|---|---|
| Versión de Vivado | **EN PROCESO** |
| Fecha de ejecución | **EN PROCESO** |
| Dispositivo del proyecto | **EN PROCESO** |

## Resultados funcionales

| Testbench | Aspecto evaluado | Resultado observado |
|---|---|---|
| alu_tb | Aritmética, lógica, comparaciones y desplazamientos | **EN PROCESO** |
| immediate_generator_tb | Formatos de inmediato y extensión de signo | **EN PROCESO** |
| register_file_tb | Lecturas, escritura, x0, habilitación y reset | **EN PROCESO** |
| instruction_decoder_tb | Decodificación y rechazo de instrucciones no soportadas | **EN PROCESO** |
| cpu_control_tb | Estados, transiciones, habilitaciones y reset | **EN PROCESO** |
| cpu_datapath_tb | Rutas de datos, registros intermedios y alineación | **EN PROCESO** |
| program_rom_tb | Inicialización, lectura síncrona y límites de dirección | **EN PROCESO** |
| cpu_tb | Ejecución de programas, estado arquitectónico, accesos y latencias | **EN PROCESO** |

### Registros de ejecución

**EN PROCESO**

## Capturas de ondas de Vivado

### ALU y generación de inmediatos

**EN PROCESO**

### Banco de registros y decodificación

**EN PROCESO**

### Control y ruta de datos

**EN PROCESO**

### ROM de programa

**EN PROCESO**

### Ejecución integrada del CPU

**EN PROCESO**

## Análisis de resultados funcionales

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
