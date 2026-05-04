`timescale 1 ns / 1 ps

module approx_mul16_loa_tb;
	parameter integer LOA_K = 4;
	parameter integer M0_APPROX = 2;
	parameter integer M1_APPROX = 2;
	parameter integer M2_APPROX = 2;
	parameter integer M3_APPROX = 2;

	reg  [15:0] a;
	reg  [15:0] b;
	wire [31:0] p;

	integer errors;
	integer total_cases;
	integer ref_fd;
	integer scan_count;
	reg [1023:0] vcd_file;
	reg [1023:0] ref_file;
	reg [15:0] in_a;
	reg [15:0] in_b;
	reg [31:0] expected;
	reg [31:0] exact_product;

	approx_mul16_loa #(
		.LOA_K(LOA_K),
		.M0_APPROX(M0_APPROX),
		.M1_APPROX(M1_APPROX),
		.M2_APPROX(M2_APPROX),
		.M3_APPROX(M3_APPROX)
	) dut (
		.a(a),
		.b(b),
		.p(p)
	);

	task run_case;
		input [15:0] case_a;
		input [15:0] case_b;
		input [31:0] case_expected;
		input [31:0] case_exact;
		begin
			a = case_a;
			b = case_b;
			#1;
			total_cases = total_cases + 1;
			if (p !== case_expected) begin
				errors = errors + 1;
				$display("FAIL k=%0d a=0x%04x b=0x%04x dut=0x%08x exp=0x%08x exact=0x%08x",
					LOA_K, case_a, case_b, p, case_expected, case_exact);
			end else begin
				$display("PASS k=%0d a=0x%04x b=0x%04x approx=0x%08x exact=0x%08x",
					LOA_K, case_a, case_b, p, case_exact);
			end
		end
	endtask

	initial begin
		errors = 0;
		total_cases = 0;

		if ($value$plusargs("vcd=%s", vcd_file)) begin
			$dumpfile(vcd_file);
			$dumpvars(0, approx_mul16_loa_tb);
		end

		if (!$value$plusargs("ref=%s", ref_file)) begin
			$display("ERROR: approx_mul16_loa_tb requires +ref=<python-generated-vector-file>");
			$finish(1);
		end

		ref_fd = $fopen(ref_file, "r");
		if (ref_fd == 0) begin
			$display("ERROR: failed to open reference vector file: %0s", ref_file);
			$finish(1);
		end

		while (!$feof(ref_fd)) begin
			scan_count = $fscanf(ref_fd, "%h %h %h %h\n", in_a, in_b, expected, exact_product);
			if (scan_count == 4)
				run_case(in_a, in_b, expected, exact_product);
			else if (scan_count != -1) begin
				$display("ERROR: malformed reference vector in %0s", ref_file);
				$fclose(ref_fd);
				$finish(1);
			end
		end

		$fclose(ref_fd);

		if (total_cases == 0) begin
			$display("ERROR: no reference vectors read from %0s", ref_file);
			$finish(1);
		end

		if (errors != 0) begin
			$display("TEST FAILED with %0d mismatches across %0d vectors", errors, total_cases);
			$finish(1);
		end

		$display("TEST PASSED for LOA_K=%0d cfg=%0d_%0d_%0d_%0d vectors=%0d",
			LOA_K, M0_APPROX, M1_APPROX, M2_APPROX, M3_APPROX, total_cases);
		$finish;
	end
endmodule
