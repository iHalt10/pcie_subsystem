if { [llength $argv] < 1 } {
    error "Usage: vivado -mode tcl generate_mcs.tcl --tclargs <PROJECT_NAME>"
}

set PROJECT_NAME [lindex $argv 0]

set interface SPIx4
set mem_size 256
set start_address 0x01002000

write_cfgmem -format mcs -interface $interface -size $mem_size -loadbit "up $start_address ${PROJECT_NAME}.bit" -file "${PROJECT_NAME}.msc"
