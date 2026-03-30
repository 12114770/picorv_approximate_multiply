`timescale 1 ns / 1 ps

module v2_8x8_error_tb;
	reg  [7:0] a;
	reg  [7:0] b;
	wire [15:0] p;

	integer ai;
	integer bi;
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

	v2_8x8_multiplier dut (
		.a(a),
		.b(b),
		.p(p)
	);

	initial begin
		total_cases = 0;
		mismatch_cases = 0;
		max_abs_error = 0;
		max_error_a = 0;
		max_error_b = 0;
		nmed_acc = 0.0;
		mred_acc = 0.0;
		mred_count = 0;

		for (ai = 0; ai < 256; ai = ai + 1) begin
			for (bi = 0; bi < 256; bi = bi + 1) begin
				a = ai[7:0];
				b = bi[7:0];
				#1;

				exact_product = ai * bi;
				approx_product = p;
				abs_error = exact_product - approx_product;
				if (abs_error < 0)
					abs_error = -abs_error;

				total_cases = total_cases + 1;
				if (approx_product != exact_product)
					mismatch_cases = mismatch_cases + 1;

				if (abs_error > max_abs_error) begin
					max_abs_error = abs_error;
					max_error_a = ai;
					max_error_b = bi;
				end

				nmed_acc = nmed_acc + (abs_error / 65025.0);
				if (exact_product != 0) begin
					mred_acc = mred_acc + (abs_error * 1.0 / exact_product);
					mred_count = mred_count + 1;
				end
			end
		end

		nmed = nmed_acc / total_cases;
		mred = mred_acc / mred_count;

		$display("V2_8X8_ERROR total=%0d mismatches=%0d", total_cases, mismatch_cases);
		$display("V2_8X8_ERROR max_abs_error=%0d at a=0x%02x b=0x%02x", max_abs_error, max_error_a[7:0], max_error_b[7:0]);
		$display("V2_8X8_ERROR nmed=%0.10f mred=%0.10f", nmed, mred);
		$finish;
	end
endmodule
