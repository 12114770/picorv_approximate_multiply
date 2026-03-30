/*
 * Alternate board firmware for Task 3.
 * Runs upstream Dhrystone first and then a dedicated mul16 benchmark.
 */

#include <stdint.h>

#include "mul16_bench.h"
#include "../picorv32/dhrystone/dhry_top.h"

extern int printf(const char *format, ...);
extern long User_Time;

#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)
#define reg_uart_data (*(volatile uint32_t*)0x02000008)
#define reg_leds (*(volatile uint32_t*)0x03000000)

void putchar(char c)
{
	if (c == '\n')
		putchar('\r');
	reg_uart_data = c;
}

static void print(const char *p)
{
	while (*p)
		putchar(*(p++));
}

int main(void)
{
	struct mul16_bench_report report;
	int dhrystones_per_second_mhz;
	int dmips_per_mhz_x1000;

	reg_uart_clkdiv = 104;
	print("mul16+dhrystone\n");

	run_dhrystone();
	run_mul16_bench(&report, 1000);
	dhrystones_per_second_mhz = (100 * 1000000) / User_Time;
	dmips_per_mhz_x1000 = (1000 * dhrystones_per_second_mhz) / 1757;

	printf("mul16 iters: %d\n", report.iterations);
	printf("mul16 cycles: %d\n", report.cycles);
	printf("mul16 checksum: 0x%x\n", report.checksum);
	printf("BENCH_DONE checksum=0x%x\n", report.checksum);

	reg_leds = report.checksum;
	for (;;) {
		printf("BENCH_DONE dmips_per_mhz=%d.%03d mul16_cycles=%d checksum=0x%x\n",
			dmips_per_mhz_x1000 / 1000,
			dmips_per_mhz_x1000 % 1000,
			report.cycles,
			report.checksum);
		for (volatile uint32_t delay = 0; delay < 200000; ++delay)
			asm volatile ("nop");
	}
}
