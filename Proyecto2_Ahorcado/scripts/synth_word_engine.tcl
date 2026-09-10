# Run: vivado -mode batch -source scripts/synth_word_engine.tcl
# Standalone synthesis of S2. This is NOT the required integrated timing simulation.
set project_root [file normalize [file join [file dirname [info script]] ..]]
set_param general.maxThreads 1
cd $project_root
set out_dir [file join $project_root build word_engine]
file mkdir $out_dir
foreach name {word_lfsr word_rom letter_evaluator word_engine} {
    read_verilog -sv [list [file join $project_root src design word_engine ${name}.sv]]
}
synth_design -top word_engine -part xc7a35tcpg236-1 -mode out_of_context
create_clock -name clk -period 10.000 [get_ports clk]
report_utilization -file [file join $out_dir utilization_synth.rpt]
report_timing_summary -file [file join $out_dir timing_synth.rpt]
set latch_count [llength [get_cells -hier -filter {REF_NAME =~ LD*}]]
puts "WORD_ENGINE_LATCH_COUNT=$latch_count"
if {$latch_count != 0} { error "Unexpected inferred latches" }
write_checkpoint -force [file join $out_dir word_engine_synth.dcp]
puts "PASS: standalone word_engine synthesis; inspect reports for integration limits"
