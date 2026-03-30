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
M0_APPROX ?= 2
M1_APPROX ?= 2
M2_APPROX ?= 2
M3_APPROX ?= 2
CFG_TAG ?= $(M0_APPROX)_$(M1_APPROX)_$(M2_APPROX)_$(M3_APPROX)
SIM_OUT ?= $(SIM_DIR)/$(TBTOP)_k$(LOA_K).vvp
VCD ?= $(SIM_DIR)/$(TBTOP)_k$(LOA_K).vcd
SYNTH_OUT ?= $(SYNTH_DIR)/$(TOP)_k$(LOA_K)_$(CFG_TAG)_netlist.v
SYNTH_LOG ?= $(SYNTH_DIR)/$(TOP)_k$(LOA_K)_$(CFG_TAG).log
METRIC_SAMPLES ?= 100000
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
	  '  make_prog Build and program the IceBreaker BRAM image' \
	  '  board_sim  Run PicoSoC/iCEBreaker simulation for selected config' \
	  '  board_pnr  Run PicoSoC/iCEBreaker place and route' \
	  '  board_prog Program selected config to iCEBreaker BRAM' \
	  '  board_test Build/program selected config for on-board execution' \
	  '  board_bench_sim Run Dhrystone+mul16 board simulation' \
	  '  board_bench_test Build/program Dhrystone+mul16 board benchmark' \
	  '  help      Show this help text' \
	  '  sim       Compile and run the selected testbench' \
	  '  synth     Synthesize the selected top module with Yosys' \
	  '  metrics   Estimate NMED and MRED with the Python model' \
	  '  resources Analyze synthesis resource consumption to CSV' \
	  '  resources32 Analyze resource consumption for all 32 configs' \
	  '  combined  Analyze metrics, resources, timing, and benchmark output' \
	  '  combined_board Same as combined, but captures real board UART' \
	  '  combined32 Analyze all 32 configs into one combined CSV' \
	  '  sweep32_full Run all 32 configs with sim+synth+metrics' \
	  '  sweep32_quick Run all 32 configs with sim+metrics' \
	  '  clean     Remove generated build files' \
	  '' \
	  'Common variables:' \
	  '  LOA_K=4|6                              LOA width (Group 8 default is 4)' \
	  '  TESTBENCH=group8/tb/approx_mul16_loa_tb.v   Testbench source' \
	  '  TBTOP=approx_mul16_loa_tb             Testbench top module' \
	  '  TOP=approx_mul16_loa                  Synthesis top module' \
	  '  M0_APPROX..M3_APPROX=0|2|4|5|6        Per-block E/22/44/55/66 selection' \
	  '  BOARD_APP=demo|mul16_dhry             Select PicoSoC firmware app' \
	  '  SERIAL_PORT=/dev/ttyUSB1              Serial port for board UART capture' \
	  '  DESIGN="file1.v file2.v ..."          Verilog design file list' \
	  '  VCD=build/sim/custom.vcd              Simulation waveform path' \
	  '  METRIC_SAMPLES=100000                 Random vectors for metrics' \
	  '' \
	  'Examples:' \
	  '  make sim LOA_K=4' \
	  '  make sim LOA_K=6 M0_APPROX=0 M1_APPROX=6 M2_APPROX=6 M3_APPROX=6' \
	  '  make sim LOA_K=4 TESTBENCH=group8/tb/picorv32_pcpi_mul16_tb.v TBTOP=picorv32_pcpi_mul16_tb' \
	  '  make synth LOA_K=4 TOP=approx_mul16_loa' \
	  '  make sweep32 METRIC_SAMPLES=10000' \
	  '  make resources LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2' \
	  '  make resources32' \
	  '  make combined                         Sweep all 32 configs on board by default' \
	  '  make combined LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2' \
	  '  make combined_board LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2' \
	  '  make combined32 METRIC_SAMPLES=2000' \
	  '  make board_test LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2' \
	  '  make board_bench_test LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2' \
	  '  make make_prog' \
	  '  make sim TESTBENCH=mul_tb.v DESIGN="add.v mul.v" VCD=mul.vcd'

make_prog:
	$(MAKE) -C picorv32/picosoc prog_bram

board_sim:
	$(MAKE) -C picorv32/picosoc sim BOARD_APP=$(BOARD_APP) LOA_K=$(LOA_K) M0_APPROX=$(M0_APPROX) M1_APPROX=$(M1_APPROX) M2_APPROX=$(M2_APPROX) M3_APPROX=$(M3_APPROX)

board_pnr:
	$(MAKE) -C picorv32/picosoc all BOARD_APP=$(BOARD_APP) LOA_K=$(LOA_K) M0_APPROX=$(M0_APPROX) M1_APPROX=$(M1_APPROX) M2_APPROX=$(M2_APPROX) M3_APPROX=$(M3_APPROX)

board_prog:
	$(MAKE) -C picorv32/picosoc prog_bram BOARD_APP=$(BOARD_APP) LOA_K=$(LOA_K) M0_APPROX=$(M0_APPROX) M1_APPROX=$(M1_APPROX) M2_APPROX=$(M2_APPROX) M3_APPROX=$(M3_APPROX)

board_test: board_pnr board_prog

board_bench_sim:
	$(MAKE) board_sim BOARD_APP=mul16_dhry LOA_K=$(LOA_K) M0_APPROX=$(M0_APPROX) M1_APPROX=$(M1_APPROX) M2_APPROX=$(M2_APPROX) M3_APPROX=$(M3_APPROX)

board_bench_test:
	$(MAKE) board_test BOARD_APP=mul16_dhry LOA_K=$(LOA_K) M0_APPROX=$(M0_APPROX) M1_APPROX=$(M1_APPROX) M2_APPROX=$(M2_APPROX) M3_APPROX=$(M3_APPROX)

sim: $(SIM_OUT)
	$(VVP) $(SIM_OUT) +vcd=$(VCD)

$(SIM_OUT): $(DESIGN) $(TESTBENCH) | $(SIM_DIR)
	$(IVERILOG) -g2012 -o $@ -s $(TBTOP) -P $(TBTOP).LOA_K=$(LOA_K) -P $(TBTOP).M0_APPROX=$(M0_APPROX) -P $(TBTOP).M1_APPROX=$(M1_APPROX) -P $(TBTOP).M2_APPROX=$(M2_APPROX) -P $(TBTOP).M3_APPROX=$(M3_APPROX) $(DESIGN) $(TESTBENCH)

synth: | $(SYNTH_DIR)
	$(YOSYS) -q -l $(SYNTH_LOG) -p 'read_verilog $(DESIGN); chparam -set LOA_K $(LOA_K) -set M0_APPROX $(M0_APPROX) -set M1_APPROX $(M1_APPROX) -set M2_APPROX $(M2_APPROX) -set M3_APPROX $(M3_APPROX) $(TOP); hierarchy -top $(TOP); proc; opt; techmap; opt; stat; write_verilog -noattr $(SYNTH_OUT)'
	@printf 'Wrote %s and %s\n' '$(SYNTH_OUT)' '$(SYNTH_LOG)'

metrics:
	$(PYTHON) group8/scripts/evaluate_mul16.py --k $(LOA_K) --m0 $(M0_APPROX) --m1 $(M1_APPROX) --m2 $(M2_APPROX) --m3 $(M3_APPROX) --samples $(METRIC_SAMPLES)

resources:
	$(PYTHON) group8/scripts/analyze_resources.py --k $(LOA_K) --m0 $(M0_APPROX) --m1 $(M1_APPROX) --m2 $(M2_APPROX) --m3 $(M3_APPROX)

resources32:
	$(PYTHON) group8/scripts/analyze_resources.py --all --output build/resource_analysis/resources32.csv

combined:
	$(PYTHON) group8/scripts/analyze_combined.py --board --serial-port $(SERIAL_PORT) --samples $(METRIC_SAMPLES) $(COMBINED_ARGS)

combined_board:
	$(PYTHON) group8/scripts/analyze_combined.py --board --serial-port $(SERIAL_PORT) --k $(LOA_K) --m0 $(M0_APPROX) --m1 $(M1_APPROX) --m2 $(M2_APPROX) --m3 $(M3_APPROX) --samples $(METRIC_SAMPLES)

combined32:
	$(PYTHON) group8/scripts/analyze_combined.py --all --samples $(METRIC_SAMPLES) --output build/combined_analysis/combined32.csv

sweep32:
	$(PYTHON) group8/scripts/run_all_configs.py --samples $(METRIC_SAMPLES)

sweep32_full:
	$(PYTHON) group8/scripts/run_all_configs.py --samples $(METRIC_SAMPLES)

sweep32_quick:
	$(PYTHON) group8/scripts/run_all_configs.py --samples $(METRIC_SAMPLES) --skip-synth

$(SIM_DIR): $(BUILD_DIR)
	mkdir -p $(SIM_DIR)

$(SYNTH_DIR): $(BUILD_DIR)
	mkdir -p $(SYNTH_DIR)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

clean:
	rm -rf $(BUILD_DIR)

.PHONY: help sim synth metrics resources resources32 combined combined_board combined32 clean make_prog sweep32 sweep32_full sweep32_quick board_sim board_pnr board_prog board_test board_bench_sim board_bench_test
