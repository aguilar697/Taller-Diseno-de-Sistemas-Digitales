# Validaciones ejecutables de parametros y conexiones, no solo capturas del BD.
proc verify_platform {output} {
    require_equal [get_property PART [current_project]] xc7a35tcpg236-1 FPGA
    validate_bd_design -force
    foreach {key expected} {
        C_FREQ 100000000 C_DATA_SIZE 32 C_USE_FPU 1 C_USE_MULDIV 1
        C_DEBUG_ENABLED 1 C_I_LMB 0 C_D_LMB 1 C_D_AXI 1
        C_USE_ICACHE 1 C_ICACHE_BYTE_SIZE 8192 C_USE_DCACHE 0 C_USE_INTERRUPT 1
    } {require_equal [get_property CONFIG.$key [get_bd_cells mbv]] $expected $key}
    foreach {key expected} {Memory_Type True_Dual_Port_RAM Write_Width_A 32 Write_Depth_A 8192} {
        require_equal [get_property CONFIG.$key [get_bd_cells mbv_local_memory/lmb_bram]] $expected $key
    }
    foreach {key expected} {C_BAUDRATE 115200 C_DATA_BITS 8 C_USE_PARITY 0} {
        require_equal [get_property CONFIG.$key [get_bd_cells uart]] $expected $key
    }
    require_equal [get_property CONFIG.C_EXT_RESET_HIGH [get_bd_cells rst_clk_wiz_1_100M]] 1 RESET_EXTERNO_ACTIVO_ALTO
    foreach {key expected} {COUNT_WIDTH 32 enable_timer2 1 mode_64bit 0} {
        require_equal [get_property CONFIG.$key [get_bd_cells timer]] $expected TIMER_$key
    }
    foreach {cell width1 width2 direction} {gpio_inputs 3 2 INPUTS gpio_outputs 4 1 OUTPUTS} {
        foreach {key expected} [list C_IS_DUAL 1 C_GPIO_WIDTH $width1 C_GPIO2_WIDTH $width2 \
            C_ALL_$direction 1 C_ALL_${direction}_2 1 C_INTERRUPT_PRESENT 0] {
            require_equal [get_property CONFIG.$key [get_bd_cells $cell]] $expected ${cell}_$key
        }
    }
    require_equal [get_property CONFIG.ADDR_WIDTH [get_bd_cells adc]] 12 ADC_DIRECCION_LOCAL
    require_equal [get_property CONFIG.PROTOCOL [get_bd_intf_pins adc/s_axi]] AXI4LITE ADC_AXI4LITE
    require_equal [get_property CONFIG.DATA_WIDTH [get_bd_intf_pins adc/s_axi]] 32 ADC_DATOS
    require_equal [get_property CONFIG.C_HAS_FAST [get_bd_cells mbv_axi_intc]] 0 INTC_NORMAL
    require_equal [get_property CONFIG.NUM_PORTS [get_bd_cells mbv_xlconcat]] 1 IRQ_SOLO_TIMER
    if {[get_property CONFIG.C_KIND_OF_INTR [get_bd_cells mbv_axi_intc]] != 0} {
        error "INTC debe usar entrada sensible a nivel"
    }
    require_equal [get_property CONFIG.NUM_SI [get_bd_cells mbv_axi_periph]] 1 SMARTCONNECT_MAESTROS
    require_equal [get_property CONFIG.NUM_MI [get_bd_cells mbv_axi_periph]] 7 SMARTCONNECT_DESTINOS
    require_equal [get_property CONFIG.PROTOCOL [get_bd_intf_pins pwm/S_AXI]] AXI4LITE PWM_PROTOCOLO
    require_equal [get_property CONFIG.DATA_WIDTH [get_bd_intf_pins pwm/S_AXI]] 32 PWM_DATOS
    foreach {key expected} {ADDR_WIDTH 12 MOD_LIMIT_Q15 27853 MIN_ON_CYCLES 100} {
        require_equal [get_property CONFIG.$key [get_bd_cells pwm]] $expected PWM_$key
    }
    foreach sink {gpio_inputs/s_axi_aclk gpio_outputs/s_axi_aclk timer/s_axi_aclk adc/s_axi_aclk pwm/s_axi_aclk} {
        require_equal [get_bd_nets -of_objects [get_bd_pins clk_wiz_1/clk_out1]] \
            [get_bd_nets -of_objects [get_bd_pins $sink]] "RELOJ $sink"
    }
    foreach sink {gpio_inputs/s_axi_aresetn gpio_outputs/s_axi_aresetn timer/s_axi_aresetn adc/s_axi_aresetn pwm/s_axi_aresetn} {
        require_equal [get_bd_nets -of_objects [get_bd_pins rst_clk_wiz_1_100M/peripheral_aresetn]] \
            [get_bd_nets -of_objects [get_bd_pins $sink]] "RESET $sink"
    }
    foreach port {pwm_ah pwm_al pwm_bh pwm_bl pwm_period_start_o} {
        require_equal [get_property DIR [get_bd_ports $port]] O PWM_SALIDA_$port
        require_equal [get_bd_nets -of_objects [get_bd_pins pwm/$port]] \
            [get_bd_nets -of_objects [get_bd_ports $port]] PWM_PUERTO_$port
    }
    foreach {key expected} {C_BASE_VECTORS 0 C_ICACHE_BASEADDR 0 C_ICACHE_HIGHADDR 32767} {
        set actual [get_property CONFIG.$key [get_bd_cells mbv]]
        if {$actual != $expected} {error "Rango de arranque/cache incorrecto: $key=$actual"}
    }
    foreach {a b} {
        clk_wiz_1/locked rst_clk_wiz_1_100M/dcm_locked
        rst_clk_wiz_1_100M/mb_reset mbv/Reset
        rst_clk_wiz_1_100M/peripheral_aresetn instruction_bram_ctrl/s_axi_aresetn
        timer/interrupt mbv_xlconcat/In0
        mbv_xlconcat/dout mbv_axi_intc/intr
        clk_wiz_1/clk_out1 adc/s_axi_aclk
        rst_clk_wiz_1_100M/peripheral_aresetn adc/s_axi_aresetn
        pwm/pwm_trigger_o adc/pwm_trigger_i
    } {
        require_equal [get_bd_nets -of_objects [get_bd_pins $a]] \
            [get_bd_nets -of_objects [get_bd_pins $b]] "CONEXION $a -> $b"
    }
    foreach {a b} {
        mbv/M_AXI_IC instruction_bram_ctrl/S_AXI
        mbv/M_AXI_DP mbv_axi_periph/S00_AXI
        mbv/DLMB mbv_local_memory/DLMB
        instruction_bram_ctrl/BRAM_PORTA mbv_local_memory/BRAM_PORTB
        mbv/DEBUG mdm_1/MBDEBUG_0
        mbv/INTERRUPT mbv_axi_intc/interrupt
        mbv_axi_periph/M00_AXI mbv_axi_intc/s_axi
        mbv_axi_periph/M01_AXI timer/S_AXI
        mbv_axi_periph/M02_AXI uart/S_AXI
        mbv_axi_periph/M03_AXI gpio_inputs/S_AXI
        mbv_axi_periph/M04_AXI gpio_outputs/S_AXI
        mbv_axi_periph/M05_AXI adc/s_axi
        mbv_axi_periph/M06_AXI pwm/S_AXI
        mbv_local_memory/dlmb_bram_if_cntlr/BRAM_PORT mbv_local_memory/lmb_bram/BRAM_PORTA
    } {
        require_equal [get_bd_intf_nets -of_objects [get_bd_intf_pins $a]] \
            [get_bd_intf_nets -of_objects [get_bd_intf_pins $b]] "INTERFAZ $a -> $b"
    }
    # El pin de jerarquia tiene redes distintas en cada cara. Comparar la cara
    # interna (lower), no su nombre de red externo contra el interno.
    require_equal [get_bd_intf_nets -boundary_type lower -of_objects [get_bd_intf_pins mbv_local_memory/BRAM_PORTB]] \
        [get_bd_intf_nets -of_objects [get_bd_intf_pins mbv_local_memory/lmb_bram/BRAM_PORTB]] BRAM_PUERTO_B_INTERNO
    foreach {segment base range} {
        mbv/Data/SEG_dlmb_bram_if_cntlr_Mem 0x00000000 0x8000
        mbv/Instruction/SEG_instruction_bram_ctrl_Mem0 0x00000000 0x8000
        mbv/Data/SEG_gpio_inputs_Reg 0x40000000 0x10000
        mbv/Data/SEG_gpio_outputs_Reg 0x40010000 0x10000
        mbv/Data/SEG_uart_Reg 0x40600000 0x10000
        mbv/Data/SEG_mbv_axi_intc_Reg 0x41200000 0x10000
        mbv/Data/SEG_timer_Reg 0x41C00000 0x10000
        mbv/Data/SEG_adc_reg0 0x44A00000 0x1000
        mbv/Data/SEG_pwm_reg0 0x44000000 0x1000
    } {
        set seg [get_bd_addr_segs $segment]
        if {[get_property OFFSET $seg] != $base || [get_property RANGE $seg] != $range} {
            error "Mapa distinto del esperado: $segment"
        }
    }
    # Comparar segmentos de datos entre si, no contra la vista de instrucciones
    # que representa intencionadamente la misma BRAM fisica.
    set intervals {}
    foreach seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces mbv/Data]] {
        set first [expr {[get_property OFFSET $seg] + 0}]
        set last [expr {$first + [get_property RANGE $seg] - 1}]
        foreach interval $intervals {
            lassign $interval old_first old_last old_name
            if {$first <= $old_last && $last >= $old_first} {
                error "Solapamiento de datos: $seg y $old_name"
            }
        }
        lappend intervals [list $first $last $seg]
    }
    file mkdir $output/reports
    set fh [open $output/reports/bd_configuration.txt w]
    puts $fh "VIVADO=[version -short] PART=[get_property PART [current_project]]"
    puts $fh "ADC_REFERENCE=adc_system_axi ADDR_WIDTH=[get_property CONFIG.ADDR_WIDTH [get_bd_cells adc]]"
    puts $fh "ADC_PROTOCOL=[get_property CONFIG.PROTOCOL [get_bd_intf_pins adc/s_axi]]"
    puts $fh "PWM_REFERENCE=pwm_system_axi; BASE=0x44000000 RANGE=0x1000; ADC_TRIGGER=PWM_REAL"
    foreach port [get_bd_ports] {
        puts $fh "PUERTO=$port DIR=[get_property DIR $port]"
    }
    foreach cell [get_bd_cells -hier -filter {TYPE == ip}] {
        puts $fh "IP=$cell VLNV=[get_property VLNV $cell]"
        foreach key [lsort [list_property $cell]] {
            if {[string match CONFIG.* $key]} {puts $fh "$key=[get_property $key $cell]"}
        }
    }
    foreach space {mbv/Data mbv/Instruction} {
        foreach seg [get_bd_addr_segs -of_objects [get_bd_addr_spaces $space]] {
            puts $fh "SEG=$seg OFFSET=[get_property OFFSET $seg] RANGE=[get_property RANGE $seg]"
        }
    }
    puts $fh "VALIDATE_BD_DESIGN=PASS; CONFIGURACION_Y_CONEXIONES=PASS"
    close $fh
}
