`timescale 1 ns / 1 ps

module v2_8x8_multiplier #(
	parameter [8*22-1:0] V2_IMPLEMENTATION = "BEST_EFFORT_22"
) (
	input  [7:0] a,
	input  [7:0] b,
	output [15:0] p
);
	// Best-effort Group-8 construction for the 22 block:
	// - split the 8x8 multiplication into two 8x4 groups using b[3:0] and b[7:4]
	// - approximate each group by clearing its two least-significant local bits
	// - accumulate the two groups in the standard shifted form
	//
	// This matches the available information that the 22 architecture uses two
	// approximated positions in each of the lower-order and higher-order groups.
	// Replace this model with the exact course-provided 22/V2 cell placement if a
	// precise block diagram becomes available.
	wire [11:0] group_a_exact;
	wire [11:0] group_b_exact;
	wire [11:0] group_a_approx;
	wire [11:0] group_b_approx;
	wire [11:0] group_a_row0;
	wire [11:0] group_a_row1;
	wire [11:0] group_a_row2;
	wire [11:0] group_a_row3;
	wire [11:0] group_b_row0;
	wire [11:0] group_b_row1;
	wire [11:0] group_b_row2;
	wire [11:0] group_b_row3;

	assign group_a_row0 = b[0] ? {4'b0000, a}       : 12'b0;
	assign group_a_row1 = b[1] ? {3'b000, a, 1'b0} : 12'b0;
	assign group_a_row2 = b[2] ? {2'b00, a, 2'b00} : 12'b0;
	assign group_a_row3 = b[3] ? {1'b0, a, 3'b000} : 12'b0;
	assign group_b_row0 = b[4] ? {4'b0000, a}       : 12'b0;
	assign group_b_row1 = b[5] ? {3'b000, a, 1'b0} : 12'b0;
	assign group_b_row2 = b[6] ? {2'b00, a, 2'b00} : 12'b0;
	assign group_b_row3 = b[7] ? {1'b0, a, 3'b000} : 12'b0;

	assign group_a_exact = group_a_row0 + group_a_row1 + group_a_row2 + group_a_row3;
	assign group_b_exact = group_b_row0 + group_b_row1 + group_b_row2 + group_b_row3;
	assign group_a_approx = {group_a_exact[11:2], 2'b00};
	assign group_b_approx = {group_b_exact[11:2], 2'b00};
	assign p = {group_b_approx, 4'b0000} + {4'b0000, group_a_approx};
endmodule
