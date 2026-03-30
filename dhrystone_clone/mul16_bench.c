#include <stdint.h>

#include "mul16_bench.h"
#include "../group8/sw/mul16.h"

static uint32_t xorshift32(uint32_t *state)
{
	uint32_t x = *state;
	x ^= x << 13;
	x ^= x >> 17;
	x ^= x << 5;
	*state = x;
	return x;
}

static uint32_t read_cycle_counter(void)
{
	uint32_t value;
	asm volatile ("rdcycle %0" : "=r" (value));
	return value;
}

void run_mul16_bench(struct mul16_bench_report *report, uint32_t iterations)
{
	uint32_t seed = 1;
	uint32_t checksum = 0;
	uint32_t start_cycles;
	uint32_t end_cycles;
	uint32_t i;

	start_cycles = read_cycle_counter();

	for (i = 0; i < iterations; ++i) {
		uint16_t a = xorshift32(&seed) & 0xffffu;
		uint16_t b = xorshift32(&seed) & 0xffffu;
		uint32_t product = mul16(a, b);
		checksum ^= product + (i << 8);
	}

	end_cycles = read_cycle_counter();

	report->iterations = iterations;
	report->cycles = end_cycles - start_cycles;
	report->checksum = checksum;
}
