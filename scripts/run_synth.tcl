if { [llength $argv] < 2 } {
    error "Usage: vivado -mode tcl run_synth.tcl --tclargs <PROJECT_NAME> <JOBS>"
}

set PROJECT_NAME [lindex $argv 0]
set JOBS         [lindex $argv 1]

open_project project/${PROJECT_NAME}.xpr
reset_run   synth_1
launch_runs synth_1 -jobs $JOBS
wait_on_run synth_1
