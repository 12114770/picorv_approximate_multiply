`timescale 1 ns / 1 ps

module approx_mul16_error_tb;
	parameter integer LOA_K = 4;
	parameter integer SAMPLE_COUNT = 100000;

	reg  [15:0] a;
	reg  [15:0] b;
	wire [31:0] p;

	integer idx;
	integer seed;
	integer total_cases;
	integer mismatch_cases;
	integer max_abs_error;
	integer max_error_a;
	integer max_error_b;
	integer exact_product;
	integer approx_product;
	integer abs_error;
	real nmed_acc;
	real mred_acc;
	integer mred_count;
	real nmed;
	real mred;

	approx_mul16_loa #(
		.LOA_K(LOA_K)
	) dut (
		.a(a),
		.b(b),
		.p(p)
	);

	initial begin
		seed = 32'h13579bdf;
		total_cases = 0;
		mismatch_cases = 0;
		max_abs_error = 0;
		max_error_a = 0;
		max_error_b = 0;
		nmed_acc = 0.0;
		mred_acc = 0.0;
		mred_count = 0;

		for (idx = 0; idx < SAMPLE_COUNT; idx = idx + 1) begin
			a = $random(seed);
			b = $random(seed);
			#1;

			exact_product = a * b;
			approx_product = p;
			abs_error = exact_product - approx_product;
			if (abs_error < 0)
				abs_error = -abs_error;

			total_cases = total_cases + 1;
			if (approx_product != exact_product)
				mismatch_cases = mismatch_cases + 1;

			if (abs_error > max_abs_error) begin
				max_abs_error = abs_error;
				max_error_a = a;
				max_error_b = b;
			end

			nmed_acc = nmed_acc + (abs_error / 4294836225.0);
			if (exact_product != 0) begin
				mred_acc = mred_acc + (abs_error * 1.0 / exact_product);
				mred_count = mred_count + 1;
			end
		end

		nmed = nmed_acc / total_cases;
		mred = mred_acc / mred_count;

		$display("APPROX_MUL16_ERROR k=%0d samples=%0d mismatches=%0d", LOA_K, total_cases, mismatch_cases);
		$display("APPROX_MUL16_ERROR max_abs_error=%0d at a=0x%04x b=0x%04x", max_abs_error, max_error_a[15:0], max_error_b[15:0]);
		$display("APPROX_MUL16_ERROR nmed=%0.10f mred=%0.10f", nmed, mred);
		$finish;
	end
endmodule
