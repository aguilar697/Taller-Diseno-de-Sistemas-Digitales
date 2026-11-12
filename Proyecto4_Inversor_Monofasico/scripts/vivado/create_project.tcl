# vivado -mode batch -source <este_archivo> -tclargs <directorio_externo_nuevo>
source [file join [file dirname [info script]] common.tcl]
require_vivado_version
if {[llength $argv] != 1} {error "Uso: create_project.tcl <directorio_externo_nuevo>"}
set output [require_external_directory [lindex $argv 0]]
if {[file exists $output]} {error "La salida ya existe; use un directorio nuevo: $output"}
create_project microblaze_platform $output -part xc7a35tcpg236-1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
source [file join [file dirname [info script]] create_bd.tcl]
source [file join [file dirname [info script]] verify_bd.tcl]
verify_platform $output
generate_target all [get_files platform_microblaze.bd]
add_files -norecurse [make_wrapper -files [get_files platform_microblaze.bd] -top]
set_property top platform_microblaze_wrapper [get_filesets sources_1]
add_files -fileset constrs_1 -norecurse [list [file join $platform_source_root src constraints basys3_microblaze_diagnostic.xdc]]
configure_runs
update_compile_order -fileset sources_1
puts "CREACION_Y_VALIDACION=PASS"
puts "PROYECTO=[file join $output microblaze_platform.xpr]"
close_project
exit
