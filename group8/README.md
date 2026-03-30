# Group 8 Approximate Unsigned 16x16 Multiplier

## Architecture

The design builds a 16x16 unsigned multiplier from four reusable 8x8 blocks:

- `M0 = A[7:0] * B[7:0]`
- `M1 = A[7:0] * B[15:8]`
- `M2 = A[15:8] * B[7:0]`
- `M3 = A[15:8] * B[15:8]`

To match the project requirement, all four blocks use the same `v2_8x8_multiplier` module. Because the course material available in this workspace still does not fully specify the internal `22` netlist, the current implementation uses a best-effort `22` model: the 8x8 multiplication is split into two 8x4 B-groups, and each group suppresses its two least-significant local bits before recombination. The surrounding hierarchy is unchanged, so a stricter course-provided `22` block can still be inserted later if needed.

Accumulation uses a Lower-part OR Adder (LOA). The low byte of `M0` is forwarded directly because it does not overlap with any other partial product. The overlapping upper 24-bit accumulation region is combined with a three-stage LOA tree. The LOA lower `k` bits use bitwise OR and the upper bits are added exactly with carry injection from bit `k-1`, matching the intended LOA style.

For Group 8, the required LOA configuration is `k = 4` only (`k-version a`).

## Files

- `group8/rtl/v2_8x8_multiplier.v` - reusable V2 block shell
- `group8/rtl/loa_adder.v` - parameterized LOA adder
- `group8/rtl/approx_mul16_loa.v` - parameterized 16x16 top level
- `group8/rtl/approx_mul16_loa_k4.v` - fixed `k=4` wrapper
- `group8/rtl/picorv32_pcpi_mul16_approx.v` - custom PCPI instruction core
- `group8/rtl/picorv32_mul16_system.v` - PicoRV32 wrapper that hooks up the PCPI core
- `group8/tb/approx_mul16_loa_tb.v` - multiplier testbench
- `group8/tb/picorv32_pcpi_mul16_tb.v` - PCPI core testbench
- `group8/sw/mul16.h` - software macro/helper for the custom instruction
- `group8/sw/mul16_demo.c` - minimal software example
- `group8/scripts/evaluate_mul16.py` - NMED/MRED estimation helper
- `Makefile` - automation for simulation, synthesis, and metrics

## Why this multiplier for PCPI

The PCPI-exported version uses the same Group 8 architecture: `22_22_22_22` 8x8 decomposition with LOA accumulation at `k=4` (`k-version a`). This is the natural choice because it is exactly the multiplier required by the assignment, it has a modular structure, and it exposes a full 32-bit unsigned product from two 16-bit operands in a single custom instruction.

## Current measured results

These numbers are based on the current best-effort `22` 8x8 model.

Random metric estimate over 10,000 vectors for the required Group 8 setting:

- `k=4`: `NMED = 0.0000002792`, `MRED = 0.0000140432`

Yosys generic-cell synthesis results:

- `k=4`: `2065` total cells

## Simulation

Top-level multiplier testbench:

```sh
make sim LOA_K=4
```

PCPI core testbench:

```sh
make sim LOA_K=4 TESTBENCH=group8/tb/picorv32_pcpi_mul16_tb.v TBTOP=picorv32_pcpi_mul16_tb
```

The default waveform path is generated under `build/sim/` and can be overridden with `VCD=...`.

## Synthesis

```sh
make synth LOA_K=4
```

Outputs:

- netlists in `build/synth/`
- synthesis logs in `build/synth/`

## Error Metrics

```sh
make metrics LOA_K=4 METRIC_SAMPLES=100000
```

## Group 8 configuration

Group 8 uses:

- `M0 = 22`
- `M1 = 22`
- `M2 = 22`
- `M3 = 22`
- `LOA k = 4` (`k-version a`)

In the current codebase, the Group 8 flow therefore uses `LOA_K=4` throughout software and PCPI integration.

## Custom instruction / software macro

The helper in `group8/sw/mul16.h` provides:

```c
#define mul16(lhs, rhs) mul16_pcpi_u16((uint32_t)(lhs), (uint32_t)(rhs))
```

It emits a custom R-type instruction using:

- opcode: `0x0b`
- funct3: `0`
- funct7: `42`

The hardware consumes `rs1[15:0]` and `rs2[15:0]` and returns the approximate 32-bit product.

## Assumption to replace later

If your lab later gives a stricter `22` cell-by-cell block diagram, replace the current best-effort internals of `group8/rtl/v2_8x8_multiplier.v` with that exact architecture and rerun `make sim`, `make synth`, and `make metrics`.
