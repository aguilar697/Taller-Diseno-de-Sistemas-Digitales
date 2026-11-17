# Sintesis, implementacion y bitstream del sistema integrado.
source [file join [file dirname [info script]] common.tcl]
require_vivado_version
if {$argc != 1} {error "Uso: construir_integrado.tcl <proyecto.xpr>"}
set xpr [file normalize [lindex $argv 0]]
set out [require_external_directory [file dirname $xpr]]
set_param general.maxThreads 2
open_project $xpr
configure_runs
# Evita lanzar simultaneamente multiples sintesis de IP en equipos de laboratorio.
set_property synth_checkpoint_mode None [get_files platform_microblaze.bd]
set_property GENERATE_SYNTH_CHECKPOINT false [get_files -all *xadc_wiz_0.xci]
set_property strategy Performance_Explore [get_runs impl_1]
launch_runs synth_1 -jobs 2
wait_on_run synth_1
if {![string match {*synth_design Complete*} [get_property STATUS [get_runs synth_1]]]} {error "Fallo la sintesis"}
launch_runs impl_1 -to_step route_design -jobs 2
wait_on_run impl_1
if {![string match {*route_design Complete*} [get_property STATUS [get_runs impl_1]]]} {error "Fallo el ruteo"}
open_run impl_1
file mkdir [file join $out reports implementacion]
platform_reports [file join $out reports implementacion]
foreach delay {max min} {
    set paths [get_timing_paths -delay_type $delay -max_paths 1]
    if {![llength $paths]} {error "Sin caminos temporizados $delay"}
    set slack [get_property SLACK [lindex $paths 0]]
    puts "SLACK_$delay=$slack"
    if {$slack < 0} {error "No se satisface timing $delay"}
}
launch_runs impl_1 -to_step write_bitstream -jobs 2
wait_on_run impl_1
if {[get_property PROGRESS [get_runs impl_1]] ne "100%"} {error "Fallo el bitstream"}
write_hw_platform -fixed -include_bit -force -file [file join $out inversor_integrado.xsa]
puts "BITSTREAM_INTEGRADO_LISTO"
close_project
