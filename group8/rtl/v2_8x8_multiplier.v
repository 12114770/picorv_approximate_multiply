`timescale 1 ns / 1 ps

module v2_8x8_multiplier #(
	parameter integer APPROX_GROUP_B = 2,
	parameter integer APPROX_GROUP_A = 2
) (
	input  [7:0] a,
	input  [7:0] b,
	output [15:0] p
);
	// Best-effort configurable approximate 8x8 block.
	//
	// Each 8x8 block is split into a lower-order 8x4 group (A) and a higher-order
	// 8x4 group (B). The approximation setting controls how many least-significant
	// local bits are suppressed in each group before recombination.
	//
	// E  -> APPROX_GROUP_A=0, APPROX_GROUP_B=0
	// 22 -> APPROX_GROUP_A=2, APPROX_GROUP_B=2
	// 44 -> APPROX_GROUP_A=4, APPROX_GROUP_B=4
	// 55 -> APPROX_GROUP_A=5, APPROX_GROUP_B=5
	// 66 -> APPROX_GROUP_A=6, APPROX_GROUP_B=6
	function [11:0] apply_group_approx;
		input [11:0] value;
		input integer approx_bits;
		reg [11:0] mask;
		begin
			case (approx_bits)
				0: mask = 12'hfff;
				1: mask = 12'hffe;
				2: mask = 12'hffc;
				3: mask = 12'hff8;
				4: mask = 12'hff0;
				5: mask = 12'hfe0;
				6: mask = 12'hfc0;
				7: mask = 12'hf80;
				8: mask = 12'hf00;
				9: mask = 12'he00;
				10: mask = 12'hc00;
				11: mask = 12'h800;
				default: mask = 12'h000;
			endcase
			apply_group_approx = value & mask;
		end
	endfunction
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
	assign group_a_approx = apply_group_approx(group_a_exact, APPROX_GROUP_A);
	assign group_b_approx = apply_group_approx(group_b_exact, APPROX_GROUP_B);
	assign p = {group_b_approx, 4'b0000} + {4'b0000, group_a_approx};
endmodule
