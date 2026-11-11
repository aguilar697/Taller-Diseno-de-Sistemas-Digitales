# Opcional y separado de la reconstruccion/sintesis. Nunca genera bitstream.
# vivado -mode batch -source <este_archivo> -tclargs <proyecto.xpr>
source [file join [file dirname [info script]] common.tcl]
require_vivado_version
if {[llength $argv] != 1} {error "Uso: implement.tcl <proyecto.xpr>"}
set xpr [file normalize [lindex $argv 0]]
set output [require_external_directory [file dirname $xpr]]
open_project $xpr
configure_runs
launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
if {![string match {*route_design Complete*} [get_property STATUS [get_runs impl_1]]]} {
    error "Routing no completado"
}
open_run impl_1
set directory $output/reports/implementation
platform_reports $directory/reference
report_route_status -file $directory/reference/routing.rpt
write_checkpoint -force $directory/reference/routed.dcp
phys_opt_design -directive Explore
platform_reports $directory/optimized
report_route_status -file $directory/optimized/routing.rpt
write_checkpoint -force $directory/optimized/routed.dcp
set summary [open $directory/optimized/slack.txt w]
foreach mode {max min} {
    set path [get_timing_paths -delay_type $mode -max_paths 1]
    puts $summary "$mode=[get_property SLACK $path]"
}
puts $summary "BITSTREAM_NO_AUTORIZADO; revisar routing, timing, LUTAR-1 y TIMING-9"
close $summary
puts "Implementacion conservada para revision; no se genera bitstream automaticamente."
close_project
exit
