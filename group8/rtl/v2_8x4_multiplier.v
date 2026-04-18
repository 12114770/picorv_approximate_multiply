`timescale 1 ns / 1 ps

module v2_8x4_multiplier #(
	parameter integer APPROX = 2
) (
	input  [7:0] a,
	input  [4:0] b,
	output [15:0] p
);	
	initial begin
		if (APPROX <= 0 || APPROX >= 6) begin
			$display("ERROR: 8x4_multiplies requires 0 < APPROX < 6. APPROX=%0d", APPROX);
			$finish;
		end
	end
	genvar i;
    //First row of 7 v2 blocks
    wire c_i_row1[7:0];
    wire c_j_row1[7:0];
    wire s_row1[8:0];
	wire c_row1 = 1'b0;
	wire p_row1 = 1'b0;
	//bit 1 to 8
    generate
        for(i = 1; i < 8; i = i +1)begin : row1
            v2 v2_inst(
                .a_i(a[i]), 
                .a_j(a[i-1]), 
                .b_i(b[0]),
                .b_j(b[1]),
                .c_in_i(1'b0),
                .c_in_j(c_j_row1[i-1]),
				.s_out_j(s_row1[i-1]),
                .c_out_i(c_i_row1[i]),
                .c_out_j(c_j_row1[i])				
			);
        end
    endgenerate
	//bit 9
	ppu ppu_row1(
		.a(0),			//? Is that right?
		.b(b[1]),
		.s_in(0),
		.c_in(c_j_row1[7]),
		.p_out(p_row1),
		.s_out(s_row1[8]),
		.c_out(c_row1)
		);
	//Second row of v2 blocks
	//Output of this row will be the output of th multiplier.
	//APPROX determines how many v2 blocks will be placed here.
    wire c_i_row2[5:0];
    wire c_j_row2[5:0];
	wire s_row2[7:0];

	generate
		for (i = 0; i < APPROX; i = i +1)begin : row2
			v2 v2_inst(
				.a_i(s_row2[i + 2]),
				.a_j(),
				.b_i(),
				.b_j(),
				.c_in_i(),
				.c_in_j(),
				.s_out_j(),
				.c_out_i(),
				.c_out_j()
			);
		end
	endgenerate
endmodule
