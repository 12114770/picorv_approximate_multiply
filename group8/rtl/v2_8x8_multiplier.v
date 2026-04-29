`timescale 1 ns / 1 ps

module v2_8x8_multiplier #(
	parameter integer APPROX_GROUP_B = 2,
	parameter integer APPROX_GROUP_A = 2,
	parameter integer APPROX_LOA	 = 4
) (
	input  [7:0] a,
	input  [7:0] b,
	output [15:0] p
);
	initial begin
		if (APPROX_GROUP_A <= 0 || APPROX_GROUP_A >= 6) begin
			$display("ERROR: 8x8_multiplies requires 0 < APPROX_GROUP_A < 6. APPROX_GROUP_A=%0d", APPROX_GROUP_A);
			$finish;
		end
		if (APPROX_GROUP_B <= 0 || APPROX_GROUP_B >= 6) begin
			$display("ERROR: 8x8_multiplies requires 0 < APPROX_GROUP_B < 6. APPROX_GROUP_B=%0d", APPROX_GROUP_B);
			$finish;
		end
		if (APPROX_LOA <= 0 ) begin
			$display("ERROR: 8x8_multiplies requires 0 < APPROX_LOA. APPROX_LOA=%0d", APPROX_LOA);
			$finish;
		end
	end

    wire [11:0] group_a_out;
    wire [11:0] group_b_out;
	wire [11:0] loa_input_a;
	wire [11:0] loa_input_b; 

    v2_8x4_multiplier #(.APPROX(APPROX_GROUP_A))
	group_a(
		.a(a),
		.b(b[3:0]),
		.s(group_a_out)
	);

	v2_8x4_multiplier #(.APPROX(APPROX_GROUP_B))
	group_b(
		.a(a),
		.b(b[7:4]),
		.s(group_b_out)
	);

	assign loa_input_a[11:8] = 4'b0000;
	assign loa_input_a[7:0]  = group_a_out[11:4];
	assign loa_input_b[11:0] = group_b_out;

	loa_adder #(.WIDTH(12), .K(APPROX_LOA))
	adder(
		.a(loa_input_a),
		.b(loa_input_b),
		.sum(p[15:4]),
		.carry_out()
	);

	assign p[3:0] = group_a_out[3:0];
endmodule