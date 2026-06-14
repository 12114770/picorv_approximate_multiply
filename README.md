# Group8's Approximate 16×16 Multiplier

Copyright (C) Group8 - Paul Engelbrechtsmüller, Lukas Sichert, Moritz Schoisswohl

TU Wien Digital Integrated Circuits Lab, Summer Term 2026.
Approximate unsigned 16-bit multiplier as a PicoRV32 PCPI coprocessor on the iCEBreaker FPGA (Lattice iCE40 UP5K).

**Approximation scheme:** V2-blocks with Lower-part OR Adder (LOA), $k \in \{4, 6\}$.  
**Used configuration:** `E_55_55_55` k=4 — NMED 0.002723, 4 359 LCs, 16.47 MHz.

### Contents

1. [Introduction](README.md#introduction)
2. [Quick Start](README.md#quick-start)
    - [Requirements](#requirements)
    - [Example Commands](#example-commands)
3. [Repository Contents](README.md#repository-layout)
    - [Root Makefile Targets](README.md#root-makefile-targets)
        - [Key Variables](#key-variables)
    - [RTL Structure](#rtl-structure-group8rtl)
    - [Automation Scripts](#automation-scripts-group8scripts)
    - [Software](#software-group8sw)
4. [SoC Build](#soc-build-picorv32picosoc)
    - [PCPI Custom Instruction](#pcpi-custom-instruction)
---

## Introduction

Group8's Approximate 16x16 Mutliplier is an unsigned 16-bit mutliplier, that is integrated into the PicoRV32 soft-core 
processor as a custom PCPI (Pico Co-Processor Interface) instruction.

---
## Quick Start

### Requirements

To run all of the demos given in this repository the [OSS Cad Suite](https://github.com/YosysHQ/oss-cad-suite-build) is a hard requirement.

Additionally it is recommended a serial monitor is recommended.

### Example Commands
```sh


# Simulate default config (k=4, all blocks M=2)
make sim

# Simulate the best identified configuration
make sim LOA_K=4 M0_APPROX=0 M1_APPROX=5 M2_APPROX=5 M3_APPROX=5

# Synthesise (Yosys generic cells)
make synth LOA_K=4 M0_APPROX=0 M1_APPROX=5 M2_APPROX=5 M3_APPROX=5

# Sweep all 32 configurations — simulation metrics only
make sim_sweep

# Sweep all 32 configurations — synthesis resource counts only
make synth_sweep

# Full sweep: metrics + synthesis + PnR + board benchmark (iCEBreaker required)
make combined SERIAL_PORT=/dev/ttyUSB1

# Single-configuration combined run
make combined LOA_K=4 M0_APPROX=0 M1_APPROX=5 M2_APPROX=5 M3_APPROX=5 SERIAL_PORT=/dev/ttyUSB1
```
## Repository Contents

```raw
group8/
  rtl/          Verilog RTL
  tb/           Testbenches
  sw/           Firmware headers and benchmark
  scripts/      Automation scripts
picorv32/
  picosoc/      SoC build for iCEBreaker
results/        Saved sweep results and Pareto analysis
build/          Generated artefacts
Makefile        Root automation
```

The folder group8 containts files created by us. picorv32 contains [YosysHQ's picorv32](https://github.com/YosysHQ/picorv32?tab=readme-ov-file) soft-core processor.
### Root Makefile Targets

| Target | Description |
|--------|-------------|
| `help` | Print usage and variable reference |
| `sim` | Compile and run the selected testbench with Icarus Verilog |
| `synth` | Synthesise `approx_mul16_loa` with Yosys (generic technology) |
| `sim_sweep` | Run `sim_sweep.py` — metric simulation for all 32 configs |
| `synth_sweep` | Run `synth_sweep.py` — Yosys synthesis for all 32 configs |
| `combined` | Run `analyze_combined.py` — full sweep with PnR and board benchmark* |
| `clean` | Delete `build/` |

*Note that make combined requires a connected iCEBreaker FPGA.

#### Key Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `LOA_K` | `4` | LOA adder approximation width (`4` or `6`) |
| `M0_APPROX` | `2` | HH block ($A_h \times B_h$) approximation: `0`=exact, `2/4/5/6`=approx |
| `M1_APPROX` | `2` | HL block ($A_h \times B_l$) approximation |
| `M2_APPROX` | `2` | LH block ($A_l \times B_h$) approximation |
| `M3_APPROX` | `2` | LL block ($A_l \times B_l$) approximation |
| `SERIAL_PORT` | `/dev/ttyUSB1` | UART port for board benchmark capture |
| `METRIC_SAMPLES` | `10000` | Random vectors for NMED/MRED simulation |
| `TESTBENCH` | `group8/tb/a_16x16_mul_tb.v` | Testbench source |
| `TBTOP` | `approx_mul16_loa_tb` | Testbench top module |
| `TOP` | `approx_mul16_loa` | Synthesis top module |

When `LOA_K` / `M*_APPROX` are not set on the command line, `make combined` sweeps all 32 configurations and writes `build/combined_analysis/combined32.csv`. If any of those variables are set, it runs a single configuration and writes `build/combined_analysis/combined.csv`.
### RTL Structure (`group8/rtl/`)

The design is built bottom up from single exact or approximate partial product . A list of the RTL files can be seen below.

The lowest level blocks are
- `ppu_block.v`: Provides exact PPU1 (single full adder) and PPU2 (two stacked PPU1) Cells. These are used for the high-significance columns of each 8 ×4 partial-product array where no approximation is applied according to the multiplier configuration. 
- `va_block.v`: The VA cell is the defining approximation method for the first recombination row. Its output is the XOR of two adjacent partial products (ai·bi ⊕aj·bj ), discarding the carry-in. 
- `v2_block.v`: The V2 cell is used in partial-product rows 2 and 3. It simplifies the adder logic by removing upward carry propagation and using approximate sum generation instead of exact XOR logic.

These blocks are used to build the 8x4-multiplier inside v2_8x4_mutliplier. The number of used v2_blocks can be configured by the APPROX parameter.

In `v2_8x8_multiplier.v` the two 8x4-multiplier form a 8x8-multiplier. Group A contains the lower bits and group B the upper bits. The accumulation uses a Lower-part OR Adder (LOA). This multiplier can be configured using `APPROX_GROUP_A`, `APPROX_GROUP_B` and `APROX_LOA`.

The 8x4- and 8x8-multiplier are also available as `e` variants, which represent exact submultipliers.

The top-level 16x16 multiplier module decomposes the multiplication into four 8x8 partial products corresponding to the HH, HL, LH, and LL multiplication regions. Each submultiplier can either use an approximate or exact implementation depending on the selected configuration parameters. The partial products are recombined using simplified carry-less addition.

`picorv32_pcpi_mul16_approx.v` wraps the 16x16 multiplier in the picorv32's PCPI interface. It can be configured using these parameters:

- `LOA_K` (4,6): determines how many bits the LOA-adder approximates
- `M0_APPROX`, `M1_APPROX`, `M2_APPROX`, `M3_APPROX` (1,2,3,4,5,6): determines the degree of approximation of the 4 8x8 multipliers inside the coprocessor. M0 handles the most signicant bits while M4 handles the least significant bits.

This is the list of RTL-files:

```raw
va_block.v              VA approximate cell (row 1: zero carry, XOR sum)
v2_block.v              V2 approximate cell (rows 2–3: zero upward carry, AND-OR sum)
ppu_block.v             Exact PPU1/PPU2 full-adder cells

e_8x4_multiplier.v      Exact 8×4 → 12-bit
v2_8x4_multiplier.v     Approximate 8×4 → 12-bit  (param: APPROX 0..6)

e_8x8_multiplier.v      Exact 8×8 → 16-bit         (param: LOA_K)
v2_8x8_multiplier.v     Approximate 8×8 → 16-bit   (params: APPROX_GROUP, LOA_K)

loa_adder.v             Lower-part OR Adder          (params: WIDTH, K)

approx_mul16_loa.v      Top-level 16×16 multiplier  (params: LOA_K, M0..M3_APPROX)
approx_mul16_loa_k4.v   Fixed-K=4 wrapper
approx_mul16_loa_k6.v   Fixed-K=6 wrapper

picorv32_pcpi_mul16_approx.v   PicoRV32 PCPI coprocessor (1-cycle latency)
```
---
### Automation Scripts (`group8/scripts/`)

| Script | Output |
|--------|--------|
| `sim_sweep.py` | `build/sim_sweep/sim_metrics.csv` — NMED/MRED for all 32 configs |
| `synth_sweep.py` | `build/synth_sweep/synth_resources.csv` — gate counts for all 32 configs |
| `analyze_combined.py` | `build/combined_analysis/combined32.csv` — full results (metrics + PnR + board) |
| `pareto_front.py` | `results/pareto_front.png`, `results/pareto_front.csv` — Pareto analysis |

---
### Software (`group8/sw/`)

The approximate multiplier can be accessed by importing the mul16.h and invoking the `mul16(a, b)` function.

The file `mul16.h` — defines `mul16(a, b)` as an inline custom instruction:

```c
.insn r 0x0b, 0, 42, rd, rs1, rs2   // opcode=0x0b, funct3=0, funct7=42
```


The example `mul16_bench.c` (`BOARD_APP=bench`) — runs 100 multiplications, prints:

```raw
iters=0x0064 cycles=0x<hex> checksum=0x<hex>
BENCH_DONE
```

The example `mul16_demo.c` (`BOARD_APP=demo`) — interactive UART demo.

---
## SoC Build (`picorv32/picosoc/`)

To build the core with the approximate multiplier use these commands:
```sh
# Full SoC flow (synthesis → PnR → bitstream)
make -C picorv32/picosoc all LOA_K=4 M0_APPROX=0 M1_APPROX=5 M2_APPROX=5 M3_APPROX=5 BOARD_APP=bench

# Program iCEBreaker
make -C picorv32/picosoc prog_bram LOA_K=4 M0_APPROX=0 M1_APPROX=5 M2_APPROX=5 M3_APPROX=5 BOARD_APP=bench

# SoC simulation
make -C picorv32/picosoc sim LOA_K=4 M0_APPROX=0 M1_APPROX=5 M2_APPROX=5 M3_APPROX=5 BOARD_APP=bench
```
### PCPI Custom Instruction

| Field | Value |
|-------|-------|
| opcode | `0x0b` (custom-0) |
| funct3 | `0` |
| funct7 | `42` |
| rs1 | 16-bit operand A |
| rs2 | 16-bit operand B |
| rd | 32-bit approximate product |
| Latency | 1 clock cycle (`pcpi_wait = 0`) |

