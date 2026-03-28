`timescale 1 ns / 1 ps

module approx_mul16_loa #(
	parameter integer LOA_K = 4,
	parameter [8*22-1:0] V2_IMPLEMENTATION = "PLACEHOLDER_EXACT"
) (
	input  [15:0] a,
	input  [15:0] b,
	output [31:0] p
);
	// 16x16 decomposition:
	// M0 = A[ 7:0] * B[ 7:0]
	// M1 = A[ 7:0] * B[15:8]
	// M2 = A[15:8] * B[ 7:0]
	// M3 = A[15:8] * B[15:8]
	//
	// Accumulation uses the low byte of M0 exactly and applies the LOA only to
	// the overlapping upper slice [31:8]:
	//   upper0 = M0[15:8]
	//   upper1 = M1
	//   upper2 = M2
	//   upper3 = (M3 << 8)
	//   upper_sum = LOA(LOA(upper0, upper1), LOA(upper2, upper3))
	//   P = {upper_sum, M0[7:0]}
	//
	// This mapping preserves the standard 8x8 decomposition while ensuring that
	// k = 4 or 6 actually approximates overlapping accumulation bits.

	wire [15:0] m0;
	wire [15:0] m1;
	wire [15:0] m2;
	wire [15:0] m3;

	wire [23:0] upper0;
	wire [23:0] upper1;
	wire [23:0] upper2;
	wire [23:0] upper3;

	wire [23:0] stage0_sum;
	wire [23:0] stage1_sum;
	wire [23:0] stage2_sum;
	wire        unused_carry0;
	wire        unused_carry1;
	wire        unused_carry2;

	v2_8x8_multiplier #(
		.V2_IMPLEMENTATION(V2_IMPLEMENTATION)
	) u_m0 (
		.a(a[7:0]),
		.b(b[7:0]),
		.p(m0)
	);

	v2_8x8_multiplier #(
		.V2_IMPLEMENTATION(V2_IMPLEMENTATION)
	) u_m1 (
		.a(a[7:0]),
		.b(b[15:8]),
		.p(m1)
	);

	v2_8x8_multiplier #(
		.V2_IMPLEMENTATION(V2_IMPLEMENTATION)
	) u_m2 (
		.a(a[15:8]),
		.b(b[7:0]),
		.p(m2)
	);

	v2_8x8_multiplier #(
		.V2_IMPLEMENTATION(V2_IMPLEMENTATION)
	) u_m3 (
		.a(a[15:8]),
		.b(b[15:8]),
		.p(m3)
	);

	assign upper0 = {16'b0, m0[15:8]};
	assign upper1 = {8'b0, m1};
	assign upper2 = {8'b0, m2};
	assign upper3 = {m3, 8'b0};

	loa_adder #(
		.WIDTH(24),
		.K(LOA_K)
	) u_add0 (
		.a(upper0),
		.b(upper1),
		.sum(stage0_sum),
		.carry_out(unused_carry0)
	);

	loa_adder #(
		.WIDTH(24),
		.K(LOA_K)
	) u_add1 (
		.a(upper2),
		.b(upper3),
		.sum(stage1_sum),
		.carry_out(unused_carry1)
	);

	loa_adder #(
		.WIDTH(24),
		.K(LOA_K)
	) u_add2 (
		.a(stage0_sum),
		.b(stage1_sum),
		.sum(stage2_sum),
		.carry_out(unused_carry2)
	);

	assign p = {stage2_sum, m0[7:0]};
endmodule
