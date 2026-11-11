# vivado -mode batch -source <este_archivo> -tclargs <proyecto.xpr>
source [file join [file dirname [info script]] common.tcl]
require_vivado_version
if {[llength $argv] != 1} {error "Uso: synthesize.tcl <proyecto.xpr>"}
set xpr [file normalize [lindex $argv 0]]
set output [require_external_directory [file dirname $xpr]]
open_project $xpr
open_bd_design [get_files platform_microblaze.bd]
source [file join [file dirname [info script]] verify_bd.tcl]
verify_platform $output
generate_target all [get_files platform_microblaze.bd]
configure_runs
launch_runs synth_1 -jobs 4
wait_on_run synth_1
set status [get_property STATUS [get_runs synth_1]]
if {![string match {*synth_design Complete*} $status]} {error "Sintesis incompleta: $status"}
open_run synth_1
platform_reports $output/reports/synthesis
set clocks [get_clocks -of_objects [get_ports clk_i]]
require_equal [llength $clocks] 1 RELOJ_ENTRADA_UNICO
if {abs([get_property PERIOD $clocks] - 10.0) > 0.001} {error "Reloj distinto de 100 MHz"}
foreach port [get_ports] {
    if {[get_property PACKAGE_PIN $port] eq "" || [get_property IOSTANDARD $port] ne "LVCMOS33"} {
        error "Constraint fisico incompleto: $port"
    }
}
write_checkpoint -force $output/reports/synthesis/platform_synth.dcp
puts "SINTESIS=PASS; no implica timing post-routing ni ejecucion en hardware"
close_project
exit
