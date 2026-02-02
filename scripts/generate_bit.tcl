if { [llength $argv] < 1 } {
    error "Usage: vivado -mode tcl generate_bit.tcl --tclargs <PROJECT_NAME>"
}

set PROJECT_NAME [lindex $argv 0]

open_project project/${PROJECT_NAME}.xpr

set impl_1_status [get_property STATUS [get_runs impl_1]]
if {$impl_1_status != "route_design Complete!"} {
    error "impl_1 was not completed"
}

open_run impl_1
write_bitstream -force ${PROJECT_NAME}.bit
