`timescale 1 ns / 1 ps

module approx_mul16_iter_datapath #(
	parameter integer LOA_K = 4,
	parameter integer M0_APPROX = 2,
	parameter integer M1_APPROX = 2,
	parameter integer M2_APPROX = 2,
	parameter integer M3_APPROX = 2
) (
	input             clk,
	input             resetn,
	input             load_operands,
	input             capture_partial,
	input      [1:0]  partial_sel,
	input             capture_stage0,
	input             capture_stage1,
	input             capture_stage2,
	input      [15:0] a_in,
	input      [15:0] b_in,
	output     [31:0] result
);
	reg [15:0] a_reg;
	reg [15:0] b_reg;
	reg [15:0] m0_reg;
	reg [15:0] m1_reg;
	reg [15:0] m2_reg;
	reg [15:0] m3_reg;
	reg [23:0] stage0_reg;
	reg [23:0] stage1_reg;
	reg [23:0] stage2_reg;

	reg  [7:0] mul_a;
	reg  [7:0] mul_b;
	wire [15:0] mul_p0;
	wire [15:0] mul_p1;
	wire [15:0] mul_p2;
	wire [15:0] mul_p3;
	reg  [15:0] mul_p;

	wire [23:0] upper0 = {16'b0, m0_reg[15:8]};
	wire [23:0] upper1 = {8'b0, m1_reg};
	wire [23:0] upper2 = {8'b0, m2_reg};
	wire [23:0] upper3 = {m3_reg, 8'b0};

	wire [23:0] loa_sum0;
	wire [23:0] loa_sum1;
	wire [23:0] loa_sum2;
	wire        unused_carry0;
	wire        unused_carry1;
	wire        unused_carry2;

	always @* begin
		case (partial_sel)
			2'd0: begin
				mul_a = a_reg[7:0];
				mul_b = b_reg[7:0];
			end
			2'd1: begin
				mul_a = a_reg[7:0];
				mul_b = b_reg[15:8];
			end
			2'd2: begin
				mul_a = a_reg[15:8];
				mul_b = b_reg[7:0];
			end
			default: begin
				mul_a = a_reg[15:8];
				mul_b = b_reg[15:8];
			end
		endcase
	end

	v2_8x8_multiplier #(
		.APPROX_GROUP_B(M0_APPROX),
		.APPROX_GROUP_A(M0_APPROX)
	) v2_mul0 (
		.a(mul_a),
		.b(mul_b),
		.p(mul_p0)
	);

	v2_8x8_multiplier #(
		.APPROX_GROUP_B(M1_APPROX),
		.APPROX_GROUP_A(M1_APPROX)
	) v2_mul1 (
		.a(mul_a),
		.b(mul_b),
		.p(mul_p1)
	);

	v2_8x8_multiplier #(
		.APPROX_GROUP_B(M2_APPROX),
		.APPROX_GROUP_A(M2_APPROX)
	) v2_mul2 (
		.a(mul_a),
		.b(mul_b),
		.p(mul_p2)
	);

	v2_8x8_multiplier #(
		.APPROX_GROUP_B(M3_APPROX),
		.APPROX_GROUP_A(M3_APPROX)
	) v2_mul3 (
		.a(mul_a),
		.b(mul_b),
		.p(mul_p3)
	);

	always @* begin
		case (partial_sel)
			2'd0: mul_p = mul_p0;
			2'd1: mul_p = mul_p1;
			2'd2: mul_p = mul_p2;
			default: mul_p = mul_p3;
		endcase
	end

	loa_adder #(
		.WIDTH(24),
		.K(LOA_K)
	) loa0 (
		.a(upper0),
		.b(upper1),
		.sum(loa_sum0),
		.carry_out(unused_carry0)
	);

	loa_adder #(
		.WIDTH(24),
		.K(LOA_K)
	) loa1 (
		.a(upper2),
		.b(upper3),
		.sum(loa_sum1),
		.carry_out(unused_carry1)
	);

	loa_adder #(
		.WIDTH(24),
		.K(LOA_K)
	) loa2 (
		.a(stage0_reg),
		.b(stage1_reg),
		.sum(loa_sum2),
		.carry_out(unused_carry2)
	);

	always @(posedge clk) begin
		if (!resetn) begin
			a_reg <= 16'b0;
			b_reg <= 16'b0;
			m0_reg <= 16'b0;
			m1_reg <= 16'b0;
			m2_reg <= 16'b0;
			m3_reg <= 16'b0;
			stage0_reg <= 24'b0;
			stage1_reg <= 24'b0;
			stage2_reg <= 24'b0;
		end else begin
			if (load_operands) begin
				a_reg <= a_in;
				b_reg <= b_in;
			end

			if (capture_partial) begin
				case (partial_sel)
					2'd0: m0_reg <= mul_p;
					2'd1: m1_reg <= mul_p;
					2'd2: m2_reg <= mul_p;
					default: m3_reg <= mul_p;
				endcase
			end

			if (capture_stage0)
				stage0_reg <= loa_sum0;

			if (capture_stage1)
				stage1_reg <= loa_sum1;

			if (capture_stage2)
				stage2_reg <= loa_sum2;
		end
	end

	assign result = {stage2_reg, m0_reg[7:0]};
endmodule
