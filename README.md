# Task 3

This repository contains the Task 3 implementation of an approximate unsigned 16x16 multiplier, its automation flow, and a PicoSoC/iCEBreaker integration that exposes the multiplier as a custom PicoRV32 PCPI instruction.

## Overview

The work is split into two main areas:

- `group8/`: approximate multiplier RTL, testbenches, software helper macro, and analysis scripts
- `picorv32/picosoc/`: FPGA/SoC integration for PicoRV32 on the iCEBreaker board

The 16x16 multiplier is built from four 8x8 blocks:

- `M0 = A[7:0] * B[7:0]`
- `M1 = A[7:0] * B[15:8]`
- `M2 = A[15:8] * B[7:0]`
- `M3 = A[15:8] * B[15:8]`

Accumulation uses a Lower-part OR Adder (LOA).

## Current Modeling Assumption

The original course material shown in the workspace is not sufficient to reconstruct the exact internal netlist of the approximate 8x8 family cell-by-cell. Because of that, the current implementation uses a best-effort structural model for the 8x8 block family:

- each 8x8 block is split into a lower-order 8x4 group and a higher-order 8x4 group
- the selected approximation level suppresses a configurable number of least-significant local bits in each group
- supported block families are `E`, `22`, `44`, `55`, and `66`

This is enough to run simulations, synthesis, simulation-backed metrics, full configuration sweeps, and PicoSoC integration consistently.

## Group 8 Default

The Group 8 target configuration is:

- `M0 = 22`
- `M1 = 22`
- `M2 = 22`
- `M3 = 22`
- `k-version a`, which maps to `LOA k = 4`

The codebase can also run the other assigned table configurations automatically.

## Configuration Mapping

Table suffix to LOA width:

- `a -> k = 4`
- `b -> k = 6`

8x8 block label mapping used in the code:

- `E -> 0`
- `22 -> 2`
- `44 -> 4`
- `55 -> 5`
- `66 -> 6`

These numbers are passed as `M0_APPROX`, `M1_APPROX`, `M2_APPROX`, and `M3_APPROX`.
The `M*` order is high-high, high-low, low-high, low-low: `M0` configures `a[15:8] * b[15:8]`, and `M3` configures `a[7:0] * b[7:0]`.

## Repository Layout

- `README.md`: this top-level overview
- `Makefile`: root automation for multiplier simulation, synthesis, metrics, and sweeps
- `group8/README.md`: Group 8 specific documentation
- `group8/rtl/v2_8x8_multiplier.v`: configurable best-effort approximate 8x8 block
- `group8/rtl/loa_adder.v`: parameterized LOA adder
- `group8/rtl/approx_mul16_loa.v`: parameterized 16x16 top-level multiplier
- `group8/rtl/approx_mul16_iter_datapath.v`: sequential datapath used by the PCPI core
- `group8/rtl/picorv32_pcpi_mul16_approx.v`: combinational PCPI wrapper
- `group8/rtl/picorv32_pcpi_mul16_seq.v`: multi-cycle FSM PCPI core
- `group8/tb/a_16x16_mul_tb.v`: top-level multiplier and metric testbench
- `group8/tb/picorv32_pcpi_mul16_tb.v`: PCPI testbench
- `group8/scripts/evaluate_mul16.py`: simulation-backed metric measurement for one configuration
- `group8/scripts/run_all_configs.py`: automated sweep of all 32 assigned configurations
- `group8/sw/mul16.h`: software macro for the custom instruction
- `picorv32/picosoc/`: PicoSoC/iCEBreaker build and run flow

## Root Makefile

The root `Makefile` provides these targets:

- `help`: print usage
- `sim`: compile and run the selected Verilog testbench
- `synth`: synthesize the selected design with Yosys
- `combined`: sweep configs and write one CSV with metrics, resource counts, PnR timing, and real-board benchmark data
- `clean`: remove generated root build artifacts

Important variables:

- `LOA_K`: LOA width, usually `4` or `6`
- `M0_APPROX`, `M1_APPROX`, `M2_APPROX`, `M3_APPROX`: high-high, high-low, low-high, low-low block configuration values `0|2|4|5|6`
- `SERIAL_PORT`: serial port for real board capture, default `/dev/ttyUSB1`
- `TESTBENCH`: testbench source file
- `TBTOP`: testbench top module
- `TOP`: synthesis top module
- `METRIC_SAMPLES`: number of random vectors for simulation-backed metrics
- `VCD`: waveform file path

## Common Commands

Group 8 default simulation:

```sh
make sim LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2
```

Mixed configuration example:

```sh
make sim LOA_K=6 M0_APPROX=0 M1_APPROX=6 M2_APPROX=6 M3_APPROX=6
```

Group 8 default synthesis:

```sh
make synth LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2
```

Full real-board combined sweep:

```sh
make combined METRIC_SAMPLES=10000 SERIAL_PORT=/dev/ttyUSB1
```

Single-configuration combined run:

```sh
make combined LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2
```

## 32-Configuration Automation

`group8/scripts/run_all_configs.py` contains the full assigned configuration list:

- `22_66_66_66 a`
- `22_55_55_55 a`
- `22_44_44_44 a`
- `22_22_22_22 a`
- `22_66_66_66 b`
- `22_55_55_55 b`
- `22_44_44_44 b`
- `22_22_22_22 b`
- `E_66_66_66 a`
- `E_55_55_55 a`
- `E_44_44_44 a`
- `E_22_22_22 a`
- `E_66_66_66 b`
- `E_55_55_55 b`
- `E_44_44_44 b`
- `E_22_22_22 b`
- `E_E_66_66 a`
- `E_E_55_55 a`
- `E_E_44_44 a`
- `E_E_22_22 a`
- `E_E_66_66 b`
- `E_E_55_55 b`
- `E_E_44_44 b`
- `E_E_22_22 b`
- `E_E_E_66 a`
- `E_E_E_55 a`
- `E_E_E_44 a`
- `E_E_E_22 a`
- `E_E_E_66 b`
- `E_E_E_55 b`
- `E_E_E_44 b`
- `E_E_E_22 b`

For each entry the script automatically:

- decodes the `M0..M3` settings
- maps `a` to `k=4` and `b` to `k=6`
- runs metrics
- runs simulation by default
- runs synthesis by default
- can skip synthesis for a quick pass
- writes a CSV row with configuration data and results

Quick direct invocation example:

```sh
python3 group8/scripts/run_all_configs.py --samples 200 --output build/config_sweep/test.csv --skip-synth
```

## Error Metrics

The metric script computes:

- `NMED`: normalized mean error distance
- `MRED`: mean relative error distance

by comparing the approximate 16x16 result against exact unsigned multiplication over random input vectors.

## Combined Analysis

The combined analyzer collects:

- error metrics: `NMED`, `MRED`
- synthesis resource counts
- iCEBreaker place-and-route timing data
- Dhrystone benchmark output
- `mul16` benchmark output

Real-board combined analysis for all 32 configurations by default:

```sh
make combined
```

If you pass `LOA_K` or any `M0..M3` override to `make combined`, it switches to single-configuration mode and writes `build/combined_analysis/combined.csv` instead of the full `combined32.csv`.

Output:

- `build/combined_analysis/combined.csv`
- `build/combined_analysis/combined32.csv`

The combined CSV includes benchmark-related fields such as:

- `dhrystones_per_second_mhz`
- `dmips_per_mhz`
- `mul16_iters`
- `mul16_cycles`
- `mul16_checksum`
- `max_freq_mhz`

## Current Representative Results

These reflect the current best-effort model, not a guaranteed exact course netlist.

Group 8 default `22_22_22_22` with `k=4`:

- `NMED = 0.0002618991`
- `MRED = 0.0053845639`
- Yosys generic-cell count: `2165`

Example mixed configuration `E_66_66_66` with `k=6`:

- metric run verified
- simulation verified
- synthesis verified

## PicoSoC / iCEBreaker Integration

The approximate multiplier is exposed to PicoRV32 through PCPI.

Main points:

- multi-cycle FSM-based PCPI core is used
- control and datapath are separated
- `ENABLE_REGS_DUALPORT = 1` is used in the iCEBreaker top
- instructions are allowed to take multiple cycles
- the PicoSoC firmware runs `100` custom `mul16` operations and prints a checksum over UART

Relevant files:

- `picorv32/picosoc/picosoc.v`
- `picorv32/picosoc/icebreaker.v`
- `picorv32/picosoc/firmware.c`
- `group8/rtl/approx_mul16_iter_datapath.v`
- `group8/rtl/picorv32_pcpi_mul16_seq.v`

The root workflow keeps PicoSoC board steps inside `make combined`. Use the `picorv32/picosoc` Makefile directly only for low-level debugging.

## Full Board Run

If the iCEBreaker is connected, this is the recommended end-to-end flow:

```sh
make combined SERIAL_PORT=/dev/ttyUSB1 METRIC_SAMPLES=10000
```

For one selected configuration:

```sh
make combined LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2 SERIAL_PORT=/dev/ttyUSB1
```

`combined` builds, places/routes, programs the BRAM image, captures the benchmark UART output, and writes a CSV. The CSV includes:

- the Dhrystone banner and summary
- the `mul16 iters`, `mul16 cycles`, and `mul16 checksum` lines
- synthesis resource counts
- PnR timing data
- `NMED` and `MRED`

To test a different table entry on hardware, change both the LOA and block settings:

```sh
make combined LOA_K=6 M0_APPROX=0 M1_APPROX=6 M2_APPROX=6 M3_APPROX=6 SERIAL_PORT=/dev/ttyUSB1
```

That corresponds to `E_66_66_66 b`.

The combined flow records the max frequency reported by nextpnr for each configuration.

Task 3 build placement:

- root-level synthesis uses `make synth`
- combined place-and-route/programming uses `picorv32/picosoc/Makefile` internally

On-board testing notes:

- `combined` uses the alternate benchmark firmware from `dhrystone_clone/`
- the benchmark firmware runs upstream Dhrystone first and then a dedicated `mul16` benchmark loop
- expected status is visible via UART output and the LED checksum written by firmware
- the actual physical UART capture depends on your host-side serial setup and board connection

## Custom Instruction Interface

The custom software helper is in `group8/sw/mul16.h`.

The hardware uses:

- opcode: `0x0b`
- funct3: `0`
- funct7: `42`

The instruction consumes:

- `rs1[15:0]`
- `rs2[15:0]`

and returns:

- the approximate unsigned 32-bit product

## Testing Status

The following have been exercised in this workspace:

- root-level multiplier simulation for Group 8 default
- root-level simulation for a mixed configuration
- root-level simulation-backed metric measurement
- root-level synthesis
- metric-only 32-configuration sweep generation
- PicoSoC simulation on iCEBreaker testbench
- PicoSoC place-and-route max-frequency reporting

## Limitations

- the 8x8 approximate family is currently a best-effort structural model derived from the available slides
- if your lab provides the exact internal `22/44/55/66` block diagram later, `group8/rtl/v2_8x8_multiplier.v` should be updated accordingly
- after replacing that model, rerun simulation, synthesis, metrics, and the sweep

## Related Documentation

- `group8/README.md`: focused Group 8 notes and current results
- `dhrystone_clone/README.md`: separate benchmark workspace for Dhrystone + `mul16`
- `picorv32/README.md`: upstream PicoRV32 documentation
- `picorv32/picosoc/README.md`: upstream PicoSoC notes
