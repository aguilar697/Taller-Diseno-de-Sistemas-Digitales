# Verificación del PWM personalizado

## Alcance

Se verificó el periférico `pwm_system_axi`, formado por interfaz AXI4-Lite, registros, modulador unipolar centrado y dos máquinas de tiempo muerto. Se utilizaron Icarus Verilog y XSim de Vivado 2026.1. La implementación independiente corresponde al dispositivo Basys 3 `xc7a35tcpg236-1`, con reloj de 100 MHz.

El [contrato de integración](../diseno/pwm_integracion.md) fija inicialmente 10 kHz, D=100 ciclos, disparo en fase 5000, referencia Q1.15 limitada a ±27853 y margen mínimo de conducción de 100 ciclos. Los [niveles tercero](../diseno/nivel_3_pwm.md) y [cuarto](../diseno/nivel_4_pwm.md) describen el diseño y sus prioridades.

## Simulación funcional

| Banco | Comprobaciones por ejecución | Icarus | XSim | Propiedades principales |
|---|---:|---|---|---|
| `tb_pwm_deadtime` | 20 | PASS | PASS | Arranque, objetivos descartados, espera, apagado, reset y estado inválido |
| `tb_pwm_core` | 1064490 | PASS | PASS | 10/20/25 kHz, referencias de ambos signos, cuantización, duración de pulsos, fases y tiempo muerto |
| `tb_pwm_axi` | 1220 | PASS | PASS | AW/W independientes, espera B/R, WSTRB, saturación, errores, límites al habilitar y referencia coincidente con el inicio de período |
| `tb_pwm_adc` | 260195 | PASS | PASS | Disparo periódico, conversión, ID/token, lectura de muestra completa y aplicación diferida de referencia |

La cantidad incluye comprobaciones repetidas por ciclo y no equivale a un porcentaje de cobertura formal. Los estímulos y las condiciones de fallo se conservan en [los testbenches](../../src/testbench/pwm/README.md). Los resúmenes identifican las fuentes mediante SHA-256: [Icarus](resultados/pwm/funcional_iverilog.json) y [XSim](resultados/pwm/funcional_xsim.json).

Las pruebas de núcleo recorren períodos completos con cero, referencias positivas/negativas, límites de modulación y valores de un LSB. Se comprueban D=1, 3 y 100 ciclos; el pulso de adquisición se verifica en el comienzo, mitad y extremos del período. La prueba AXI comprueba además que un acceso rechazado no modifique la configuración y que una orden de apagado conserve la frecuencia anterior durante operación.

`tb_pwm_adc` conecta el PWM completo con el módulo `adc_control` del repositorio. El banco modela EOC después de 100 ciclos y DRDY siete ciclos después de DEN; entrega códigos conocidos y reconoce publicaciones mediante token. Se consumen doce muestras y se verifica que la siguiente quede disponible. No incluye AXI del ADC, XADC Wizard, CPU ni señal analógica; su resultado prueba coordinación digital bajo esas condiciones.

## Detección de error forzado

`tb_pwm_axi +INJECT_ERROR` fuerza simultáneamente las órdenes superior e inferior de una rama. El monitor termina con `PWM_OVERLAP_DETECTED`. La ejecución negativa se considera correcta solo si aparece ese diagnóstico y no el mensaje de aprobación del banco. Se comprobó la detección en Icarus y XSim. El [resumen del ensayo negativo](resultados/pwm/error_forzado.json) distingue el fallo esperado de un error de compilación.

La inyección utiliza `force` exclusivamente en el testbench. No añade lógica de inyección al circuito sintetizable y no representa un ensayo de cortocircuito físico.

## Implementación independiente

| Indicador después de ruteo | Resultado |
|---|---:|
| Reloj restringido | 100 MHz; período 10 ns |
| Peor slack de setup | +0,507 ns |
| Peor slack de hold | +0,169 ns |
| Endpoints con fallo setup / hold | 0 / 0 |
| LUT | 568 de 20800 (2,73 %) |
| Flip-flops | 282 de 41600 (0,68 %) |
| DSP | 3 de 90 (3,33 %) |
| BRAM | 0 |

Se conservan los reportes originales de [temporización](resultados/pwm/timing_ruteo.rpt), [utilización](resultados/pwm/utilizacion_ruteo.rpt) y [DRC](resultados/pwm/drc.rpt), junto con el [manifiesto de fuentes y resultado](resultados/pwm/implementacion.json).

Para reducir la ruta combinacional se usa aritmética de ancho acotado, validación con constantes por frecuencia, cálculo paralelo de umbrales y comparación de intervalos equivalente a la portadora triangular. En el valle se utiliza la identidad de que ambas órdenes superiores ideales están activas para todo el rango permitido. Estas transformaciones conservan la aplicación atómica de referencia y fueron verificadas otra vez con los bancos funcionales.

La implementación es fuera de contexto: no asigna pines, retardos de entrada/salida ni ubicación de reloj del sistema completo. No existen endpoints internos sin restricción de reloj, pero los puertos AXI y PWM requieren el contexto de la plataforma para su análisis final. DRC informa advertencias de configuración de banco y de ausencia de registros internos de DSP; no se declara un diseño completo listo para bitstream a partir de este ensayo.

También se comprobó la incorporación como referencia de módulo a un Block Design temporal: Vivado reconoció `S_AXI` como AXI4-Lite, el reloj a 100 MHz, reset activo bajo y los seis puertos de salida. La prueba exige administración automática de fuentes. El [registro de interfaz](resultados/pwm/interfaz_bd.txt) conserva ese resultado. Vivado emitió la advertencia de soporte parcial de empaquetado con top SystemVerilog; la referencia de módulo se creó correctamente. Este ensayo no conecta ni valida el Block Design completo de MicroBlaze.

## Simulación temporizada

Se ejecutó `tb_pwm_timing` sobre la netlist posterior al ruteo, con anotación SDF máxima confirmada por XSim. El banco solo utiliza los puertos externos y comprueba lectura/escritura AXI, saturación, tres períodos de 100 µs, disparo a los 50 µs, pulso de un ciclo, separación de órdenes, cambio de referencia, rechazo de reconfiguración activa, apagado y reset. Resultado: **PASS, 81 comprobaciones**, sin avisos de anotación fallida ni violaciones temporales en el ensayo.

La comprobación de separación en puertos admite hasta un ciclo de diferencia entre retardos de salida; no sustituye la medición de VGS ni del tiempo muerto efectivo de los transistores. Los archivos [de resultado](resultados/pwm/temporizada_xsim.json), [elaboración](resultados/pwm/temporizada_elaboracion.txt) y [simulación](resultados/pwm/temporizada.txt) identifican netlist, SDF y estímulos utilizados. La anotación se configura con `--sdfmax` mediante un archivo de opciones, conforme a [UG900 de AMD](https://docs.amd.com/r/2025.1-English/ug900-vivado-logic-simulation/xelab-xvhdl-and-xvlog-xsim-Command-Options).

## Consistencia con el control

Se mantuvieron los offsets del driver C y se configuró `TRIGGER_PHASE=5000` en `parametros.h`. Se aclaró que `VDC_V=12` es la normalización fija del modelo inicial; el bus físico sigue siendo variable entre 12 y 24 V. No se sustituyó la calibración nominal por valores físicos incompletos.

Los coeficientes resonantes del C coinciden con Tustin preajustado a 50 Hz, Kp=12, Kr=200 y ancho resonante de 2 Hz. El [contraste numérico](resultados/pwm/control_parametros.json) evalúa 24 combinaciones de R=7,2/10,5 Ω, L=6,984/9,291/10 mH, bus=12/24 V y retardos de uno/dos períodos. Los modelos lineales resultan estables y con error de amplitud menor de 10 %. Este análisis no demuestra el montaje real, la recuperación en saturación ni el retardo fraccionario integrado.

Las 13 pruebas existentes de software y las 18 pruebas de análisis numérico terminaron correctamente después del ajuste de parámetros. Los modelos PLECS y sus resultados previos permanecen sin modificaciones; sus condiciones, incluido el retardo utilizado, se consultan en el [análisis de potencia](../../modelos/analisis/README.md).

## Reproducción y validación pendiente

El [procedimiento de ejecución](../../src/testbench/pwm/README.md) utiliza fuentes del repositorio y genera comandos, logs y huellas en `build/pwm/`, excluido de Git. Las evidencias citadas son una selección de esos resultados; las netlists, SDF, checkpoints y ejecutables se regeneran con los scripts.

Antes de aceptar el sistema integrado se requiere:

- comprobar la versión Vivado/Vitis 2025.1 solicitada por el instructivo; esta verificación se ejecutó en 2026.1;
- incorporar el módulo a la plataforma, asignar direcciones y pines, y repetir timing del sistema completo;
- medir la fase Timer–PWM, la disponibilidad ADC y el tiempo de ISR para confirmar el retardo y el plazo de escritura;
- verificar la ocupación final de BRAM con BSP, pila, programa y buffer;
- calibrar cero y ganancia firmada del sensor y definir el permiso de apagado SD;
- comprobar ambos drivers, bootstrap, VGS y ausencia de solapamiento físico antes de cerrar el lazo con potencia.

La verificación independiente del PWM está completada bajo las condiciones indicadas. La integración con MicroBlaze y la validación eléctrica permanecen pendientes.
