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

DESIGN ?= 	$(RTL_DIR)/loa_adder.v \
			$(RTL_DIR)/ppu_block.v \
			$(RTL_DIR)/v2_block.v \
			$(RTL_DIR)/va_block.v \
			$(RTL_DIR)/v2_8x4_multiplier.v \
			$(RTL_DIR)/v2_8x8_multiplier.v \
			$(RTL_DIR)/e_8x4_multiplier.v \
			$(RTL_DIR)/e_8x8_multiplier.v \
			$(RTL_DIR)/approx_mul16_loa.v \
			$(RTL_DIR)/approx_mul16_loa_k4.v \
			$(RTL_DIR)/approx_mul16_loa_k6.v \
			$(RTL_DIR)/picorv32_pcpi_mul16_approx.v
TESTBENCH ?= $(TB_DIR)/a_16x16_mul_tb.v
TBTOP ?= approx_mul16_loa_tb
TOP ?= approx_mul16_loa
LOA_K ?= 4
M0_APPROX ?= 2
M1_APPROX ?= 2
M2_APPROX ?= 2
M3_APPROX ?= 2
CFG_TAG ?= $(M0_APPROX)_$(M1_APPROX)_$(M2_APPROX)_$(M3_APPROX)
SIM_OUT ?= $(SIM_DIR)/$(TBTOP)_k$(LOA_K)_m$(M0_APPROX)_$(M1_APPROX)_$(M2_APPROX)_$(M3_APPROX).vvp
VCD ?= $(SIM_DIR)/$(TBTOP)_k$(LOA_K).vcd
SYNTH_OUT ?= $(SYNTH_DIR)/$(TOP)_k$(LOA_K)_$(CFG_TAG)_netlist.v
SYNTH_LOG ?= $(SYNTH_DIR)/$(TOP)_k$(LOA_K)_$(CFG_TAG).log
METRIC_SAMPLES ?= 10000
SERIAL_PORT ?= /dev/ttyUSB1

ifeq ($(filter command line,$(origin LOA_K) $(origin M0_APPROX) $(origin M1_APPROX) $(origin M2_APPROX) $(origin M3_APPROX)),)
COMBINED_ARGS := --all --output build/combined_analysis/combined32.csv
else
COMBINED_ARGS := --k $(LOA_K) --m0 $(M0_APPROX) --m1 $(M1_APPROX) --m2 $(M2_APPROX) --m3 $(M3_APPROX) --output build/combined_analysis/combined.csv
endif

.DEFAULT_GOAL := help

help:
	@printf '%s\n' \
	  'Group 8 approximate multiplier flow' \
	  '' \
	  'Targets:' \
	  '  help      Show this help text' \
	  '  sim       Compile and run the selected testbench' \
	  '  synth     Synthesize the selected top module with Yosys' \
	  '  sim_sweep Run all 32 configs through the metric simulation' \
	  '  synth_sweep Run all 32 configs through synthesis/resource analysis' \
	  '  combined  Sweep configs: metrics, resources, PnR timing, and board benchmark CSV' \
	  '  clean     Remove generated build files' \
	  '' \
	  'Common variables:' \
	  '  LOA_K=4|6                              LOA width (Group 8 default is 4)' \
	  '  TESTBENCH=group8/tb/a_16x16_mul_tb.v        Testbench source' \
	  '  TBTOP=approx_mul16_loa_tb             Testbench top module' \
	  '  TOP=approx_mul16_loa                  Synthesis top module' \
	  '  M0_APPROX..M3_APPROX=0|2|4|5|6        HH,HL,LH,LL block configs; 0 means exact' \
	  '  SERIAL_PORT=/dev/ttyUSB1              Serial port for board UART capture' \
	  '  DESIGN="file1.v file2.v ..."          Verilog design file list' \
	  '  VCD=build/sim/custom.vcd              Simulation waveform path' \
	  '  METRIC_SAMPLES=10000                  Random vectors for metrics' \
	  '' \
	  'Examples:' \
	  '  make sim LOA_K=4' \
	  '  make sim LOA_K=6 M0_APPROX=0 M1_APPROX=6 M2_APPROX=6 M3_APPROX=6' \
	  '  make sim LOA_K=4 TESTBENCH=group8/tb/picorv32_pcpi_mul16_tb.v TBTOP=picorv32_pcpi_mul16_tb' \
	  '  make synth LOA_K=4 TOP=approx_mul16_loa' \
	  '  make combined                         Sweep all 32 configs on board' \
	  '  make combined LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2' \
	  '  make sim TESTBENCH=mul_tb.v DESIGN="add.v mul.v" VCD=mul.vcd'

sim: $(SIM_OUT)
	$(VVP) $(SIM_OUT) +vcd=$(VCD)

$(SIM_OUT): $(DESIGN) $(TESTBENCH) | $(SIM_DIR)
	$(IVERILOG) -g2012 -o $@ -s $(TBTOP) -P $(TBTOP).LOA_K=$(LOA_K) -P $(TBTOP).M0_APPROX=$(M0_APPROX) -P $(TBTOP).M1_APPROX=$(M1_APPROX) -P $(TBTOP).M2_APPROX=$(M2_APPROX) -P $(TBTOP).M3_APPROX=$(M3_APPROX) $(DESIGN) $(TESTBENCH)

synth: | $(SYNTH_DIR)
	$(YOSYS) -q -l $(SYNTH_LOG) -p 'read_verilog $(DESIGN); chparam -set LOA_K $(LOA_K) -set M0_APPROX $(M0_APPROX) -set M1_APPROX $(M1_APPROX) -set M2_APPROX $(M2_APPROX) -set M3_APPROX $(M3_APPROX) $(TOP); hierarchy -top $(TOP); proc; opt; techmap; opt; stat; write_verilog -noattr $(SYNTH_OUT)'
	@printf 'Wrote %s and %s\n' '$(SYNTH_OUT)' '$(SYNTH_LOG)'

sim_sweep:
	$(PYTHON) group8/scripts/sim_sweep.py

synth_sweep:
	$(PYTHON) group8/scripts/synth_sweep.py --all

combined:
	$(PYTHON) group8/scripts/analyze_combined.py --board --serial-port $(SERIAL_PORT) --samples $(METRIC_SAMPLES) $(COMBINED_ARGS)

$(SIM_DIR): $(BUILD_DIR)
	mkdir -p $(SIM_DIR)

$(SYNTH_DIR): $(BUILD_DIR)
	mkdir -p $(SYNTH_DIR)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

pareto:
	$(PYTHON) group8/scripts/pareto_front.py

clean:
	rm -rf $(BUILD_DIR)

.PHONY: help sim synth sim_sweep synth_sweep combined clean
