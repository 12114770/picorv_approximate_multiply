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

This is enough to run simulations, synthesis, metric estimation, full configuration sweeps, and PicoSoC integration consistently.

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
- `group8/tb/approx_mul16_loa_tb.v`: top-level multiplier testbench
- `group8/tb/picorv32_pcpi_mul16_tb.v`: PCPI testbench
- `group8/scripts/evaluate_mul16.py`: metric estimation for one configuration
- `group8/scripts/run_all_configs.py`: automated sweep of all 32 assigned configurations
- `group8/sw/mul16.h`: software macro for the custom instruction
- `picorv32/picosoc/`: PicoSoC/iCEBreaker build and run flow

## Root Makefile

The root `Makefile` provides these targets:

- `help`: print usage
- `sim`: compile and run the selected Verilog testbench
- `synth`: synthesize the selected design with Yosys
- `metrics`: estimate `NMED` and `MRED`
- `resources`: synthesize one configuration and write resource CSV output
- `resources32`: synthesize all 32 assigned configurations and write resource CSV output
- `combined`: collect metrics, resource data, timing, and real-board benchmark output into one CSV
- `combined_board`: same as `combined`, but captures a real connected board run over UART
- `combined32`: run the simulation-backed combined analysis for all 32 configurations
- `sweep32`: run all 32 assigned configurations with sim, synth, and metrics
- `sweep32_full`: explicit alias for the full 32-config sweep
- `sweep32_quick`: run all 32 assigned configurations without synthesis
- `board_sim`: run the PicoSoC/iCEBreaker simulation for the selected configuration
- `board_pnr`: run iCEBreaker place-and-route for the selected configuration
- `board_prog`: program the selected configuration to iCEBreaker BRAM
- `board_test`: build and program the selected configuration for on-board execution
- `board_bench_sim`: run the cloned Dhrystone + `mul16` board benchmark in simulation
- `board_bench_test`: build and program the cloned Dhrystone + `mul16` board benchmark
- `make_prog`: build and program the iCEBreaker BRAM image through the PicoSoC flow
- `clean`: remove generated root build artifacts

Important variables:

- `LOA_K`: LOA width, usually `4` or `6`
- `M0_APPROX`, `M1_APPROX`, `M2_APPROX`, `M3_APPROX`: per-block configuration values `0|2|4|5|6`
- `BOARD_APP`: board firmware selection, `demo` or `mul16_dhry`
- `SERIAL_PORT`: serial port for real board capture, default `/dev/ttyUSB1`
- `TESTBENCH`: testbench source file
- `TBTOP`: testbench top module
- `TOP`: synthesis top module
- `METRIC_SAMPLES`: number of random vectors for metric estimation
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

Group 8 default metrics:

```sh
make metrics LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2 METRIC_SAMPLES=10000
```

Group 8 default resource analysis:

```sh
make resources LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2
```

Full 32-configuration sweep:

```sh
make sweep32 METRIC_SAMPLES=10000
```

Quick 32-configuration sweep without synthesis:

```sh
make sweep32_quick METRIC_SAMPLES=10000
```

All-configuration resource CSV:

```sh
make resources32
```

The sweep writes:

- `build/config_sweep/results.csv`

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

## Resource Consumption Analysis

The resource analyzer uses Yosys synthesis logs and writes CSV summaries.

Single configuration:

```sh
make resources LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2
```

Output:

- `build/resource_analysis/resources.csv`

All 32 assigned configurations:

```sh
make resources32
```

Output:

- `build/resource_analysis/resources32.csv`

The CSV includes:

- configuration id
- table label
- LOA `k`
- `M0..M3` settings
- total synthesized cells
- hierarchy cell count
- `$_AND_`, `$_MUX_`, `$_OR_`, `$_XOR_` counts
- wire and port counts

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

Explicit real-board combined analysis over UART:

```sh
make combined_board LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2
```

If you pass `LOA_K` or any `M0..M3` override to `make combined`, it switches to single-configuration mode and writes `build/combined_analysis/combined.csv` instead of the full `combined32.csv`.

All 32 configurations in one combined CSV:

```sh
make combined32 METRIC_SAMPLES=2000
```

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

Run PicoSoC simulation:

```sh
make -C picorv32/picosoc sim
make board_sim LOA_K=6 M0_APPROX=0 M1_APPROX=6 M2_APPROX=6 M3_APPROX=6
```

Run place-and-route for iCEBreaker:

```sh
make -C picorv32/picosoc pnr
make board_pnr LOA_K=6 M0_APPROX=0 M1_APPROX=6 M2_APPROX=6 M3_APPROX=6
```

Program BRAM image:

```sh
make make_prog
make board_prog LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2
```

Build and program a selected configuration in one step:

```sh
make board_test LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2
```

Run the cloned Dhrystone + `mul16` benchmark in simulation:

```sh
make board_bench_sim LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2
```

Build and program the cloned Dhrystone + `mul16` benchmark:

```sh
make board_bench_test LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2
```

## Full Board Run

If the iCEBreaker is connected, this is the recommended end-to-end flow.

1. Open a serial monitor on the board UART at `115200` baud using your preferred terminal program.
2. From the repository root, build and program the normal `mul16` demo:

```sh
make board_test LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2
```

3. Watch the UART output for the demo banner and checksum.
4. For the benchmark-style run that executes Dhrystone and then the custom `mul16` benchmark, use:

```sh
make board_bench_test LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2
```

5. Watch the UART output for:

- the Dhrystone banner and summary
- the `mul16 iters`, `mul16 cycles`, and `mul16 checksum` lines

6. The LED register is also updated with the final checksum, so the board LEDs provide a simple visible completion indicator.

Useful intermediate commands:

```sh
make board_sim LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2
make board_bench_sim LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2
make board_pnr LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2
make board_prog LOA_K=4 M0_APPROX=2 M1_APPROX=2 M2_APPROX=2 M3_APPROX=2
```

To test a different table entry on hardware, change both the LOA and block settings. Example:

```sh
make board_bench_test LOA_K=6 M0_APPROX=0 M1_APPROX=6 M2_APPROX=6 M3_APPROX=6
```

That corresponds to `E_66_66_66 b`.

The current integrated build has already been verified to pass the `13 MHz` iCEBreaker target in the PNR flow.

Task 3 build placement:

- synthesis/place-and-route for combined analysis now uses `picorv32/scripts/icestorm/Makefile` with `make all`
- board programming still uses `make prog_bram` in `picorv32/picosoc/Makefile`

On-board testing notes:

- `board_test` automates build, place-and-route, and BRAM programming
- `board_bench_test` does the same using the alternate firmware from `dhrystone_clone/`
- after programming, the firmware runs `100` custom `mul16` instructions automatically
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
- root-level metric estimation
- root-level synthesis
- quick 32-configuration sweep generation
- PicoSoC simulation on iCEBreaker testbench
- PicoSoC place-and-route meeting the 13 MHz target

## Limitations

- the 8x8 approximate family is currently a best-effort structural model derived from the available slides
- if your lab provides the exact internal `22/44/55/66` block diagram later, `group8/rtl/v2_8x8_multiplier.v` should be updated accordingly
- after replacing that model, rerun simulation, synthesis, metrics, and the sweep

## Related Documentation

- `group8/README.md`: focused Group 8 notes and current results
- `dhrystone_clone/README.md`: separate benchmark workspace for Dhrystone + `mul16`
- `picorv32/README.md`: upstream PicoRV32 documentation
- `picorv32/picosoc/README.md`: upstream PicoSoC notes
