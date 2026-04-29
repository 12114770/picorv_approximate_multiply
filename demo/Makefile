
# Directories:
BIN_DIR = synth_design
DESIGN_DIR = designs
BUILD_DIR = build
SOFTWARE_DIR = software
SW_BUILD_DIR = $(BUILD_DIR)/$(SOFTWARE_DIR)
BIT_STR_DIR = $(BUILD_DIR)/bitstream
SIM_DIR     = $(BUILD_DIR)/sim
SCRIPT_DIR  = scripts

# RISCV
USE_MYSTDLIB = 1
RISCV_ISA = im
TOOLCHAIN_PREFIX = riscv-none-elf-

# BRAM size
BRAM_SIZE = 3072

# ICE40 models for simulation
ICE40_SIM_MODEL := $(shell yosys-config --datdir/ice40/cells_sim.v)

# Simulation
USE_RAND ?= true
RAND_SEED = 422
NUM_INPUT ?= 1000

# Set simulation macros
SIM_DEFS = -DN_INPUT=$(NUM_INPUT)
ifeq ($(USE_RAND),true)
    SIM_DEFS += -DUSE_RAND
endif

demo_software: $(SW_BUILD_DIR)/icebreaker_fw_bram.hex

size : $(SW_BUILD_DIR)/icebreaker_fw.elf
	$(TOOLCHAIN_PREFIX)size $(SW_BUILD_DIR)/icebreaker_fw.elf

dis: $(SW_BUILD_DIR)/icebreaker_fw.elf
	$(TOOLCHAIN_PREFIX)objdump -d $(SW_BUILD_DIR)/icebreaker_fw.elf

disdump: $(SW_BUILD_DIR)/icebreaker_fw.elf
	$(TOOLCHAIN_PREFIX)objdump -D $(SW_BUILD_DIR)/icebreaker_fw.elf > $(SW_BUILD_DIR)/icebreaker_fw.s

demo: $(BIT_STR_DIR)/icebreaker.bin

prog_demo: $(BIT_STR_DIR)/icebreaker.bin
	iceprog $(BIT_STR_DIR)/icebreaker.bin

sim_demo: $(DESIGN_DIR)/approx_mul.v $(SIM_DIR)/sim_input_a.hex $(SIM_DIR)/sim_input_b.hex
			iverilog -g2012 -o $(SIM_DIR)/sim.out \
			$(SIM_DEFS) \
			demo_tb.v $(DESIGN_DIR)/approx_mul.v $(ICE40_SIM_MODEL)
			vvp $(SIM_DIR)/sim.out > $(SIM_DIR)/sim_results.txt
			python3 $(SCRIPT_DIR)/calc_error_metrics.py $(SIM_DIR)/sim_results.txt > $(SIM_DIR)/error_metrics.txt
clean:
	rm -rf $(BUILD_DIR)

$(SW_BUILD_DIR)/icebreaker_sections.lds: $(SOFTWARE_DIR)/sections.lds | $(SW_BUILD_DIR)
	$(TOOLCHAIN_PREFIX)cpp -P -DICEBREAKER -o $(SW_BUILD_DIR)/icebreaker_sections.lds $(SOFTWARE_DIR)/sections.lds

$(SW_BUILD_DIR)/icebreaker_fw.elf: $(SW_BUILD_DIR)/icebreaker_sections.lds $(SOFTWARE_DIR)/start.s $(SOFTWARE_DIR)/benchmark.c
	$(TOOLCHAIN_PREFIX)gcc -O2 -DICEBREAKER -DTIME -DRISCV -DUSE_MYSTDLIB -ffreestanding -nostdlib -mabi=ilp32 -march=rv32$(RISCV_ISA) \
	-Wl,-Bstatic,-T,$(SW_BUILD_DIR)/icebreaker_sections.lds,-Map,$(SW_BUILD_DIR)/icebreaker_fw.map,--strip-debug -o $(SW_BUILD_DIR)/icebreaker_fw.elf \
	$(SOFTWARE_DIR)/start.s  $(SOFTWARE_DIR)/benchmark.c  $(SOFTWARE_DIR)/stdlib.c -Wno-implicit-int -Wno-implicit-function-declaration -lgcc

$(SW_BUILD_DIR)/icebreaker_fw.bin: $(SW_BUILD_DIR)/icebreaker_fw.elf
	$(TOOLCHAIN_PREFIX)objcopy -O binary $(SW_BUILD_DIR)/icebreaker_fw.elf $(SW_BUILD_DIR)/icebreaker_fw.bin

$(SW_BUILD_DIR)/icebreaker_fw_bram.hex: $(SW_BUILD_DIR)/icebreaker_fw.bin
	python3 $(SCRIPT_DIR)/makehex.py $< $(BRAM_SIZE) > $@

$(SW_BUILD_DIR)/icebreaker_fw_random.hex: | $(SW_BUILD_DIR)
	icebram -s 420 -g 32 $(BRAM_SIZE) > $(SW_BUILD_DIR)/icebreaker_fw_random.hex

$(BIT_STR_DIR)/icebreaker.bin: $(SW_BUILD_DIR)/icebreaker_fw_random.hex $(SW_BUILD_DIR)/icebreaker_fw_bram.hex $(DESIGN_DIR)/icebreaker.asc | $(BIT_STR_DIR)
	icebram -v $(SW_BUILD_DIR)/icebreaker_fw_random.hex $(SW_BUILD_DIR)/icebreaker_fw_bram.hex < $(DESIGN_DIR)/icebreaker.asc > $(BIT_STR_DIR)/icebreaker_bram.asc
	icetime -d up5k -c 12 -mtr $(BIT_STR_DIR)/time.rpt $(BIT_STR_DIR)/icebreaker_bram.asc
	icepack $(BIT_STR_DIR)/icebreaker_bram.asc $(BIT_STR_DIR)/icebreaker.bin

$(SIM_DIR)/sim_input_a.hex : | $(SIM_DIR)
	python3 $(SCRIPT_DIR)/gen_stimulus.py $(SIM_DIR) $(NUM_INPUT) $(RAND_SEED)

$(SIM_DIR)/sim_input_b.hex : | $(SIM_DIR)
	python3 $(SCRIPT_DIR)/gen_stimulus.py $(SIM_DIR) $(NUM_INPUT) $(RAND_SEED)

$(SIM_DIR): | $(BUILD_DIR)
	mkdir -p $(SIM_DIR)

$(BIT_STR_DIR) : | $(BUILD_DIR)
	mkdir -p $(BIT_STR_DIR)

$(SW_BUILD_DIR): | $(BUILD_DIR)
	mkdir -p $(SW_BUILD_DIR)

$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)
