#include <stdint.h>
#include "mul16.h"

#define reg_uart_clkdiv (*(volatile uint32_t*)0x02000004)
#define reg_uart_data   (*(volatile uint32_t*)0x02000008)

void putchar(char c)
{
	if (c == '\n') putchar('\r');
	reg_uart_data = c;
}

static void print(const char *p)
{
	while (*p) putchar(*(p++));
}

static void print_dec(uint32_t v)
{
	static const uint32_t pow10[] = {
		1000000000, 100000000, 10000000, 1000000,
		100000, 10000, 1000, 100, 10, 1
	};
	if (v == 0) { putchar('0'); return; }
	int leading = 1;
	for (int i = 0; i < 10; i++) {
		int digit = 0;
		while (v >= pow10[i]) { v -= pow10[i]; digit++; }
		if (digit || !leading) { putchar('0' + digit); leading = 0; }
	}
}

volatile uint32_t demo_result;

int main(void)
{
	reg_uart_clkdiv = 104; /* 12 MHz / 115200 baud */

	uint16_t a = 0x1234;
	uint16_t b = 0x5678;

	demo_result = mul16(a, b);

	print("a     = "); print_dec(a); print("\n");
	print("b     = "); print_dec(b); print("\n");
	print("a * b = "); print_dec(demo_result); print("\n");

	return 0;
}
