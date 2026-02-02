if { [llength $argv] < 9 } {
    error "Usage: vivado -mode tcl create_project.tcl --tclargs <PROJECT_NAME> <FPGA_BOARD_REPO_PATH> <FPGA_PART> <FPGA_BOARD_PART> <FPGA_TOP_MODULE> \"<SYN_FILES>\" \"<SIM_FILES>\" \"<XDC_FILES>\" \"<IP_TCL_FILES>\""
}

set PROJECT_NAME         [lindex $argv 0]
set FPGA_BOARD_REPO_PATH [lindex $argv 1]
set FPGA_PART            [lindex $argv 2]
set FPGA_BOARD_PART      [lindex $argv 3]
set FPGA_TOP_MODULE      [lindex $argv 4]
set SYN_FILES    [split [lindex $argv 5] " "]
set SIM_FILES    [split [lindex $argv 6] " "]
set XDC_FILES    [split [lindex $argv 7] " "]
set IP_TCL_FILES [split [lindex $argv 8] " "]

set_param board.repoPaths $FPGA_BOARD_REPO_PATH

create_project project/$PROJECT_NAME .

set_property part $FPGA_PART [current_project]
set_property board_part $FPGA_BOARD_PART [current_project]

if {[llength $SYN_FILES] > 0} {
    add_files -fileset sources_1 $SYN_FILES
}

if {[llength $SIM_FILES] > 0} {
    add_files -fileset sim_1 $SIM_FILES
}

if {[llength $XDC_FILES] > 0} {
    add_files -fileset constrs_1 $XDC_FILES
}

set_property top $FPGA_TOP_MODULE [current_fileset]

if {[llength $IP_TCL_FILES] > 0} {
    foreach file $IP_TCL_FILES {
        source $file
    }
}
