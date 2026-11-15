# Síntesis e implementación fuera de contexto del periférico para Basys 3.
# Uso: vivado -mode batch -source implementar_pwm.tcl -tclargs directorio_salida
if {$argc != 1} { error "Indique un directorio nuevo de salida." }
set root [file normalize [file join [file dirname [info script]] ../../..]]
set out [file normalize [lindex $argv 0]]
if {[file exists $out]} { error "El directorio de salida ya existe: $out" }
file mkdir $out
set_param general.maxThreads 1
create_project -in_memory -part xc7a35tcpg236-1
set sources [list]
foreach name {pwm_deadtime pwm_core pwm_axi_lite pwm_system_axi} {
    lappend sources [file join $root src design pwm ${name}.sv]
}
read_verilog -sv $sources
# Solo se restringe el reloj real; no se asignan pines de la plataforma del equipo.
set clock_file [file join $out reloj.xdc]
set cf [open $clock_file w]
puts $cf {create_clock -name s_axi_aclk -period 10.000 [get_ports s_axi_aclk]}
close $cf
read_xdc $clock_file
synth_design -top pwm_system_axi -part xc7a35tcpg236-1 -mode out_of_context
report_utilization -file [file join $out utilizacion_sintesis.rpt]
report_timing_summary -file [file join $out timing_sintesis.rpt]
opt_design
place_design
route_design
report_utilization -file [file join $out utilizacion_ruteo.rpt]
report_timing_summary -report_unconstrained -file [file join $out timing_ruteo.rpt]
report_drc -file [file join $out drc.rpt]
write_checkpoint [file join $out pwm_ruteado.dcp]
write_verilog -mode timesim -sdf_anno false [file join $out pwm_timesim.v]
write_sdf [file join $out pwm_timesim.sdf]
set paths [get_timing_paths -delay_type max -max_paths 1]
if {![llength $paths]} { error "No se encontraron caminos temporizados." }
set slack [get_property SLACK [lindex $paths 0]]
set hold_paths [get_timing_paths -delay_type min -max_paths 1]
set hold_slack [get_property SLACK [lindex $hold_paths 0]]
set fp [open [file join $out resultado.txt] w]
puts $fp "Vivado [version -short]"
puts $fp "Dispositivo xc7a35tcpg236-1"
puts $fp "Implementacion fuera de contexto; reloj 100 MHz"
puts $fp "Peor slack setup: $slack ns"
puts $fp "Peor slack hold: $hold_slack ns"
puts $fp "Sin asignaciones de pines ni validacion de E/S del sistema completo"
close $fp
if {$slack < 0} { error "El periferico no cierra setup a 100 MHz." }
if {$hold_slack < 0} { error "El periferico no satisface hold." }
puts "PWM_IMPLEMENTATION_PASSED slack=$slack"
