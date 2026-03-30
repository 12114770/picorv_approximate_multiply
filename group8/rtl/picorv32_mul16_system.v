`timescale 1 ns / 1 ps

module picorv32_mul16_system #(
	parameter integer LOA_K = 4,
	parameter [ 0:0] ENABLE_COUNTERS = 1,
	parameter [ 0:0] ENABLE_COUNTERS64 = 1,
	parameter [ 0:0] ENABLE_REGS_16_31 = 1,
	parameter [ 0:0] ENABLE_REGS_DUALPORT = 1,
	parameter [ 0:0] LATCHED_MEM_RDATA = 0,
	parameter [ 0:0] TWO_STAGE_SHIFT = 1,
	parameter [ 0:0] BARREL_SHIFTER = 0,
	parameter [ 0:0] TWO_CYCLE_COMPARE = 0,
	parameter [ 0:0] TWO_CYCLE_ALU = 0,
	parameter [ 0:0] COMPRESSED_ISA = 0,
	parameter [ 0:0] CATCH_MISALIGN = 1,
	parameter [ 0:0] CATCH_ILLINSN = 1,
	parameter [ 0:0] ENABLE_IRQ = 0,
	parameter [ 0:0] ENABLE_IRQ_QREGS = 1,
	parameter [ 0:0] ENABLE_IRQ_TIMER = 1,
	parameter [ 0:0] ENABLE_TRACE = 0,
	parameter [ 0:0] REGS_INIT_ZERO = 0,
	parameter [31:0] MASKED_IRQ = 32'h0000_0000,
	parameter [31:0] LATCHED_IRQ = 32'hffff_ffff,
	parameter [31:0] PROGADDR_RESET = 32'h0000_0000,
	parameter [31:0] PROGADDR_IRQ = 32'h0000_0010,
	parameter [31:0] STACKADDR = 32'hffff_ffff
) (
	input             clk,
	input             resetn,
	output            trap,
	output            mem_valid,
	output            mem_instr,
	input             mem_ready,
	output     [31:0] mem_addr,
	output     [31:0] mem_wdata,
	output     [ 3:0] mem_wstrb,
	output            mem_la_read,
	output            mem_la_write,
	output     [31:0] mem_la_addr,
	output     [31:0] mem_la_wdata,
	output     [ 3:0] mem_la_wstrb,
	input      [31:0] mem_rdata,
	input      [31:0] irq,
	output     [31:0] eoi,
	output            trace_valid,
	output     [35:0] trace_data
);
	wire        pcpi_valid;
	wire [31:0] pcpi_insn;
	wire [31:0] pcpi_rs1;
	wire [31:0] pcpi_rs2;
	wire        pcpi_wr;
	wire [31:0] pcpi_rd;
	wire        pcpi_wait;
	wire        pcpi_ready;

	picorv32 #(
		.ENABLE_COUNTERS(ENABLE_COUNTERS),
		.ENABLE_COUNTERS64(ENABLE_COUNTERS64),
		.ENABLE_REGS_16_31(ENABLE_REGS_16_31),
		.ENABLE_REGS_DUALPORT(ENABLE_REGS_DUALPORT),
		.LATCHED_MEM_RDATA(LATCHED_MEM_RDATA),
		.TWO_STAGE_SHIFT(TWO_STAGE_SHIFT),
		.BARREL_SHIFTER(BARREL_SHIFTER),
		.TWO_CYCLE_COMPARE(TWO_CYCLE_COMPARE),
		.TWO_CYCLE_ALU(TWO_CYCLE_ALU),
		.COMPRESSED_ISA(COMPRESSED_ISA),
		.CATCH_MISALIGN(CATCH_MISALIGN),
		.CATCH_ILLINSN(CATCH_ILLINSN),
		.ENABLE_PCPI(1),
		.ENABLE_MUL(0),
		.ENABLE_FAST_MUL(0),
		.ENABLE_DIV(0),
		.ENABLE_IRQ(ENABLE_IRQ),
		.ENABLE_IRQ_QREGS(ENABLE_IRQ_QREGS),
		.ENABLE_IRQ_TIMER(ENABLE_IRQ_TIMER),
		.ENABLE_TRACE(ENABLE_TRACE),
		.REGS_INIT_ZERO(REGS_INIT_ZERO),
		.MASKED_IRQ(MASKED_IRQ),
		.LATCHED_IRQ(LATCHED_IRQ),
		.PROGADDR_RESET(PROGADDR_RESET),
		.PROGADDR_IRQ(PROGADDR_IRQ),
		.STACKADDR(STACKADDR)
	) cpu (
		.clk(clk),
		.resetn(resetn),
		.trap(trap),
		.mem_valid(mem_valid),
		.mem_instr(mem_instr),
		.mem_ready(mem_ready),
		.mem_addr(mem_addr),
		.mem_wdata(mem_wdata),
		.mem_wstrb(mem_wstrb),
		.mem_la_read(mem_la_read),
		.mem_la_write(mem_la_write),
		.mem_la_addr(mem_la_addr),
		.mem_la_wdata(mem_la_wdata),
		.mem_la_wstrb(mem_la_wstrb),
		.mem_rdata(mem_rdata),
		.pcpi_valid(pcpi_valid),
		.pcpi_insn(pcpi_insn),
		.pcpi_rs1(pcpi_rs1),
		.pcpi_rs2(pcpi_rs2),
		.pcpi_wr(pcpi_wr),
		.pcpi_rd(pcpi_rd),
		.pcpi_wait(pcpi_wait),
		.pcpi_ready(pcpi_ready),
		.irq(irq),
		.eoi(eoi),
		.trace_valid(trace_valid),
		.trace_data(trace_data)
	);

	picorv32_pcpi_mul16_approx #(
		.LOA_K(LOA_K)
	) pcpi_mul16 (
		.clk(clk),
		.resetn(resetn),
		.pcpi_valid(pcpi_valid),
		.pcpi_insn(pcpi_insn),
		.pcpi_rs1(pcpi_rs1),
		.pcpi_rs2(pcpi_rs2),
		.pcpi_wr(pcpi_wr),
		.pcpi_rd(pcpi_rd),
		.pcpi_wait(pcpi_wait),
		.pcpi_ready(pcpi_ready)
	);
endmodule
