if { [llength $argv] < 2 } {
    error "Usage: vivado -mode tcl run_impl.tcl --tclargs <PROJECT_NAME> <JOBS>"
}

set PROJECT_NAME [lindex $argv 0]
set JOBS         [lindex $argv 1]

open_project project/${PROJECT_NAME}.xpr

set synth_1_status [get_property STATUS [get_runs synth_1]]
if {$synth_1_status != "synth_design Complete!"} {
    error "synth_1 was not completed"
}

reset_run   impl_1
launch_runs impl_1 -to_step route_design -jobs $JOBS
wait_on_run impl_1
