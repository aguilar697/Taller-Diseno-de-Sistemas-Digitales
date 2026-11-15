# Comprobación de reconocimiento como referencia de módulo en Block Design.
# Uso desde una ruta de trabajo ASCII: vivado -mode batch -source este_archivo.tcl
set root [file normalize [file join [file dirname [info script]] ../../..]]
create_project -in_memory -part xc7a35tcpg236-1
set_property source_mgmt_mode All [current_project]
foreach name {pwm_deadtime pwm_core pwm_axi_lite pwm_system_axi} {
    add_files -norecurse [file join $root src design pwm ${name}.sv]
}
update_compile_order -fileset sources_1
create_bd_design pwm_interface_check
create_bd_cell -type module -reference pwm_system_axi pwm
set axi [get_bd_intf_pins -quiet pwm/S_AXI]
if {[llength $axi] != 1} { error "No se reconocio la interfaz S_AXI." }
if {[get_property CONFIG.PROTOCOL $axi] ne "AXI4LITE"} { error "Protocolo distinto de AXI4LITE." }
foreach name {s_axi_aclk s_axi_aresetn pwm_ah pwm_al pwm_bh pwm_bl pwm_trigger_o pwm_period_start_o} {
    if {[llength [get_bd_pins -quiet pwm/$name]] != 1} { error "Puerto ausente: $name" }
}
puts "PWM_BD_INTERFACE_PASSED"
puts "S_AXI: [get_property CONFIG.PROTOCOL $axi]"
