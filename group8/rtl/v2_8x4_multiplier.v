`timescale 1 ns / 1 ps

module v2_8x4_multiplier #(
	parameter integer APPROX = 2
) (
	input  [7:0] a,
	input  [3:0] b,
	output [11:0] s
);	
	initial begin
		if (APPROX <= 0 || APPROX >= 6) begin
			$display("ERROR: 8x4_multiplies requires 0 < APPROX < 6. APPROX=%0d", APPROX);
			$finish;
		end
	end
	genvar i;

	//Carry chains
	//c_0 wire can be ignored since it is approximated away.
	wire [8:0] c_1;
	wire [8:0] c_2;
	wire [8:0] c_3;
	assign c_1[0] = 1'b0;
	assign c_2[0] = 1'b0;
	assign c_3[0] = 1'b0;
	//Sum chains
	//Sum of row 0 is a dummy row.
	wire [7:0] s_0;
	wire [7:0] s_1;
	//Sum of row 2 is also not used entirely
	wire [7:0] s_2;
	wire [7:0] s_3;

	//Row 0
    assign s_0[0] = a[0] & b[0];
	//Row 1
	generate 
		for (i = 0; i < 7; i++) begin : v2_arr_1
			v2 v2_block(
				.a_i(a[i +1]),
				.a_j(a[i]),
				.b_i(b[0]),
				.b_j(b[1]),
				.c_in_i(1'b0),
				.c_in_j(c_1[i]),
				.s_out_j(s_1[i]),
				.c_out_i(),
				.c_out_j(c_1[i+1])
			);
		end
	endgenerate

	ppu1 ppu_row_1_out(
		.a(a[7]),
		.b(b[1]),
		.s_in(1'b0),
		.c_in(c_1[7]),
		.s_out(s_1[7]),
		.c_out(c_1[8])
	);

	ppu1 ppu_row_2_in(
		.a(a[0]),
		.b(b[2]),
		.s_in(s_1[1]),
		.c_in(c_2[0]),
		.s_out(s_2[0]),
		.c_out(c_2[1])
	);

	//Generate number of APPROX blocks
	generate 
		for(i = 0; i < APPROX; i = i + 1) begin : v2_arr_2
			v2 v2_block(
				.a_i(a[i+1]),
				.a_j(a[i]),
				.b_i(b[2]),
				.b_j(b[3]),
				.c_in_i(c_2[i+1]),
				.c_in_j(c_3[i]),
				.s_out_j(s_3[i]),
				.c_out_i(c_2[i+2]),
				.c_out_j(c_3[i+1])
			);
		end
	endgenerate
	//Generate missing blocks of dual ppu blocks.
	generate 
		for(i = APPROX; i < 6; i = i + 1)begin : ppu2_arr
			ppu2 ppu2_block(
				.a_i(a[i+1]),
				.a_j(a[i]),
				.b_i(b[2]),
				.b_j(b[3]),
				.s_in(s_1[i]),
				.c_in_i(c_2[i+1]),
				.c_in_j(c_3[i]),
				.s_out(s_3[i]),
				.c_out_i(c_2[i+2]),
				.c_out_j(c_3[i+1])
			);
		end
	endgenerate

	ppu2 ppu_row2_out(
		.a_i(a[7]),
		.a_j(a[6]),
		.b_i(b[2]),
		.b_j(b[3]),
		.s_in(c_1[8]),
		.c_in_i(c_2[7]),
		.c_in_j(c_3[6]),
		.s_out(s_3[6]),
		.c_out_i(c_2[8]),
		.c_out_j(c_3[7])
	);

	ppu1 ppu_row_3_out(
		.a(a[7]),
		.b(b[3]),
		.s_in(c_2[8]),
		.c_in(c_3[7]),
		.s_out(s_3[7]),
		.c_out(c_3[8])
	);

	assign s[0] = s_0[0];
	assign s[1] = s_1[0];
	assign s[2] = s_2[0];
	assign s[10:3] = s_3;
	assign s[11] = c_3[8];
endmodule
