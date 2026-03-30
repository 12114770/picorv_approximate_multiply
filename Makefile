SHELL := bash

BUILD_DIR ?= build
SIM_DIR ?= $(BUILD_DIR)/sim
SYNTH_DIR ?= $(BUILD_DIR)/synth

IVERILOG ?= iverilog
VVP ?= vvp
YOSYS ?= yosys
PYTHON ?= python3

RTL_DIR ?= group8/rtl
TB_DIR ?= group8/tb
SW_DIR ?= group8/sw

DESIGN ?= $(RTL_DIR)/v2_8x8_multiplier.v $(RTL_DIR)/loa_adder.v $(RTL_DIR)/approx_mul16_loa.v $(RTL_DIR)/approx_mul16_loa_k4.v $(RTL_DIR)/approx_mul16_loa_k6.v $(RTL_DIR)/picorv32_pcpi_mul16_approx.v
TESTBENCH ?= $(TB_DIR)/approx_mul16_loa_tb.v
TBTOP ?= approx_mul16_loa_tb
TOP ?= approx_mul16_loa
LOA_K ?= 4
SIM_OUT ?= $(SIM_DIR)/$(TBTOP)_k$(LOA_K).vvp
VCD ?= $(SIM_DIR)/$(TBTOP)_k$(LOA_K).vcd
SYNTH_OUT ?= $(SYNTH_DIR)/$(TOP)_k$(LOA_K)_netlist.v
SYNTH_LOG ?= $(SYNTH_DIR)/$(TOP)_k$(LOA_K).log
METRIC_SAMPLES ?= 100000

.DEFAULT_GOAL := help

help:
	@printf '%s\n' \
	  'Group 8 approximate multiplier flow' \
	  '' \
	  'Targets:' \
	  '  make_prog Build and program the IceBreaker BRAM image' \
	  '  help      Show this help text' \
	  '  sim       Compile and run the selected testbench' \
	  '  synth     Synthesize the selected top module with Yosys' \
	  '  metrics   Estimate NMED and MRED with the Python model' \
	  '  clean     Remove generated build files' \
	  '' \
	  'Common variables:' \
	  '  LOA_K=4                                Group 8 required LOA width' \
	  '  TESTBENCH=group8/tb/approx_mul16_loa_tb.v   Testbench source' \
	  '  TBTOP=approx_mul16_loa_tb             Testbench top module' \
	  '  TOP=approx_mul16_loa                  Synthesis top module' \
	  '  DESIGN="file1.v file2.v ..."          Verilog design file list' \
	  '  VCD=build/sim/custom.vcd              Simulation waveform path' \
	  '  METRIC_SAMPLES=100000                 Random vectors for metrics' \
	  '' \
	  'Examples:' \
	  '  make sim LOA_K=4' \
	  '  make sim LOA_K=4 TESTBENCH=group8/tb/picorv32_pcpi_mul16_tb.v TBTOP=picorv32_pcpi_mul16_tb' \
	  '  make synth LOA_K=4 TOP=approx_mul16_loa' \
	  '  make make_prog' \
	  '  make sim TESTBENCH=mul_tb.v DESIGN="add.v mul.v" VCD=mul.vcd'

make_prog:
	$(MAKE) -C picorv32/picosoc prog_bram

sim: $(SIM_OUT)
	$(VVP) $(SIM_OUT) +vcd=$(VCD)

$(SIM_OUT): $(DESIGN) $(TESTBENCH) | $(SIM_DIR)
	$(IVERILOG) -g2012 -o $@ -s $(TBTOP) -P $(TBTOP).LOA_K=$(LOA_K) $(DESIGN) $(TESTBENCH)

synth: | $(SYNTH_DIR)
	$(YOSYS) -q -l $(SYNTH_LOG) -p 'read_verilog $(DESIGN); chparam -set LOA_K $(LOA_K) $(TOP); hierarchy -top $(TOP); proc; opt; techmap; opt; stat; write_verilog -noattr $(SYNTH_OUT)'
	@printf 'Wrote %s and %s\n' '$(SYNTH_OUT)' '$(SYNTH_LOG)'

metrics:
	$(PYTHON) group8/scripts/evaluate_mul16.py --k $(LOA_K) --samples $(METRIC_SAMPLES)

$(SIM_DIR): $(BUILD_DIR)
	mkdir -p $(SIM_DIR)

$(SYNTH_DIR): $(BUILD_DIR)
	mkdir -p $(SYNTH_DIR)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: help sim synth metrics clean make_prog
