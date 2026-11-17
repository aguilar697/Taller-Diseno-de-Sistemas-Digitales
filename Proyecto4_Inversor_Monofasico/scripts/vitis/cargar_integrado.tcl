# Descarga por JTAG el bitstream y el ELF de la misma construccion.
# Uso: xsdb cargar_integrado.tcl <bitstream.bit> <programa.elf>
# Mantener SD alto, SW15 bajo y el bus de potencia desconectado.
if {$argc != 2} {error "Uso: cargar_integrado.tcl <bitstream.bit> <programa.elf>"}
set bitstream [file normalize [lindex $argv 0]]
set program [file normalize [lindex $argv 1]]
foreach path [list $bitstream $program] {
    if {![file isfile $path]} {error "No existe: $path"}
}
connect
set fpgas [targets -target-properties -filter {name =~ "xc7a35t*"}]
if {[llength $fpgas] != 1} {
    puts [targets]
    error "No se encontro una unica Basys 3. Compruebe USB y alimentacion."
}
targets -set -filter {name =~ "xc7a35t*"}
fpga -file $bitstream
after 1000
# MicroBlaze V expone el nucleo ejecutable como Hart, debajo del transporte RISC-V.
set cpus [targets -target-properties -filter {name =~ "Hart #*"}]
if {[llength $cpus] == 0} {
    set cpus [targets -target-properties -filter {name =~ "MicroBlaze*"}]
}
if {[llength $cpus] != 1} {
    puts [targets]
    error "No se encontro un unico procesador MicroBlaze V. Revisar la lista de targets."
}
targets -set [dict get [lindex $cpus 0] target_id]
stop
rst -processor
after 100
dow $program
con
puts "ELF descargado. Verificar UART a 115200 8N1 y LED de actividad."
