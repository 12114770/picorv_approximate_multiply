`timescale 1 ns / 1 ps

module approx_mul16_loa #(
	parameter integer LOA_K = 4,
	parameter integer M0_APPROX = 2,
	parameter integer M1_APPROX = 2,
	parameter integer M2_APPROX = 2,
	parameter integer M3_APPROX = 2
) (
	input  [15:0] a,
	input  [15:0] b,
	output [31:0] p
);

	wire [15:0] m0;
	wire [15:0] m1;
	wire [15:0] m2;
	wire [15:0] m3;

	wire [7:0] part_sum0; //m0_h + m1_l 
	wire [7:0] part_sum1; //m2_l + part_sum0
	wire [7:0] part_sum2; //m1_h + m2_h
	wire [7:0] part_sum3; //m3_l + part_sum2

	v2_8x8_multiplier #(
		.APPROX_GROUP_B(M0_APPROX),
		.APPROX_GROUP_A(M0_APPROX),
		.APPROX_LOA(LOA_K)
	) u_m0 (
		.a(a[7:0]),
		.b(b[7:0]),
		.p(m0)
	);

	v2_8x8_multiplier #(
		.APPROX_GROUP_B(M1_APPROX),
		.APPROX_GROUP_A(M1_APPROX),
		.APPROX_LOA(LOA_K)
	) u_m1 (
		.a(a[7:0]),
		.b(b[15:8]),
		.p(m1)
	);

	v2_8x8_multiplier #(
		.APPROX_GROUP_B(M2_APPROX),
		.APPROX_GROUP_A(M2_APPROX),
		.APPROX_LOA(LOA_K)
	) u_m2 (
		.a(a[15:8]),
		.b(b[7:0]),
		.p(m2)
	);

	v2_8x8_multiplier #(
		.APPROX_GROUP_B(M3_APPROX),
		.APPROX_GROUP_A(M3_APPROX),
		.APPROX_LOA(LOA_K)
	) u_m3 (
		.a(a[15:8]),
		.b(b[15:8]),
		.p(m3)
	);

	assign part_sum0 = m0[15:8] + m1[7:0];  
	assign part_sum1 = part_sum0 + m2[7:0];
	assign part_sum2 = m2[15:8] + m1[15:8];
	assign part_sum3 = part_sum2 + m3[7:0];

	assign p[31:24] = m3[15:8];
	assign p[23:16] = part_sum3;
	assign p[15:8]  = part_sum1;
	assign p[7:0]   = m0[7:0];
endmodule
