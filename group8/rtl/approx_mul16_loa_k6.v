`timescale 1 ns / 1 ps

module approx_mul16_loa_k6 (
	input  [15:0] a,
	input  [15:0] b,
	output [31:0] p
);
	approx_mul16_loa #(
		.LOA_K(6)
	) dut (
		.a(a),
		.b(b),
		.p(p)
	);
endmodule
