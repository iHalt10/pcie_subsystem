################################################################################
# Makefile for vivado Project
#
# quick usage:
#   $ make project     # Create vivado project
#   $ make build       # Run synth, impl, bit, mcs in sequence
#   $ make synth       # Run synthesis
#   $ make impl        # Run implementation
#   $ make bit         # Generate bitstream file
#   $ make program-bit # Program FPGA with bitstream
#   $ make mcs         # Generate MCS file
#   $ make program-mcs # Program flash memory with MCS file
#   $ make ide         # Open vivado GUI
#   $ make clean-log   # Remove vivado log files
#   $ make clean       # Remove all generated files
################################################################################
.PHONY: default project build synth impl bit program-bit mcs program-mcs ide clean-log clean

PROJECT_NAME         := pcie_subsystem_tester
FPGA_BOARD_REPO_PATH := $(abspath ./boards_files)
FPGA_PART            := xcu50-fsvh2104-2-e
FPGA_BOARD_PART      := xilinx.com:au50:part0:1.3
FPGA_TOP_MODULE      := fpga_au50
NUM_JOBS_PARALLEL    := $(shell nproc)
PROGRAM_HW_SERVER    := 127.0.0.1:3121
PROGRAM_DEVICE_NAME  := xcu50_u55n_0
PROGRAM_FLASH_PART   := mt25qu01g-spi-x1_x2_x4

SYN_ROOT    := rtl
TB_ROOT     := tb
XDC_ROOT    := constraints
IP_TCL_ROOT := ip

SYN_FILES    := $(shell find $(SYN_ROOT)    -type f -name "*.v" -o -name "*.vh" -o -name "*.sv" -o -name "*.svh")
TB_FILES     := $(shell find $(TB_ROOT)     -type f -name "*.sv")
XDC_FILES    := $(shell find $(XDC_ROOT)    -type f -name "*.xdc") project/run_params.xdc
IP_TCL_FILES := $(shell find $(IP_TCL_ROOT) -type f -name "*.tcl")

default: project build

project: project/$(PROJECT_NAME).xpr

project/$(PROJECT_NAME).xpr:
	mkdir -p project
	touch project/run_params.xdc
	vivado -mode batch -source scripts/create_project.tcl -tclargs $(PROJECT_NAME) $(FPGA_BOARD_REPO_PATH) $(FPGA_PART) $(FPGA_BOARD_PART) $(FPGA_TOP_MODULE) "$(SYN_FILES)" "$(TB_FILES)" "$(XDC_FILES)" "$(IP_TCL_FILES)"

build: synth

synth:
	vivado -mode batch -source scripts/run_synth.tcl -tclargs $(PROJECT_NAME) $(NUM_JOBS_PARALLEL)

impl:
	vivado -mode batch -source scripts/run_impl.tcl -tclargs $(PROJECT_NAME) $(NUM_JOBS_PARALLEL)

$(PROJECT_NAME).bit:
	vivado -mode batch -source scripts/generate_bit.tcl -tclargs $(PROJECT_NAME)

bit: $(PROJECT_NAME).bit

program-bit: $(PROJECT_NAME).bit
	vivado -mode batch -source scripts/program_bit.tcl -tclargs $(PROGRAM_HW_SERVER) $(PROGRAM_DEVICE_NAME) $(PROJECT_NAME).bit

$(PROJECT_NAME).mcs: $(PROJECT_NAME).bit
	vivado -mode batch -source scripts/generate_mcs.tcl -tclargs $(PROJECT_NAME)

mcs: $(PROJECT_NAME).mcs

program-mcs: $(PROJECT_NAME).mcs
	vivado -mode batch -source scripts/program_mcs.tcl -tclargs $(PROGRAM_HW_SERVER) $(PROGRAM_DEVICE_NAME) $(PROJECT_NAME).mcs $(PROGRAM_FLASH_PART)

ide: project/$(PROJECT_NAME).xpr
	vivado project/$(PROJECT_NAME).xpr &

clean-log:
	rm -f vivado*.log vivado*.jou vivado*.str 

clean: clean-log
	rm -f $(PROJECT_NAME).bit
	rm -f $(PROJECT_NAME).mcs
	rm -f $(PROJECT_NAME).prm
	rm -rf project
	rm -rf .Xil
