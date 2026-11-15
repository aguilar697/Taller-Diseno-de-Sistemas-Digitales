# Añade las fuentes al proyecto abierto. No ejecuta síntesis ni cambia el top global.
# En la consola Tcl de Vivado: source ruta/a/agregar_pwm.tcl
if {[current_project -quiet] eq ""} { error "Abra primero el proyecto de integracion." }
set pwm_root [file normalize [file join [file dirname [info script]] ../../..]]
foreach pwm_name {pwm_deadtime pwm_core pwm_axi_lite pwm_system_axi} {
    add_files -norecurse [file join $pwm_root src design pwm ${pwm_name}.sv]
}
update_compile_order -fileset sources_1
puts "PWM agregado. Top del periferico: pwm_system_axi; interfaz: S_AXI."
puts "Conectar s_axi_aclk a 100 MHz y s_axi_aresetn al reset AXI."
