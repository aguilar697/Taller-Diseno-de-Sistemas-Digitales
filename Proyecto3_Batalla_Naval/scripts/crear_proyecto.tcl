# Proyecto reproducible de Basys 3. El modelo funcional de reloj queda deshabilitado.
set project_root [file normalize [file join [file dirname [info script]] ..]]
set output_dir [file join $project_root build proyecto_vivado]
create_project batalla_naval $output_dir -part xc7a35tcpg236-1
set_property target_language Verilog [current_project]
# La licencia BASIC permite el flujo completo sin compilación incremental.
foreach run_name {synth_1 impl_1} {
    set_property INCREMENTAL_CHECKPOINT {} [get_runs $run_name]
    set_property AUTO_INCREMENTAL_CHECKPOINT 0 [get_runs $run_name]
}
set_property WRITE_INCREMENTAL_SYNTH_CHECKPOINT 0 [get_runs synth_1]

proc sv_files {directory} {
    set result [glob -nocomplain -directory $directory *.sv]
    foreach child [glob -nocomplain -types d -directory $directory *] {
        set result [concat $result [sv_files $child]]
    }
    return [lsort $result]
}

set design_files [sv_files [file join $project_root src design]]
add_files -norecurse $design_files
set_property file_type SystemVerilog [get_files *.sv]
import_ip -files [file join $project_root src design vga ip pixel_clock_wiz.xci]
set_property generate_synth_checkpoint false [get_files *.xci]
generate_target all [get_ips pixel_clock_wiz]

add_files -fileset constrs_1 -norecurse [file join $project_root src constraints basys3_battleship.xdc]
add_files -norecurse [file join $project_root src software_riscv program.hex]
set_property file_type {Memory Initialization Files} [get_files program.hex]
set_property top basys3_top [get_filesets sources_1]

set test_files [sv_files [file join $project_root src testbench]]
add_files -fileset sim_1 -norecurse $test_files
set_property file_type SystemVerilog [get_files *.sv]
# La definición pixel_clock_wiz de este archivo no participa en Vivado.
set model [get_files pixel_clock_wiz_sim.sv]
set_property used_in_synthesis false $model
set_property used_in_simulation false $model
set_property used_in_implementation false $model
add_files -fileset sim_1 -norecurse [file join $project_root src testbench memory program_rom_tb.hex]
add_files -fileset sim_1 -norecurse [file join $project_root src testbench integration guion.txt]
set_property file_type {Data Files} [get_files guion.txt]
set_property top cpu_tb [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "PROYECTO [file join $output_dir batalla_naval.xpr]"
