#include <stdint.h>

#include "mul16.h"

volatile uint32_t demo_result;

int main(void)
{
	uint16_t a = 0x1234;
	uint16_t b = 0x5678;

	demo_result = mul16(a, b);
	return 0;
}
