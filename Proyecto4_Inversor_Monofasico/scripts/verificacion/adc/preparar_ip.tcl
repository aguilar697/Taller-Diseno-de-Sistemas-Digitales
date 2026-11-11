# Regenera el XADC dentro de build; nunca abre ni modifica el proyecto de origen.
if {$argc != 1} { error {Uso: preparar_ip.tcl <directorio_nuevo_de_salida>} }
set adc_root [file normalize [file join [file dirname [info script]] ../../..]]
set adc_out [file normalize [lindex $argv 0]]
set adc_build [file normalize [file join $adc_root build adc]]
if {![string equal -nocase [string range $adc_out 0 [string length $adc_build]] "${adc_build}/"]} {
    error {La salida debe estar dentro de build/adc del Proyecto 4.}
}
if {[file exists $adc_out]} { error "La salida ya existe: $adc_out" }
if {[version -short] ne "2026.1"} {
    error {Flujo validado en Vivado 2026.1. Verificar compatibilidad antes de usar otra version.}
}
file mkdir $adc_out
create_project adc_repro [file join $adc_out project] -part xc7a35tcpg236-1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
# import_ip copia y adapta los metadatos de rutas; el XCI versionado se conserva intacto.
set adc_xci [file join $adc_root src design adc ip xadc_wiz_0 xadc_wiz_0.xci]
import_ip -files [list $adc_xci]
set adc_ip [get_ips xadc_wiz_0]
if {[llength $adc_ip] != 1} { error {No se encontro un unico xadc_wiz_0.} }
generate_target all $adc_ip
set adc_wrapper {}
foreach adc_file [get_files -all -of_objects $adc_ip] {
    if {[file tail $adc_file] eq "xadc_wiz_0.v"} { set adc_wrapper [file normalize $adc_file] }
}
if {$adc_wrapper eq {} || ![file exists $adc_wrapper]} { error {No se genero xadc_wiz_0.v.} }
set adc_manifest [open [file join $adc_out wrapper.txt] w]
puts $adc_manifest $adc_wrapper
close $adc_manifest
report_ip_status -file [file join $adc_out ip_status.rpt]
close_project
puts {ADC_IP_GENERATED_IN_BUILD}
