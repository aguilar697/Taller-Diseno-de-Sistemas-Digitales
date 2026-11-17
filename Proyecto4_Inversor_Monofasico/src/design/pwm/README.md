# Periférico PWM

El módulo superior es `pwm_system_axi`. Integra `pwm_axi_lite` (registros), `pwm_core` (portadora y referencia activa) y dos instancias de `pwm_deadtime` (separación de órdenes por rama). Las cuatro fuentes `.sv` de esta carpeta se incorporan al conjunto de diseño de Vivado.

La interfaz `S_AXI` utiliza datos de 32 bits, dirección local de 6 bits por defecto, reloj de 100 MHz y reset activo bajo. Las salidas `pwm_ah/al` y `pwm_bh/bl` se conectan a HIN/LIN de los drivers correspondientes. `pwm_trigger_o` inicia la adquisición; `pwm_period_start_o` permite observar el inicio del período para verificar la fase con el Timer. Ninguna de estas señales es un reloj generado.

Parámetros: `ADDR_WIDTH=6`, `MOD_LIMIT_Q15=27853` y `MIN_ON_CYCLES=100`. El reset borra la configuración y mantiene las salidas inactivas. Es obligatorio programar DEADTIME antes de habilitar.

Desde la consola Tcl de un proyecto abierto puede ejecutarse `source scripts/verificacion/pwm/agregar_pwm.tcl`, utilizando la ruta del archivo dentro del proyecto. El script agrega fuentes; la incorporación al Block Design y la asignación de direcciones corresponden a la integración de plataforma. Las referencias de módulo requieren administración automática de fuentes (`source_mgmt_mode=All`). `scripts/verificacion/pwm/verificar_interfaz.tcl` comprueba por separado que Vivado reconoce `S_AXI` y los puertos del módulo.
