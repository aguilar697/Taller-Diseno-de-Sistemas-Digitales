# Núcleo RISC-V multiciclo

El núcleo implementa el subconjunto documentado de RV32I y las instrucciones LUI/AUIPC. La búsqueda comienza en cero y la interfaz externa conserva los puertos acordados: `clk_i`, `rst_i`, `ProgAddress_o`, `ProgIn_i`, `DataAddress_o`, `DataOut_o`, `DataIn_i` y `we_o`.

## Organización

| Archivo | Responsabilidad |
|---|---|
| cpu_pkg.sv | Constantes de ALU, formatos, clases y estados |
| alu.sv | Operaciones combinacionales de 32 bits |
| immediate_generator.sv | Reconstrucción de inmediatos |
| register_file.sv | Banco de registros y protección de x0 |
| instruction_decoder.sv | Decodificación estricta y controles de ejecución |
| cpu_control.sv | FSM y habilitaciones |
| cpu_datapath.sv | Registros intermedios, rutas de PC y acceso de datos |
| cpu.sv | Conexión de bloques y captura de controles al finalizar DECODE |
| ../memory/program_rom.sv | ROM síncrona de 2048 palabras |

## Contrato de integración

La lectura de programa y la lectura de datos utilizan una latencia fija de un flanco: dirección estable antes de N, respuesta después de N y captura en N+1. No hay puertos ready/valid. Una escritura ocupa un ciclo de STORE. Las lecturas son libres de efectos secundarios; fuera de un acceso, la dirección de datos es cero y `we_o=0`.

La ROM se conecta con `addr_i=ProgAddress_o` y `rdata_o=ProgIn_i`. `INIT_FILE` selecciona el archivo de instrucciones. Su valor predeterminado vacío inicializa toda la ROM con NOP; la integración debe proporcionar la imagen real del programa. No se incorpora lógica del juego ni un programa ficticio de Batalla Naval.

El reset síncrono activo alto limpia el núcleo y no borra ROM. Una instrucción ilegal, una dirección de palabra desalineada o un destino de salto inválido detiene el núcleo en FAULT hasta reset. El fallo permanece interno, sin modificar la interfaz de integración. Los accesos de datos alineados pero no mapeados los resuelve el bus externo.

## Validación

Los testbenches individuales y su procedimiento de ejecución están en [Verificación del CPU y ROM](../../testbench/cpu/README.md). El diseño se desarrolla en [tercer nivel](../../../docs/diseno/nivel_3_cpu.md) y [cuarto nivel](../../../docs/diseno/nivel_4_cpu.md).

La síntesis e implementación se realizan en Vivado para el dispositivo `xc7a35tcpg236-1`. Los reportes de recursos y tiempos se documentan junto con el módulo superior, la imagen de ROM y las restricciones utilizadas. El análisis del núcleo aislado no sustituye la validación del sistema integrado.
