# Dhrystone Clone

This directory is a separate benchmark workspace used for Task 3 board testing.

It does not modify the upstream PicoSoC Dhrystone sources in `picorv32/picosoc/dhrystone/`.
Instead, it adds a custom `mul16` benchmark path that can be built as an alternate
PicoSoC firmware image.

Files:

- `firmware_dhrystone_mul16.c`: alternate board firmware
- `mul16_bench.c`: benchmark loop that exercises the custom `mul16` PCPI instruction
- `mul16_bench.h`: benchmark interface

The firmware runs:

1. the existing Dhrystone benchmark
2. a dedicated `mul16` benchmark loop using the approximate multiplier

This is intended for board-level validation that the custom instruction is working
inside a benchmark-style workload.
