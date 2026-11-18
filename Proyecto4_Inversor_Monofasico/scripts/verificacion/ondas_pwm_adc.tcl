# Ejecutar con el snapshot tb_pwm_adc_axi desde su carpeta de simulación.
set senales [list /tb_pwm_adc_axi/ah /tb_pwm_adc_axi/al \
    /tb_pwm_adc_axi/period_start /tb_pwm_adc_axi/trigger_adc \
    /tb_pwm_adc_axi/adc/u_adc/convst /tb_pwm_adc_axi/adc/sample \
    /tb_pwm_adc_axi/pwm/core/active_reference_q]
open_vcd pwm_adc.vcd
log_vcd {*}$senales
log_wave {*}$senales
run all
close_vcd
quit
