`timescale 1 ns / 1 ps

module picorv32_pcpi_mul16_tb;
	parameter integer LOA_K = 4;
	parameter integer M0_APPROX = 2;
	parameter integer M1_APPROX = 2;
	parameter integer M2_APPROX = 2;
	parameter integer M3_APPROX = 2;
	localparam [6:0] CUSTOM_OPCODE = 7'b0001011;
	localparam [2:0] CUSTOM_FUNCT3 = 3'b000;
	localparam [6:0] CUSTOM_FUNCT7 = 7'b0101010;

	reg clk;
	reg resetn;
	reg pcpi_valid;
	reg [31:0] pcpi_insn;
	reg [31:0] pcpi_rs1;
	reg [31:0] pcpi_rs2;
	wire pcpi_wr;
	wire [31:0] pcpi_rd;
	wire pcpi_wait;
	wire pcpi_ready;
	wire [31:0] expected;

	picorv32_pcpi_mul16_approx #(
		.LOA_K(LOA_K),
		.M0_APPROX(M0_APPROX),
		.M1_APPROX(M1_APPROX),
		.M2_APPROX(M2_APPROX),
		.M3_APPROX(M3_APPROX),
		.CUSTOM_OPCODE(CUSTOM_OPCODE),
		.CUSTOM_FUNCT3(CUSTOM_FUNCT3),
		.CUSTOM_FUNCT7(CUSTOM_FUNCT7)
	) dut (
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

	approx_mul16_loa #(
		.LOA_K(LOA_K),
		.M0_APPROX(M0_APPROX),
		.M1_APPROX(M1_APPROX),
		.M2_APPROX(M2_APPROX),
		.M3_APPROX(M3_APPROX)
	) ref_model (
		.a(pcpi_rs1[15:0]),
		.b(pcpi_rs2[15:0]),
		.p(expected)
	);

	always #5 clk = ~clk;

	initial begin
		clk = 1'b0;
		resetn = 1'b0;
		pcpi_valid = 1'b0;
		pcpi_insn = 32'b0;
		pcpi_rs1 = 32'b0;
		pcpi_rs2 = 32'b0;

		repeat (2) @(posedge clk);
		resetn = 1'b1;

		pcpi_rs1 = 32'h00001234;
		pcpi_rs2 = 32'h00005678;
		pcpi_insn = {CUSTOM_FUNCT7, 5'd2, 5'd1, CUSTOM_FUNCT3, 5'd3, CUSTOM_OPCODE};
		pcpi_valid = 1'b1;
		@(posedge clk);
		pcpi_valid = 1'b0;

		@(negedge clk);
		if (!pcpi_ready || !pcpi_wr || pcpi_wait || pcpi_rd !== expected) begin
			$display("PCPI TEST FAILED k=%0d rd=0x%08x expected=0x%08x ready=%b wr=%b wait=%b",
				LOA_K, pcpi_rd, expected, pcpi_ready, pcpi_wr, pcpi_wait);
			$finish(1);
		end

		$display("PCPI TEST PASSED k=%0d rd=0x%08x", LOA_K, pcpi_rd);
		$finish;
	end
endmodule
