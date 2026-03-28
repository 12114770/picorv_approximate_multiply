#ifndef GROUP8_MUL16_H
#define GROUP8_MUL16_H

#include <stdint.h>

#define MUL16_CUSTOM_OPCODE 0x0b
#define MUL16_CUSTOM_FUNCT3 0
#define MUL16_CUSTOM_FUNCT7 42

static inline uint32_t mul16_pcpi_u16(uint32_t lhs, uint32_t rhs)
{
	uint32_t rd;
	uint32_t rs1 = lhs & 0xffffu;
	uint32_t rs2 = rhs & 0xffffu;

	asm volatile (
		".insn r "
		"%3, %4, %5, %0, %1, %2"
		: "=r" (rd)
		: "r" (rs1), "r" (rs2),
		  "i" (MUL16_CUSTOM_OPCODE),
		  "i" (MUL16_CUSTOM_FUNCT3),
		  "i" (MUL16_CUSTOM_FUNCT7)
	);

	return rd;
}

#define mul16(lhs, rhs) mul16_pcpi_u16((uint32_t)(lhs), (uint32_t)(rhs))

#endif
