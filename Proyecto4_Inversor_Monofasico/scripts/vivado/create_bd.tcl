# Topologia C explorada: una BRAM fisica, datos DLMB e instrucciones AXI/cache.
# Se invoca desde create_project.tcl; sin automatizaciones dependientes de placa.
create_bd_design platform_microblaze
foreach {name bus} {UART_0 uart GPIO_0 gpio GPIO2_0 gpio} {
    create_bd_intf_port -mode Master -vlnv xilinx.com:interface:${bus}_rtl:1.0 $name
}
create_bd_port -dir I -type clk -freq_hz 100000000 clk_i
create_bd_port -dir I -type rst reset_i
set_property CONFIG.POLARITY ACTIVE_HIGH [get_bd_ports reset_i]

create_bd_cell -type ip -vlnv xilinx.com:ip:microblaze_riscv:1.0 mbv
set_property -dict [list CONFIG.C_DATA_SIZE 32 CONFIG.C_DEBUG_ENABLED 1 \
    CONFIG.C_D_AXI 1 CONFIG.C_D_LMB 1 CONFIG.C_I_LMB 0 \
    CONFIG.C_USE_FPU 1 CONFIG.C_USE_MULDIV 1 CONFIG.C_USE_INTERRUPT 1 \
    CONFIG.C_USE_ICACHE 1 CONFIG.C_ICACHE_BYTE_SIZE 8192 CONFIG.C_USE_DCACHE 0 \
    CONFIG.C_ICACHE_BASEADDR 0x0000000000000000 \
    CONFIG.C_ICACHE_HIGHADDR 0x0000000000007fff] [get_bd_cells mbv]

create_bd_cell -type hier mbv_local_memory
current_bd_instance mbv_local_memory
create_bd_intf_pin -mode MirroredMaster -vlnv xilinx.com:interface:lmb_rtl:1.0 DLMB
create_bd_intf_pin -mode Slave -vlnv xilinx.com:interface:bram_rtl:1.0 BRAM_PORTB
create_bd_pin -dir I -type clk LMB_Clk
create_bd_pin -dir I -type rst SYS_Rst
create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_v10:3.0 dlmb_v10
create_bd_cell -type ip -vlnv xilinx.com:ip:lmb_bram_if_cntlr:4.0 dlmb_bram_if_cntlr
set_property CONFIG.C_ECC 0 [get_bd_cells dlmb_bram_if_cntlr]
create_bd_cell -type ip -vlnv xilinx.com:ip:blk_mem_gen:8.4 lmb_bram
set_property -dict [list CONFIG.Memory_Type True_Dual_Port_RAM \
    CONFIG.use_bram_block BRAM_Controller] [get_bd_cells lmb_bram]
foreach {a b} {DLMB dlmb_v10/LMB_M dlmb_v10/LMB_Sl_0 dlmb_bram_if_cntlr/SLMB \
    dlmb_bram_if_cntlr/BRAM_PORT lmb_bram/BRAM_PORTA BRAM_PORTB lmb_bram/BRAM_PORTB} {
    connect_bd_intf_net [get_bd_intf_pins $a] [get_bd_intf_pins $b]
}
connect_bd_net [get_bd_pins LMB_Clk] [get_bd_pins dlmb_v10/LMB_Clk] [get_bd_pins dlmb_bram_if_cntlr/LMB_Clk]
connect_bd_net [get_bd_pins SYS_Rst] [get_bd_pins dlmb_v10/SYS_Rst] [get_bd_pins dlmb_bram_if_cntlr/LMB_Rst]
current_bd_instance /

foreach {name vlnv} {
    mbv_axi_periph smartconnect:1.0
    mbv_axi_intc axi_intc:4.1
    mdm_1 mdm_riscv:1.0
    clk_wiz_1 clk_wiz:6.0
    rst_clk_wiz_1_100M proc_sys_reset:5.0
    timer axi_timer:2.0
    uart axi_uartlite:2.0
    gpio axi_gpio:2.0
    instruction_bram_ctrl axi_bram_ctrl:4.1
} {create_bd_cell -type ip -vlnv xilinx.com:ip:$vlnv $name}
set_property -dict [list CONFIG.NUM_SI 1 CONFIG.NUM_MI 4] [get_bd_cells mbv_axi_periph]
set_property -dict [list CONFIG.C_HAS_FAST 0 CONFIG.C_KIND_OF_INTR 0x00000000] [get_bd_cells mbv_axi_intc]
set_property -dict [list CONFIG.PRIM_IN_FREQ 100.000 CONFIG.CLKOUT1_REQUESTED_OUT_FREQ 100.000 \
    CONFIG.PRIM_SOURCE Single_ended_clock_capable_pin CONFIG.USE_LOCKED true \
    CONFIG.USE_RESET true CONFIG.RESET_TYPE ACTIVE_HIGH] [get_bd_cells clk_wiz_1]
# C_EXT_RESET_HIGH se propaga desde POLARITY del puerto y es de solo lectura.
set_property CONFIG.C_AUX_RESET_HIGH 1 [get_bd_cells rst_clk_wiz_1_100M]
set_property -dict [list CONFIG.C_BAUDRATE 115200 CONFIG.C_DATA_BITS 8 CONFIG.C_USE_PARITY 0] [get_bd_cells uart]
set_property -dict [list CONFIG.C_IS_DUAL 1 CONFIG.C_GPIO_WIDTH 1 CONFIG.C_GPIO2_WIDTH 1 \
    CONFIG.C_ALL_INPUTS 1 CONFIG.C_ALL_OUTPUTS_2 1] [get_bd_cells gpio]
set_property -dict [list CONFIG.DATA_WIDTH 32 CONFIG.SINGLE_PORT_BRAM 1] [get_bd_cells instruction_bram_ctrl]
create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconcat:1.0 mbv_xlconcat
set_property CONFIG.NUM_PORTS 1 [get_bd_cells mbv_xlconcat]
create_bd_cell -type inline_hdl -vlnv xilinx.com:inline_hdl:ilconstant:1.0 zero_inline
set_property -dict [list CONFIG.CONST_WIDTH 1 CONFIG.CONST_VAL 0] [get_bd_cells zero_inline]

foreach {a b} {
    mbv/DLMB mbv_local_memory/DLMB
    mbv/M_AXI_IC instruction_bram_ctrl/S_AXI
    instruction_bram_ctrl/BRAM_PORTA mbv_local_memory/BRAM_PORTB
    mbv/M_AXI_DP mbv_axi_periph/S00_AXI
    mbv_axi_periph/M00_AXI mbv_axi_intc/s_axi
    mbv_axi_periph/M01_AXI timer/S_AXI
    mbv_axi_periph/M02_AXI uart/S_AXI
    mbv_axi_periph/M03_AXI gpio/S_AXI
    mbv/DEBUG mdm_1/MBDEBUG_0
    mbv_axi_intc/interrupt mbv/INTERRUPT
} {connect_bd_intf_net [get_bd_intf_pins $a] [get_bd_intf_pins $b]}
foreach {a b} {UART_0 uart/UART GPIO_0 gpio/GPIO GPIO2_0 gpio/GPIO2} {
    connect_bd_intf_net [get_bd_intf_ports $a] [get_bd_intf_pins $b]
}
connect_bd_net [get_bd_ports clk_i] [get_bd_pins clk_wiz_1/clk_in1]
connect_bd_net [get_bd_ports reset_i] [get_bd_pins clk_wiz_1/reset] [get_bd_pins rst_clk_wiz_1_100M/ext_reset_in]
foreach sink {mbv/Clk mbv_local_memory/LMB_Clk mbv_axi_periph/aclk mbv_axi_intc/s_axi_aclk \
    timer/s_axi_aclk uart/s_axi_aclk gpio/s_axi_aclk instruction_bram_ctrl/s_axi_aclk \
    rst_clk_wiz_1_100M/slowest_sync_clk} {
    connect_bd_net [get_bd_pins clk_wiz_1/clk_out1] [get_bd_pins $sink]
}
foreach sink {mbv_axi_periph/aresetn mbv_axi_intc/s_axi_aresetn timer/s_axi_aresetn \
    uart/s_axi_aresetn gpio/s_axi_aresetn instruction_bram_ctrl/s_axi_aresetn} {
    connect_bd_net [get_bd_pins rst_clk_wiz_1_100M/peripheral_aresetn] [get_bd_pins $sink]
}
foreach {a b} {
    clk_wiz_1/locked rst_clk_wiz_1_100M/dcm_locked
    mdm_1/Debug_SYS_Rst rst_clk_wiz_1_100M/mb_debug_sys_rst
    rst_clk_wiz_1_100M/mb_reset mbv/Reset
    rst_clk_wiz_1_100M/bus_struct_reset mbv_local_memory/SYS_Rst
    zero_inline/dout rst_clk_wiz_1_100M/aux_reset_in
    timer/interrupt mbv_xlconcat/In0
    mbv_xlconcat/dout mbv_axi_intc/intr
} {connect_bd_net [get_bd_pins $a] [get_bd_pins $b]}

# Dos vistas de los mismos 32 KiB fisicos; no son memorias independientes.
foreach {space target offset range} {
    Data mbv_local_memory/dlmb_bram_if_cntlr/SLMB/Mem 0x00000000 0x8000
    Instruction instruction_bram_ctrl/S_AXI/Mem0 0x00000000 0x8000
    Data gpio/S_AXI/Reg 0x40000000 0x10000
    Data uart/S_AXI/Reg 0x40600000 0x10000
    Data mbv_axi_intc/S_AXI/Reg 0x41200000 0x10000
    Data timer/S_AXI/Reg 0x41C00000 0x10000
} {
    assign_bd_address -offset $offset -range $range -target_address_space \
        [get_bd_addr_spaces mbv/$space] [get_bd_addr_segs $target]
}
validate_bd_design -force
save_bd_design
