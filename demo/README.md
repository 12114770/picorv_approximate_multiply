# Approximate Multiplier Demo

This directory contains a demo of an implementation of the
16x16 approximate multiplier, with the same structure as described
in the task 2 description.

## Description

In the [designs](designs) directory the hardware source files are located, namely a synthesised design and a placed and routed design. Of course we won't provide the full RTL source codes, as that is your task.

## Approximate Multiplier Simulation and Error Metrics Demo

The [synthesised design](designs/approx_mul.v) is an 16x16 approximate multiplier and can be simulated by using the make target:

`````
make sim_demo
`````

This target then simulates the design and calculates the error metrics by using
the [python script](scripts/calc_error_metrics.py). After running the script (can take a while depending on the number of inputs set in the make file) the error metrics can be found in the [error_metrics.txt](build/sim/error_metrics.txt) file. It is to note that like described in the introduction slides for task
two, the state of the art literature uses one million input values. For a none
synthesised design this should take less time. It is also to note that one can
for example use system verilog test benches and randomize the values inside
the test bench by using system verilog built in randomization features.

## Approximate Multiplier Hardware Benchmark Demo

We also provide a hardware demo, containing the picosoc, the approximate multiplier and the multiplier of the PicoRV32. This comes in the form of a
already [synthesised, placed and routed design](designs/icebreaker.asc).

The software to compare the exact and approximate multiplier on hardware
can be found in the software directory in the [benchmark.c](software/benchmark.c) file. By running the target:

`````
make demo_software
`````

the software is compiled, and by running:

`````
make demo
`````

the software replaces the random hex file content in the routed design and is
packed into a bitstream. Finally by running the target:

`````
make prog_demo
`````

The hardware including the benchmark software will be loaded onto the FPGA and
a serial monitor can be used to run the benchmark on hardware. The comparison
on hardware contains the cycles used to calculate the multiplication in the
exact and approximated case and will compare the results (only absolute value comparison no error metrics.)