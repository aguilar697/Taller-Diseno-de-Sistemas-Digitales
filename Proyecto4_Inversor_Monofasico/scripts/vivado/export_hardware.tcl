# XSA de hardware sin bitstream, para la plataforma standalone de Vitis.
source [file join [file dirname [info script]] common.tcl]
require_vivado_version
if {[llength $argv] != 1} {error "Uso: export_hardware.tcl <proyecto.xpr>"}
set xpr [file normalize [lindex $argv 0]]
set output [require_external_directory [file dirname $xpr]]
open_project $xpr
open_bd_design [get_files platform_microblaze.bd]
source [file join [file dirname [info script]] verify_bd.tcl]
verify_platform $output
save_bd_design
generate_target all [get_files platform_microblaze.bd]
write_hw_platform -fixed -force -file $output/platform_microblaze.xsa
puts "XSA_SIN_BITSTREAM=$output/platform_microblaze.xsa"
close_project
exit
