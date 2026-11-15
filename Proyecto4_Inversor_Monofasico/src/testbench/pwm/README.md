# Pruebas del PWM

Los bancos son autoverificables y terminan con `$fatal` si incumplen una condición. La ejecución correcta imprime `TEST PASSED`. Los retardos de los estímulos no sustituyen la comprobación de respuestas AXI.

| Banco | Alcance |
|---|---|
| `tb_pwm_deadtime` | Arranque, espera, cambio de objetivo, apagado, reset y recuperación de estado inválido |
| `tb_pwm_core` | Tres frecuencias, referencias de ambos signos y extremos, cuantización, períodos, fases y separación de órdenes |
| `tb_pwm_axi` | Canales independientes, respuestas retenidas, WSTRB, errores, saturación, validación al habilitar y escritura coincidente con inicio de período |
| `tb_pwm_adc` | PWM completo con `adc_control` y modelo digital de EOC/DRDY; adquisición, publicación y reconocimiento por token |
| `tb_pwm_timing` | Verificación desde los puertos externos; admite RTL o netlist implementada con SDF |

Desde la raíz de Proyecto 4:

```powershell
python scripts/verificacion/pwm/ejecutar_pruebas_pwm.py --nombre funcional
python scripts/verificacion/pwm/ejecutar_pruebas_pwm.py --simulador xsim --vivado-home C:/AMDDesignTools/2026.1/Vivado --nombre xsim
python scripts/verificacion/pwm/ejecutar_pruebas_pwm.py --tests tb_pwm_axi --error-forzado --nombre negativo
```

Icarus (`iverilog` y `vvp`) debe estar en PATH para el primer y tercer comando. Para Vivado se indica su instalación o se define `VIVADO_HOME`. Cada nombre de ejecución debe ser nuevo. `EXPECTED_FAILURE` significa que el ensayo negativo identificó específicamente `PWM_OVERLAP_DETECTED`; un error de compilación no se considera detección correcta.

Los comandos, huellas SHA-256 y logs se generan en `build/pwm/`. La prueba PWM–ADC no incluye procesador, AXI del ADC, XADC Wizard ni señal analógica: verifica la coordinación digital con una latencia de respuesta declarada en el banco.

Implementación independiente y simulación temporizada:

```powershell
python scripts/verificacion/pwm/implementar_pwm.py --vivado-home C:/AMDDesignTools/2026.1/Vivado --nombre implementacion
python scripts/verificacion/pwm/ejecutar_pruebas_pwm.py --simulador xsim --vivado-home C:/AMDDesignTools/2026.1/Vivado --tests tb_pwm_timing --netlist-dir build/pwm/implementacion/resultados --nombre temporizada
```

El ejecutor Python prepara un directorio temporal ASCII para evitar interrupciones de Vivado por la ruta de trabajo en Windows, llama a `implementar_pwm.tcl` y conserva los resultados en `build/`. El script restringe el reloj a 10 ns para `xc7a35tcpg236-1`. No sustituye las restricciones de pines ni el análisis temporal del sistema integrado. [Resultados y límites de verificación](../../../docs/informe/pwm_verificacion.md).
