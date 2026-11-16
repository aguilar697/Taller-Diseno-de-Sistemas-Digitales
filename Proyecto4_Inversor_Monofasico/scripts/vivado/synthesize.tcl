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
set pending_pwm {}
foreach port [get_ports] {
    if {[get_property PACKAGE_PIN $port] eq "" || [get_property IOSTANDARD $port] ne "LVCMOS33"} {
        if {$port in {pwm_ah pwm_al pwm_bh pwm_bl pwm_period_start_o} && [get_property PACKAGE_PIN $port] eq ""} {
            lappend pending_pwm $port
        } else {error "Constraint fisico incompleto no previsto: $port"}
    }
}
set fh [open $output/reports/synthesis/pending_pwm_pins.txt w]
puts $fh "PUERTOS_SIN_ASIGNACION_FISICA=$pending_pwm"
puts $fh "No se modificaron severidades DRC ni se autoriza implementacion/bitstream."
close $fh
write_checkpoint -force $output/reports/synthesis/platform_synth.dcp
puts "SINTESIS=PASS; no implica timing post-routing ni ejecucion en hardware"
puts "CONSTRAINTS_PWM_PENDIENTES=$pending_pwm"
close_project
exit
