#ifndef DHRYSTONE_CLONE_MUL16_BENCH_H
#define DHRYSTONE_CLONE_MUL16_BENCH_H

#include <stdint.h>

struct mul16_bench_report {
	uint32_t iterations;
	uint32_t cycles;
	uint32_t checksum;
};

void run_mul16_bench(struct mul16_bench_report *report, uint32_t iterations);

#endif
