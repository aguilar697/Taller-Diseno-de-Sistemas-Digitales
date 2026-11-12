# Sintesis aislada desde el repositorio, con IP regenerado y resultados en build/adc.
# No crea bitstream ni abre el proyecto original; la plataforma aporta las E/S finales.
if {$argc != 1} { error {Uso: sintetizar_adc.tcl <nombre_nuevo_de_ejecucion>} }
set adc_run [lindex $argv 0]
if {![regexp {^[A-Za-z0-9_-]+$} $adc_run]} { error {Nombre de ejecucion no valido.} }
set adc_root [file normalize [file join [file dirname [info script]] ../../..]]
set adc_synth_out [file join $adc_root build adc $adc_run]
if {[file exists $adc_synth_out]} { error "La salida ya existe: $adc_synth_out" }
# Reutiliza la misma importacion segura; el manifiesto identifica el wrapper generado.
set argc 1
set argv [list [file join $adc_synth_out ip]]
source [file join [file dirname [info script]] preparar_ip.tcl]
set adc_in [open [file join $adc_synth_out ip wrapper.txt] r]
set adc_synth_wrapper [string trim [read $adc_in]]
close $adc_in
set adc_files [list]
foreach adc_name {adc_control.sv adc_top.sv adc_axi_lite.sv adc_system_axi.sv} {
    lappend adc_files [file join $adc_root src design adc $adc_name]
}
lappend adc_files $adc_synth_wrapper
read_verilog -sv $adc_files
synth_design -mode out_of_context -top adc_system_axi -part xc7a35tcpg236-1
create_clock -name adc_clk -period 10.000 [get_ports s_axi_aclk]
report_utilization -file [file join $adc_synth_out utilization.rpt]
report_timing_summary -file [file join $adc_synth_out timing_post_synthesis.rpt]
puts {ADC_SYNTHESIS_COMPLETED_NO_BITSTREAM}
