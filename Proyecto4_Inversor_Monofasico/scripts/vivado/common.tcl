# Funciones compartidas. Solo se admite la version comprobada de Vivado.
set platform_source_root [file normalize [file join [file dirname [info script]] ../..]]

proc require_vivado_version {} {
    if {[version -short] ne "2026.1"} {
        error "Se requiere Vivado 2026.1. La compatibilidad con 2025.1 no esta comprobada."
    }
}

proc require_external_directory {path} {
    global platform_source_root
    set path [file normalize $path]
    set repository [file normalize [file join $platform_source_root ..]]
    set lower_path [string tolower [string map {\\ /} $path]]
    set lower_repo [string tolower [string map {\\ /} $repository]]
    if {$lower_path eq $lower_repo || [string first "$lower_repo/" "$lower_path/"] == 0} {
        error "Los productos deben escribirse fuera del repositorio: $path"
    }
    return $path
}

proc require_equal {actual expected label} {
    if {$actual ne $expected} {error "${label}: obtenido=$actual esperado=$expected"}
}

proc configure_runs {} {
    # BASIC: no depender de checkpoints incrementales sujetos a otra licencia.
    foreach run [get_runs] {
        foreach {prop value} {
            AUTO_INCREMENTAL_CHECKPOINT 0
            INCREMENTAL_CHECKPOINT {}
            WRITE_INCREMENTAL_SYNTH_CHECKPOINT 0
        } {
            if {[lsearch -exact [list_property $run] $prop] >= 0} {
                set_property $prop $value $run
            }
        }
    }
}

proc platform_reports {directory} {
    file mkdir $directory
    report_utilization -file $directory/utilization.rpt
    report_clocks -file $directory/clocks.rpt
    check_timing -verbose -file $directory/check_timing.rpt
    report_exceptions -file $directory/exceptions.rpt
    report_drc -file $directory/drc.rpt
    report_methodology -file $directory/methodology.rpt
    report_cdc -details -all_checks_per_endpoint -no_waiver -file $directory/cdc.rpt
    report_timing_summary -delay_type min_max -report_unconstrained -file $directory/timing.rpt
    report_io -file $directory/io.rpt
}
