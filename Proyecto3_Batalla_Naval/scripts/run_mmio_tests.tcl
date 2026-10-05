# Ejecuta las pruebas MMIO con Vivado/XSim sin depender de un proyecto existente.
set script_dir [file dirname [file normalize [info script]]]
set project_root [file normalize [file join $script_dir ".."]]
set work_root [file normalize [file join $::env(TEMP) "batalla_naval_mmio_xsim"]]

file mkdir $work_root
create_project mmio_tests $work_root -force -part xc7a35tcpg236-1
set_property target_language Verilog [current_project]

set design_sources [list \
    [file join $project_root src design memory data_ram.sv] \
    [file join $project_root src design bus address_decoder.sv] \
    [file join $project_root src design bus data_bus.sv] \
    [file join $project_root src design uart uart_tx.sv] \
    [file join $project_root src design uart uart_rx.sv] \
    [file join $project_root src design uart uart_peripheral.sv] \
    [file join $project_root src design outputs sevenseg_driver.sv] \
    [file join $project_root src design outputs sevenseg_peripheral.sv] \
    [file join $project_root src design outputs led_peripheral.sv] \
    [file join $project_root src design outputs buzzer_peripheral.sv]]

set test_sources [list \
    [file join $project_root src testbench memory data_ram_tb.sv] \
    [file join $project_root src testbench bus address_decoder_tb.sv] \
    [file join $project_root src testbench bus data_bus_tb.sv] \
    [file join $project_root src testbench uart uart_tx_tb.sv] \
    [file join $project_root src testbench uart uart_rx_tb.sv] \
    [file join $project_root src testbench uart uart_peripheral_tb.sv] \
    [file join $project_root src testbench outputs sevenseg_peripheral_tb.sv] \
    [file join $project_root src testbench outputs led_peripheral_tb.sv] \
    [file join $project_root src testbench outputs buzzer_peripheral_tb.sv] \
    [file join $project_root src testbench integration mmio_subsystem_integration_tb.sv]]

add_files -fileset sources_1 $design_sources
add_files -fileset sim_1 $test_sources
set_property file_type SystemVerilog [get_files [concat $design_sources $test_sources]]

set testbenches [list \
    data_ram_tb \
    address_decoder_tb \
    data_bus_tb \
    uart_tx_tb \
    uart_rx_tb \
    uart_peripheral_tb \
    sevenseg_peripheral_tb \
    led_peripheral_tb \
    buzzer_peripheral_tb \
    mmio_subsystem_integration_tb]

foreach testbench $testbenches {
    puts "============================================================"
    puts "Ejecutando $testbench"
    puts "============================================================"
    set_property top $testbench [get_filesets sim_1]
    update_compile_order -fileset sim_1

    if {[catch {launch_simulation -simset sim_1 -mode behavioral} message]} {
        puts stderr "ERROR al iniciar $testbench: $message"
        exit 1
    }
    if {[catch {run all} message]} {
        puts stderr "ERROR durante $testbench: $message"
        close_sim -force
        exit 1
    }
    close_sim -force
}

puts "Todas las simulaciones MMIO finalizaron. Revise los mensajes ALL TESTS PASSED."
close_project
