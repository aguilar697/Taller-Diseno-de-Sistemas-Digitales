# Ejecución del sistema en Basys 3

## Requisitos

- Vivado con soporte para `xc7a35tcpg236-1`.
- Python 3.10 o posterior.
- Basys 3, conexión USB, monitor VGA y buzzer externo en JA1 según las conexiones del diseño.
- `pyserial` para la terminal del Jugador 2.

Ejecutar las órdenes desde la raíz de `Proyecto3_Batalla_Naval`. Los scripts localizan Vivado en PATH o en las ubicaciones habituales de instalación. También puede indicarse su carpeta `bin` mediante `VIVADO_BIN` o `--vivado-bin`.

## Comprobaciones antes de implementar

```powershell
python scripts/ensamblar_programa.py --check
python -m unittest discover -s src/software_pc -v
python -m unittest discover -s scripts -p "test_*.py" -v
python scripts/verificar_sistema_completo.py --all
python scripts/verificar_partida_j2.py
```

La simulación completa utiliza el CPU y los periféricos RTL, UART 8N1 a 115200 baud y un modelo funcional de reloj VGA de 25 MHz. El guion cubre colocación inválida, rotación, disparo fuera de turno, disparo repetido, hundimientos, victoria y reinicio. Se comparan las tramas, ambos tableros en RAM, estadísticas y marcador. Las capturas de píxeles se conservan como archivos de texto para examinar la salida gráfica simulada.

`pixel_clock_wiz_sim.sv` solo se habilita con `BN_FUNCTIONAL_CLOCK` en el script de simulación. El proyecto de Vivado utiliza el IP real `pixel_clock_wiz.xci` y deshabilita ese modelo. No debe habilitarse la macro en el proyecto de implementación.

## Proyecto de Vivado y bitstream

```powershell
python scripts/implementar_basys3.py --project-only
```

Esta orden copia las fuentes a un directorio temporal exclusivo, genera el IP y muestra la ruta del `.xpr` que se puede abrir en Vivado. La copia es independiente del repositorio; si se modifican las fuentes, se debe crear nuevamente el proyecto. El top de implementación es `basys3_top`, con `basys3_battleship.xdc` y `program.hex`. El top inicial de simulación es `cpu_tb`.

Para generar automáticamente el bitstream:

```powershell
python scripts/implementar_basys3.py
```

El flujo ejecuta síntesis, implementación, análisis temporal y DRC. Detiene la generación ante latches, infracciones DRC o slack negativo. Los reportes, el manifiesto SHA-256 de las fuentes y `batalla_naval.bit` se guardan en una carpeta de ejecución dentro de `build/vivado/`. Los archivos generados quedan excluidos de Git.

También se puede ejecutar `scripts/crear_proyecto.tcl` desde la consola Tcl de Vivado para crear el proyecto en `build/proyecto_vivado/`. Si esa carpeta ya contiene un proyecto, se debe abrir el existente o escoger otro directorio de trabajo; el script no borra proyectos.

## Simulación postimplementación con retardos

Después de implementar, utilizar el `.xpr` cuya ruta muestra el script:

```powershell
python scripts/verificar_postimplementacion.py --project "C:/ruta/al/proyecto/batalla_naval.xpr"
```

Este flujo abre `impl_1`, exporta el netlist `timesim` y los retardos SDF de esquina lenta, y ejecuta XSim con retardos máximos. Utiliza el MMCM y la ROM del diseño implementado. El banco aplica estímulos por los puertos externos y observa UART y LED para comprobar el anuncio de nueva partida, el rechazo de un barco con identificador inválido y el rechazo de un disparo durante colocación. La espera de arranque del programa, de aproximadamente 13,2 ms, hace que este ensayo requiera más tiempo de ejecución que las pruebas RTL.

Los registros de ejecución se guardan en `build/postimplementacion/`; al aprobar el ensayo, se genera además el resultado con los hashes del netlist, SDF y banco de pruebas. La carpeta temporal indicada conserva `postimpl.wdb` para inspeccionar ondas en Vivado. El alcance es el arranque y los rechazos descritos. El banco se encuentra en `scripts/postimplementacion/` y se compila contra el netlist enrutado.

## Ejecución desde la interfaz de Vivado

Abrir el archivo `.xpr` del proyecto configurado. En **Sources**, comprobar que `basys3_top` es el módulo superior de **Design Sources**. El proyecto debe incluir `basys3_battleship.xdc`, el IP `pixel_clock_wiz` y `program.hex`; este último se agrega como **Memory Initialization Files**. La selección del dispositivo es `xc7a35tcpg236-1`. El IP suministrado se configura por dispositivo, sin seleccionar una placa en **Board Part**; las conexiones de Basys 3 las establece el XDC.

Para simular el juego completo:

1. En **Simulation Sources**, seleccionar `tb_battleship_system`, pulsar el botón derecho y escoger **Set as Top**.
2. Comprobar que `guion.txt` está agregado a `sim_1` como **Data Files**. Vivado lo copia al directorio de simulación junto con `program.hex`.
3. En **Flow Navigator**, escoger **Simulation → Run Simulation → Run Behavioral Simulation**.
4. En **Tcl Console**, ejecutar `run all` y esperar el mensaje `PASS` del banco de pruebas. Si ya terminó y se desea repetir, ejecutar `restart` y luego `run all`.

La prueba completa puede tardar varios minutos con el IP real de reloj. El tiempo inicial que muestra Vivado al abrir la simulación no equivale a completar la prueba.

Para ejecutar la prueba general de conexiones y reset, seleccionar **all_top_modules_tb** como top de simulación y ejecutar `run all`. El resultado esperado es de 32 verificaciones aprobadas. El banco contiene una aserción de fallo intencional, comentada en su configuración normal. Para comprobar el detector de errores, activarla en una copia de prueba y recompilar: la simulación debe informar el fallo y finalizar mediante `$fatal`.

Para programar la tarjeta, ejecutar **Run Synthesis**, **Run Implementation** y **Generate Bitstream**, en ese orden. Cada etapa debe terminar correctamente antes de continuar. Después, conectar la Basys 3 y abrir **Hardware Manager → Open Target → Auto Connect → Program Device**. Este flujo requiere una licencia de síntesis válida para el dispositivo.

El proyecto generado utiliza síntesis e implementación completas, con compilación incremental deshabilitada. Si un proyecto existente presenta el error `[Vivado 12-29181]` al ejecutar `read_checkpoint -auto_incremental -incremental`, aplicar en **Tcl Console**:

```tcl
foreach run_name {synth_1 impl_1} {
    set_property INCREMENTAL_CHECKPOINT {} [get_runs $run_name]
    set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs $run_name]
}
set_property WRITE_INCREMENTAL_SYNTH_CHECKPOINT 0 [get_runs synth_1]
```

Luego reiniciar la ejecución fallida de síntesis y generar nuevamente el bitstream. Se utiliza síntesis e implementación completas; este ajuste no modifica el RTL ni los controles del juego.

## Terminal y controles

```powershell
python -m pip install -r src/software_pc/requirements.txt
python src/software_pc/naval_terminal.py COM6
```

Cambiar `COM6` por el puerto asignado a la Basys 3. La terminal permite seleccionar el puerto cuando se omite ese argumento. La conexión utiliza 115200 baud, ocho bits de datos, sin paridad y un bit de parada.

La terminal espera el anuncio de inicio antes de solicitar colocaciones. Si la FPGA se programó antes de abrir la terminal, pulsar y soltar BTNC inicia una partida sincronizada. Para arrancar desde reset, abrir la terminal con `SW15=0` y después subir `SW15=1`: la terminal recibe el anuncio tras la espera inicial de estabilización de los switches. Mantener `SW0=0` y `SW1=0` permite producir posteriormente nuevos flancos de rotación y confirmación.

| Control | Función |
|---|---|
| BTNU, BTND, BTNL, BTNR | Mover el cursor |
| SW0 | Cambiar orientación del barco; subir y bajar el switch para cada rotación |
| SW1 | Confirmar colocación o disparo; volver a cero antes de confirmar otra vez |
| BTNC | Reiniciar la partida conservando el marcador; pulsar y soltar el botón |
| SW15 | RUN: `0` aplica reset general y borra el marcador; `1` habilita el funcionamiento |
| LED0–LED3 | Estado físico de BTNU, BTND, BTNL y BTNR, respectivamente |
| LED4–LED6 | Estado físico de SW0 (orientación), SW1 (confirmación) y BTNC (nueva partida) |
| LED11 | Fase de colocación |
| LED12 | Fase de batalla |
| LED13 | Fase de resultado |
| LED7–LED10 y LED14 | Apagados en el top del juego completo |
| LED15 | Sigue a SW15: encendido con RUN en `1`; indica que el reset general no está solicitado |
| Displays | Victorias de J1 y J2 |

Los LED0–LED6 del juego completo reflejan directamente los pines; el programa recibe las entradas sincronizadas y filtradas. En el top independiente de prueba del Subsistema 2, los indicadores de controles muestran los niveles filtrados. El orden de los siete controles coincide en ambos tops.

La orden de victoria reproduce cuatro notas ascendentes, Do5, Mi5, Sol5 y Do6, de aproximadamente 523, 659, 784 y 1046 Hz. Cada nota dura 200 ms con reloj de 100 MHz; la secuencia completa dura 800 ms y termina automáticamente. Las demás órdenes conservan sus tonos y duraciones independientes.

## Secuencia de juego

1. Conectar USB, monitor VGA y buzzer. Abrir la terminal con SW15 en cero; mantener SW0 y SW1 en cero y subir SW15 para arrancar.
2. Colocar los barcos de longitudes 4, 3 y 2. J1 mueve el cursor, rota con SW0 y confirma con SW1. J2 introduce en la terminal las coordenadas y la orientación solicitadas. Una colocación rechazada permite intentar otra posición.
3. Cuando ambas flotas están completas, seguir el indicador de turno. J1 selecciona una casilla del tablero rival y confirma; J2 introduce las coordenadas en la terminal. Cada disparo válido cambia el turno. Repetir una casilla no consume turno.
4. Al hundirse la flota rival, comprobar el ganador en VGA y terminal, la secuencia sonora y el incremento del marcador.
5. Pulsar y soltar BTNC para comenzar otra partida conservando las victorias. Bajar SW15 y volver a subirlo reinicia el sistema y borra el marcador.

La vista rival presenta únicamente las casillas descubiertas. Las conexiones y controles de esta guía corresponden a `basys3_top` y `basys3_battleship.xdc`.
