`timescale 1 ns / 1 ps

module loa_adder #(
	parameter integer WIDTH = 32,
	parameter integer K = 4
) (
	input  [WIDTH-1:0] a,
	input  [WIDTH-1:0] b,
	output [WIDTH-1:0] sum,
	output             carry_out
);
	initial begin
		if (K <= 0 || K >= WIDTH) begin
			$display("ERROR: loa_adder requires 0 < K < WIDTH. WIDTH=%0d K=%0d", WIDTH, K);
			$finish;
		end
	end

	wire [K-1:0] lower_sum;
	wire         lower_carry;
	wire [WIDTH-K:0] upper_sum_ext;

	assign lower_sum = a[K-1:0] | b[K-1:0];
	assign lower_carry = a[K-1] & b[K-1];
	assign upper_sum_ext = {1'b0, a[WIDTH-1:K]} + {1'b0, b[WIDTH-1:K]} + lower_carry;

	assign sum[K-1:0] = lower_sum;
	assign sum[WIDTH-1:K] = upper_sum_ext[WIDTH-K-1:0];
	assign carry_out = upper_sum_ext[WIDTH-K];
endmodule
