`timescale 1 ns / 1 ps

module picorv32_pcpi_mul16_approx #(
	parameter integer LOA_K = 4,
	parameter [6:0] CUSTOM_OPCODE = 7'b0001011,
	parameter [2:0] CUSTOM_FUNCT3 = 3'b000,
	parameter [6:0] CUSTOM_FUNCT7 = 7'b0101010
) (
	input             clk,
	input             resetn,
	input             pcpi_valid,
	input      [31:0] pcpi_insn,
	input      [31:0] pcpi_rs1,
	input      [31:0] pcpi_rs2,
	output reg        pcpi_wr,
	output reg [31:0] pcpi_rd,
	output            pcpi_wait,
	output reg        pcpi_ready
);
	wire insn_mul16;
	wire [31:0] approx_product;

	assign insn_mul16 = pcpi_valid &&
		(pcpi_insn[6:0]   == CUSTOM_OPCODE) &&
		(pcpi_insn[14:12] == CUSTOM_FUNCT3) &&
		(pcpi_insn[31:25] == CUSTOM_FUNCT7);

	approx_mul16_loa #(
		.LOA_K(LOA_K)
	) u_mul16 (
		.a(pcpi_rs1[15:0]),
		.b(pcpi_rs2[15:0]),
		.p(approx_product)
	);

	assign pcpi_wait = 1'b0;

	always @(posedge clk) begin
		if (!resetn) begin
			pcpi_wr <= 1'b0;
			pcpi_ready <= 1'b0;
			pcpi_rd <= 32'b0;
		end else begin
			pcpi_wr <= insn_mul16;
			pcpi_ready <= insn_mul16;
			pcpi_rd <= approx_product;
		end
	end
endmodule
