#include <stdint.h>
#include "mul16.h"

#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)
#define reg_uart_data   (*(volatile uint32_t*)0x02000008)
#define reg_leds        (*(volatile uint32_t*)0x03000000)

void putchar(char c)
{
	if (c == '\n') putchar('\r');
	reg_uart_data = c;
}

static void print(const char *p)
{
	while (*p) putchar(*(p++));
}

static void print_hex32(uint32_t v)
{
	for (int i = 7; i >= 0; i--)
		putchar("0123456789abcdef"[(v >> (4 * i)) & 15]);
}

static uint32_t xorshift32(uint32_t *state)
{
	uint32_t x = *state;
	x ^= x << 13;
	x ^= x >> 17;
	x ^= x << 5;
	*state = x;
	return x;
}

static uint32_t rdcycle(void)
{
	uint32_t v;
	asm volatile ("rdcycle %0" : "=r"(v));
	return v;
}

void main(void)
{
	uint32_t seed = 1;
	uint32_t checksum = 0;
	uint32_t i;
	uint32_t t0, t1;

	reg_uart_clkdiv = 104;

#ifdef USE_EXACT_MUL
	print("mul16_exact\n");
#else
	print("mul16_pcpi\n");
#endif

	t0 = rdcycle();
	for (i = 0; i < 100; i++) {
		uint16_t a = (uint16_t)(xorshift32(&seed) & 0xffffu);
		uint16_t b = (uint16_t)(xorshift32(&seed) & 0xffffu);
#ifdef USE_EXACT_MUL
		uint32_t result = (uint32_t)a * (uint32_t)b;
#else
		uint32_t result = mul16(a, b);
#endif
		checksum ^= result + ((uint32_t)i << 16);
	}
	t1 = rdcycle();

	print("iters=0x0064 cycles=0x");
	print_hex32(t1 - t0);
	print(" checksum=0x");
	print_hex32(checksum);
	print("\n");
	reg_leds = checksum;
	print("BENCH_DONE\n");

	for (;;)
		asm volatile ("nop");
}
