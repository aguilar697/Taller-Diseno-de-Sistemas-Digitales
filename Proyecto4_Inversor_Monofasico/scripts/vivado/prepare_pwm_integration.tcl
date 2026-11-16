# Integracion digital invocada desde create_project.tcl/create_bd.tcl.
# El XDC de plataforma fija JC1/2/3/4/7 para validacion digital, sin potencia.
# Toda conexion fisica posterior requiere validacion electrica del equipo.
proc prepare_pwm_sources {source_root} {
    set_property source_mgmt_mode All [current_project]
    foreach name {pwm_deadtime pwm_core pwm_axi_lite pwm_system_axi} {
        set source [file join $source_root src design pwm ${name}.sv]
        if {![file isfile $source]} {error "Fuente PWM ausente: $source"}
        add_files -norecurse [list $source]
    }
    update_compile_order -fileset sources_1
}

proc integrate_pwm_digital {} {
    if {[llength [get_bd_cells -quiet pwm]]} {error "PWM ya instanciado"}
    if {[get_property CONFIG.NUM_MI [get_bd_cells mbv_axi_periph]] != 6} {
        error "Se esperaba SmartConnect con seis destinos antes de agregar PWM"
    }
    create_bd_cell -type module -reference pwm_system_axi pwm
    # El modulo usa comparacion completa de offsets. Doce bits evitan alias
    # dentro de la ventana minima inferida de 4 KiB, sin editar RTL de Kevin.
    set_property CONFIG.ADDR_WIDTH 12 [get_bd_cells pwm]
    set_property CONFIG.NUM_MI 7 [get_bd_cells mbv_axi_periph]
    connect_bd_intf_net [get_bd_intf_pins mbv_axi_periph/M06_AXI] [get_bd_intf_pins pwm/S_AXI]
    connect_bd_net [get_bd_pins clk_wiz_1/clk_out1] [get_bd_pins pwm/s_axi_aclk]
    connect_bd_net [get_bd_pins rst_clk_wiz_1_100M/peripheral_aresetn] [get_bd_pins pwm/s_axi_aresetn]
    set old_trigger [get_bd_nets -of_objects [get_bd_pins adc/pwm_trigger_i]]
    disconnect_bd_net $old_trigger [get_bd_pins adc/pwm_trigger_i]
    connect_bd_net [get_bd_pins pwm/pwm_trigger_o] [get_bd_pins adc/pwm_trigger_i]
    foreach name {pwm_ah pwm_al pwm_bh pwm_bl pwm_period_start_o} {
        create_bd_port -dir O $name
        connect_bd_net [get_bd_pins pwm/$name] [get_bd_ports $name]
    }
    set segments [get_bd_addr_segs -of_objects [get_bd_intf_pins pwm/S_AXI]]
    if {[llength $segments] != 1} {error "Segmento PWM inferido no es unico: $segments"}
    assign_bd_address -offset 0x44000000 -range 0x1000 \
        -target_address_space [get_bd_addr_spaces mbv/Data] $segments
    puts "PWM conectado digitalmente; JC1/2/3/4/7 definidos en XDC. Validar pines, BD, mapa y reset; sin potencia."
}
