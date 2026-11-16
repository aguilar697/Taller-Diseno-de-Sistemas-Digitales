# Integración digital MicroBlaze V, ADC y PWM

## Alcance de la revisión

La rama dPuentes incorpora origin/main mediante los merges 63ebb78 y 33c6cbe, sin conflictos. El segundo incluye los PR 72–74 de pruebas y documentación ADC, sin cambios de RTL, XCI ni software. Los PR 66 (software) y 67 (ADC) están fusionados; el PR 65 de plataforma sigue abierto. El RTL PWM está publicado mediante el PR 71. Esta revisión integra ese PWM real junto con ADC y GPIO; no crea un PWM de prueba ni ejecuta el PR sobre hardware.

La construcción utiliza Vivado/Vitis 2026.1. No está comprobada con 2025.1. No hay bitstream, programación de FPGA ni conexión a potencia. Las advertencias del BSP, LUTAR-1 y TIMING-9 no se consideran resueltas.

## Conexiones y contratos

El [diagrama de plataforma](implementacion_microblaze.md#arquitectura-y-conexiones) mantiene una BRAM física de 32 KiB, datos DLMB e instrucciones AXI con caché de 8 KiB, FPU simple y 100 MHz. SmartConnect tiene siete salidas: INTC, Timer, UART, GPIO de entradas, GPIO de salidas, ADC y PWM.

El ADC se instancia como referencia a `adc_system_axi`, con `ADDR_WIDTH=12` y `ADC_TIMEOUT_CYCLES=1024`. Se usan sus cuatro fuentes RTL sin cambios. Se importa una copia del XCI `xadc_wiz_0` y se regeneran sus productos dentro del proyecto externo. La interfaz inferida es `s_axi`, AXI4-Lite de 32 bits. Vivado infiere el bloque `s_axi/reg0`, con un mínimo de 4096 bytes; doce bits locales permiten rechazar offsets no implementados sin alias dentro del segmento. Esto no agrega registros al ADC.

Reloj, reset activo bajo y accesos AXI llegan desde la plataforma. `pwm_trigger_i` recibe directamente `pwm/pwm_trigger_o`, en lugar del cero usado en la revisión parcial. Ambos bloques comparten 100 MHz; el trigger es un evento, no un reloj nuevo. VAUX6 sale por `vauxp6/vauxn6`. El reconocimiento conserva el protocolo de Kenneth: leer SAMPLE, leer el token snapshot en ACK_ID y devolver ese token completo, sin sustituirlo por ID16 ni escribir CONTROL[1]. Las operaciones deben ser ordenadas, no cacheadas y exclusivas entre lectores, con reset coordinado.

Se conservan los offsets ADC: CONTROL=0x00, STATUS=0x04, SAMPLE=0x08, ERROR=0x0C y ACK_ID=0x10. Los errores persistentes requieren revisión de recuperación; no se añade una limpieza ficticia al driver.

## Mapa y GPIO

| Periférico | Base | Ventana prevista |
|---|---|---|
| GPIO entradas | 0x40000000 | 64 KiB |
| GPIO salidas | 0x40010000 | 64 KiB |
| UART Lite | 0x40600000 | 64 KiB |
| AXI INTC | 0x41200000 | 64 KiB |
| AXI Timer | 0x41C00000 | 64 KiB |
| PWM real | 0x44000000 | 4 KiB |
| ADC | 0x44A00000 | 4 KiB |

Las ventanas pasan las comprobaciones del BD, incluida la ausencia de solapamientos en el espacio de datos. La vista de instrucciones comparte intencionadamente la BRAM, no es otro esclavo de datos. Las macros realmente exportadas por Vitis se registran en el informe de esta reconstrucción; no se supone que todo módulo RTL obtenga automáticamente un driver o una macro.

GPIO entradas tiene canales de 3 y 2 bits: BTN U/L/R para habilitar, reconocer y exportar, y SW0/SW1 para amplitud. GPIO salidas tiene canales de 4 y 1 bits: LED0–3 para operación/falla/exportación/latido y JA1 para diagnóstico ISR. BTN C conserva reset. Ver la tabla de pines en la guía de plataforma.

Fuente física: [XDC oficial de Digilent](https://github.com/Digilent/digilent-xdc/blob/master/Basys-3-Master.xdc). VAUX6 reserva J3/K3, JXADC1/JXADC7; consultar también el [manual Basys 3](https://digilent.com/reference/_media/basys3%3Abasys3_rm.pdf). El estándar del pin no amplía el rango de entrada analógica permitido. El mapa digital verificado utiliza pwm_ah/JC1/K17, pwm_al/JC2/M18, pwm_bh/JC3/N17, pwm_bl/JC4/P18 y pwm_period_start_o/JC7/L17, todos LVCMOS33. Cualquier conexión física posterior debe respetarlo y pasar por validación eléctrica del equipo; no se autoriza conectar drivers ni potencia.

## Timer, interrupciones y sincronización pendiente

El Timer usa las propiedades públicas COUNT_WIDTH=32, enable_timer2=1 y mode_64bit=0: dos contadores independientes, no cascada. El contador 0 queda disponible para cuenta descendente con autoreload y ENIT; el driver carga TLR0=9998 para 10000 ciclos, 100 us. El contador 1 se utiliza ascendente sin ENIT para medir ciclos. Configurar la IP no ejecuta todavía esas escrituras de software.

La interrupción del Timer se conserva en In0 del concat y AXI INTC, con entrada de nivel y modo normal. La aplicación debe construirse con PLATAFORMA_CON_INTC y comprobar el ID real exportado. No se agrega IRQ de ADC ni PWM.

La configuración publicada utiliza F_SW_HZ=10000, TS=100 us, DEADTIME=100 y TRIGGER_PHASE=5000. El PWM real expone `pwm_period_start_o` como puerto de diagnóstico en JC7/L17. `pwm_trigger_o` permanece en la red interna hacia ADC: podrá observarse con instrumentación interna en una revisión posterior. No son relojes. Se debe medir la siguiente secuencia, no asumirla:

1. Inicio de período y aplicación de referencia pendiente.
2. Disparo en fase 5000 y reconocimiento por ADC en el siguiente flanco.
3. Finalización de conversión/DRP, publicación de SAMPLE/token.
4. Entrada real a ISR, lectura coherente, ACK_ID y cálculo PR.
5. Finalización de la escritura REFERENCE antes del límite objetivo.

Timer y PWM se habilitan mediante accesos AXI separados. Tener ambos a 100 MHz no fija su fase. Los 111–113 ciclos de adquisición documentados por Kenneth son observaciones aisladas, no una cota integrada. El retardo de 1,5 Ts es una hipótesis nominal pendiente de medir. El presupuesto debe incluir entrada/salida de interrupción, guardado de FPU y accesos AXI, no solo el intervalo parcial medido en app_isr.

## Compilación exploratoria del PR

**Estado actual:** el flujo consolidado utiliza BSP local con backport de alineación, -Os y el linker validado ALIGN(16). La reconstrucción anterior enlazó con 32032 bytes reservados y 736 libres; la reconstrucción con PWM real se registra en el informe. Ver [consolidación de software](consolidacion_software_microblaze.md). Los párrafos siguientes describen el intento inicial -O0 y sus límites, no la configuración actual.

`scripts/vitis/build_pr_exploratory.py` genera una plataforma/BSP y copia los C/H reales a un workspace externo nuevo, conservando hashes de entrada. Usa el linker de diagnóstico de nuestra plataforma, limitado a 32 KiB, heap 2048 y pila 1024. No modifica `direcciones.h`, los drivers, parámetros ni fuentes AMD. La configuración CMake de la copia proporciona las bases obtenidas de xparameters y PLATAFORMA_CON_INTC; PWM_BASE identifica únicamente una reserva sin hardware. No debe descargarse ese ELF a esta plataforma parcial.

El primer intento conserva -O0, buffer de 1024 muestras y K_REG=1. El buffer ocupa 8192 bytes; eso no demuestra que la aplicación completa quepa. Se conservarán errores de enlace, mapa, BSP y reporte ELF. Si faltan macros, falla la compilación o no cabe, se documenta el resultado sin reducir memoria, buffer, FPU ni editar software ajeno. Ningún resultado de compilación demuestra ejecución, estabilidad del control ni calibración.

Comando desde una terminal Vitis, con las variables de la guía y rutas externas sin espacios:

```powershell
Push-Location "$fuentes/scripts/vitis"
try {
    vitis -s build_pr_exploratory.py "$salida/platform_microblaze.xsa" "$env:TEMP/p4_pr_nuevo"
} finally {
    Pop-Location
}
```

## Límites y verificaciones

Las comprobaciones ejecutables revisan CPU, memoria, mapa, canales GPIO, dos Timer, AXI ADC, reloj y reset compartidos e interrupción. La síntesis revisa pins y un solo reloj de entrada. Se mantienen visibles los avisos de E/S/CDC; no se añaden excepciones internas para cerrar timing ni se ejecuta implementación en esta etapa.

El merge mostró `timing_ruteo.rpt` de Kevin como modificado por atributos LF frente a un blob CRLF: su contenido local es idéntico byte por byte a HEAD. No se normaliza ni se agrega ese informe en esta tarea. Tampoco se modifica su .gitattributes.

Los [resultados de la revisión parcial](../informe/microblaze_reconstruccion.md#revisión-digital-con-adc-y-gpio--15-de-noviembre-de-2026) conservan el enlace fallido con -O0: 39088 bytes requeridos frente a 32768, exceso de 6320. Ese resultado histórico fue superado mediante -Os y ALIGN(16), sin modificar algoritmo, buffer ni memoria; no debe confundirse con una aprobación del lazo. El lanzador Vitis puede devolver cero ante una excepción Python; comprobar el resultado APP_BUILD y el reporte ELF, no solo el código externo.
