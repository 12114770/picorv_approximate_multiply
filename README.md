# Approximate 16×16 Multiplier — Group 8

TU Wien Digital Integrated Circuits Lab, Summer Term 2026.
Task 2: approximate unsigned 16-bit multiplier as a PicoRV32 PCPI coprocessor on the iCEBreaker FPGA (Lattice iCE40 UP5K).

**Approximation scheme:** V2-blocks with Lower-part OR Adder (LOA), $k \in \{4, 6\}$.  
**Best configuration:** `E_55_55_55` k=4 — NMED 0.002723, 4 359 LCs, 16.47 MHz.

---

## Repository Layout

```
group8/
  rtl/          Verilog RTL (12 active files)
  tb/           Testbenches
  sw/           Firmware headers and benchmark
  scripts/      Automation scripts
picorv32/
  picosoc/      SoC build for iCEBreaker
results/        Saved sweep results and Pareto analysis
build/          Generated artefacts (git-ignored)
Makefile        Root automation
```

---

## Quick Start

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

---

## Root Makefile Targets

| Target | Description |
|--------|-------------|
| `help` | Print usage and variable reference |
| `sim` | Compile and run the selected testbench with Icarus Verilog |
| `synth` | Synthesise `approx_mul16_loa` with Yosys (generic technology) |
| `sim_sweep` | Run `sim_sweep.py` — metric simulation for all 32 configs |
| `synth_sweep` | Run `synth_sweep.py` — Yosys synthesis for all 32 configs |
| `combined` | Run `analyze_combined.py` — full sweep with PnR and board benchmark |
| `clean` | Delete `build/` |

### Key Variables

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

---

## RTL Structure (`group8/rtl/`)

The design is built bottom-up:

```
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

The 16×16 product is decomposed schoolbook-style into four 8×8 sub-products recombined with carry-less byte-slice addition (intentional approximation). Each sub-product uses `v2_8x8` when `M_APPROX > 0`, or `e_8x8` when `M_APPROX = 0`.

---

## Automation Scripts (`group8/scripts/`)

| Script | Output |
|--------|--------|
| `sim_sweep.py` | `build/sim_sweep/sim_metrics.csv` — NMED/MRED for all 32 configs |
| `synth_sweep.py` | `build/synth_sweep/synth_resources.csv` — gate counts for all 32 configs |
| `analyze_combined.py` | `build/combined_analysis/combined32.csv` — full results (metrics + PnR + board) |
| `pareto_front.py` | `results/pareto_front.png`, `results/pareto_front.csv` — Pareto analysis |

---

## Software (`group8/sw/`)

`mul16.h` — defines `mul16(a, b)` as an inline custom instruction:

```c
.insn r 0x0b, 0, 42, rd, rs1, rs2   // opcode=0x0b, funct3=0, funct7=42
```

`mul16_bench.c` (`BOARD_APP=bench`) — runs 100 multiplications, prints:

```
iters=0x0064 cycles=0x<hex> checksum=0x<hex>
BENCH_DONE
```

`mul16_demo.c` (`BOARD_APP=demo`) — interactive UART demo.

---

## PCPI Custom Instruction

| Field | Value |
|-------|-------|
| opcode | `0x0b` (custom-0) |
| funct3 | `0` |
| funct7 | `42` |
| rs1 | 16-bit operand A |
| rs2 | 16-bit operand B |
| rd | 32-bit approximate product |
| Latency | 1 clock cycle (`pcpi_wait = 0`) |

---

## SoC Build (`picorv32/picosoc/`)

```sh
# Full SoC flow (synthesis → PnR → bitstream)
make -C picorv32/picosoc all LOA_K=4 M0_APPROX=0 M1_APPROX=5 M2_APPROX=5 M3_APPROX=5 BOARD_APP=bench

# Program iCEBreaker
make -C picorv32/picosoc prog_bram LOA_K=4 M0_APPROX=0 M1_APPROX=5 M2_APPROX=5 M3_APPROX=5 BOARD_APP=bench

# SoC simulation
make -C picorv32/picosoc sim LOA_K=4 M0_APPROX=0 M1_APPROX=5 M2_APPROX=5 M3_APPROX=5 BOARD_APP=bench
```

---

