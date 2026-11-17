# Plataforma de Puentes con conexion JA y permiso SW15 para el laboratorio.
# Uso: vivado -mode batch -source integrar_sistema.tcl -tclargs salida_nueva
source [file join [file dirname [info script]] common.tcl]
require_vivado_version
if {$argc != 1} {error "Uso: integrar_sistema.tcl <salida_nueva>"}
set output [require_external_directory [lindex $argv 0]]
if {[file exists $output]} {error "La salida ya existe: $output"}
set_param general.maxThreads 2
create_project inversor_integrado $output -part xc7a35tcpg236-1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
import_ip -files [list [file join $platform_source_root src design adc ip xadc_wiz_0 xadc_wiz_0.xci]]
generate_target all [get_ips xadc_wiz_0]
foreach name {adc_control adc_top adc_axi_lite adc_system_axi} {
    add_files -norecurse [list [file join $platform_source_root src design adc ${name}.sv]]
}
source [file join [file dirname [info script]] prepare_pwm_integration.tcl]
prepare_pwm_sources $platform_source_root
source [file join [file dirname [info script]] create_bd.tcl]
source [file join [file dirname [info script]] verify_bd.tcl]
verify_platform $output
# El permiso externo utiliza el mismo reloj que PWM/ADC, despues del MMCM.
create_bd_port -dir O -type clk axi_clk_o
connect_bd_net [get_bd_pins clk_wiz_1/clk_out1] [get_bd_ports axi_clk_o]
save_bd_design
generate_target all [get_files platform_microblaze.bd]
add_files -norecurse [make_wrapper -files [get_files platform_microblaze.bd] -top]
add_files -norecurse [list [file join $platform_source_root src design top inversor_basys3.sv]]
set_property top inversor_basys3 [get_filesets sources_1]
foreach name {pwm_basys3_ja.xdc inversor_integrado_basys3.xdc} {
    add_files -fileset constrs_1 -norecurse [list [file join $platform_source_root src constraints $name]]
}
configure_runs
update_compile_order -fileset sources_1
puts "PROYECTO=[file join $output inversor_integrado.xpr]"
close_project
exit
