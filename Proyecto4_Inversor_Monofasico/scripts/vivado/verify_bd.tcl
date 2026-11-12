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
        mbv/Data/SEG_gpio_Reg 0x40000000 0x10000
        mbv/Data/SEG_uart_Reg 0x40600000 0x10000
        mbv/Data/SEG_mbv_axi_intc_Reg 0x41200000 0x10000
        mbv/Data/SEG_timer_Reg 0x41C00000 0x10000
    } {
        set seg [get_bd_addr_segs $segment]
        if {[get_property OFFSET $seg] != $base || [get_property RANGE $seg] != $range} {
            error "Mapa distinto del esperado: $segment"
        }
    }
    file mkdir $output/reports
    set fh [open $output/reports/bd_configuration.txt w]
    puts $fh "VIVADO=[version -short] PART=[get_property PART [current_project]]"
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
