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

	integer idx;
	integer errors;
	integer seed;
	reg [1023:0] vcd_file;
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

	function [15:0] v2_mul8_model;
		input [7:0] x;
		input [7:0] y;
		input integer approx_group_a;
		input integer approx_group_b;
		reg [11:0] group_a_exact;
		reg [11:0] group_b_exact;
		begin
			group_a_exact = x * y[3:0];
			group_b_exact = x * y[7:4];
			case (approx_group_a)
				0: group_a_exact = group_a_exact & 12'hfff;
				2: group_a_exact = group_a_exact & 12'hffc;
				4: group_a_exact = group_a_exact & 12'hff0;
				5: group_a_exact = group_a_exact & 12'hfe0;
				6: group_a_exact = group_a_exact & 12'hfc0;
				default: group_a_exact = 12'b0;
			endcase
			case (approx_group_b)
				0: group_b_exact = group_b_exact & 12'hfff;
				2: group_b_exact = group_b_exact & 12'hffc;
				4: group_b_exact = group_b_exact & 12'hff0;
				5: group_b_exact = group_b_exact & 12'hfe0;
				6: group_b_exact = group_b_exact & 12'hfc0;
				default: group_b_exact = 12'b0;
			endcase
			v2_mul8_model = {group_b_exact, 4'b0000} + {4'b0000, group_a_exact};
		end
	endfunction

	function [31:0] loa_sum_model;
		input [31:0] x;
		input [31:0] y;
		reg [31:0] tmp;
		reg carry;
		reg [32-LOA_K:0] upper;
		integer i;
		begin
			tmp = 32'b0;
			for (i = 0; i < LOA_K; i = i + 1)
				tmp[i] = x[i] | y[i];
			carry = x[LOA_K-1] & y[LOA_K-1];
			upper = {1'b0, x[31:LOA_K]} + {1'b0, y[31:LOA_K]} + carry;
			tmp[31:LOA_K] = upper[31-LOA_K:0];
			loa_sum_model = tmp;
		end
	endfunction

	function [23:0] loa_sum24_model;
		input [23:0] x;
		input [23:0] y;
		reg [23:0] tmp;
		reg carry;
		reg [24-LOA_K:0] upper;
		integer i;
		begin
			tmp = 24'b0;
			for (i = 0; i < LOA_K; i = i + 1)
				tmp[i] = x[i] | y[i];
			carry = x[LOA_K-1] & y[LOA_K-1];
			upper = {1'b0, x[23:LOA_K]} + {1'b0, y[23:LOA_K]} + carry;
			tmp[23:LOA_K] = upper[23-LOA_K:0];
			loa_sum24_model = tmp;
		end
	endfunction

	function [31:0] approx_mul16_model;
		input [15:0] x;
		input [15:0] y;
		reg [15:0] m0;
		reg [15:0] m1;
		reg [15:0] m2;
		reg [15:0] m3;
		reg [23:0] u0;
		reg [23:0] u1;
		reg [23:0] u2;
		reg [23:0] u3;
		reg [23:0] s0;
		reg [23:0] s1;
		reg [23:0] s2;
		begin
			m0 = v2_mul8_model(x[7:0], y[7:0], M0_APPROX, M0_APPROX);
			m1 = v2_mul8_model(x[7:0], y[15:8], M1_APPROX, M1_APPROX);
			m2 = v2_mul8_model(x[15:8], y[7:0], M2_APPROX, M2_APPROX);
			m3 = v2_mul8_model(x[15:8], y[15:8], M3_APPROX, M3_APPROX);
			u0 = {16'b0, m0[15:8]};
			u1 = {8'b0, m1};
			u2 = {8'b0, m2};
			u3 = {m3, 8'b0};
			s0 = loa_sum24_model(u0, u1);
			s1 = loa_sum24_model(u2, u3);
			s2 = loa_sum24_model(s0, s1);
			approx_mul16_model = {s2, m0[7:0]};
		end
	endfunction

	task run_case;
		input [15:0] in_a;
		input [15:0] in_b;
		begin
			a = in_a;
			b = in_b;
			#1;
			expected = approx_mul16_model(in_a, in_b);
			exact_product = in_a * in_b;
			if (p !== expected) begin
				errors = errors + 1;
				$display("FAIL k=%0d a=0x%04x b=0x%04x dut=0x%08x exp=0x%08x exact=0x%08x",
					LOA_K, in_a, in_b, p, expected, exact_product);
			end else begin
				$display("PASS k=%0d a=0x%04x b=0x%04x approx=0x%08x exact=0x%08x",
					LOA_K, in_a, in_b, p, exact_product);
			end
		end
	endtask

	initial begin
		errors = 0;
		seed = 32'h1badc0de;

		if ($value$plusargs("vcd=%s", vcd_file)) begin
			$dumpfile(vcd_file);
			$dumpvars(0, approx_mul16_loa_tb);
		end

		run_case(16'h0000, 16'h0000);
		run_case(16'h0001, 16'h0001);
		run_case(16'h000f, 16'h0003);
		run_case(16'h00ff, 16'h0002);
		run_case(16'h00ff, 16'h00ff);
		run_case(16'h1234, 16'h5678);
		run_case(16'ha5a5, 16'h5a5a);
		run_case(16'hffff, 16'h0001);
		run_case(16'hffff, 16'hffff);
		run_case(16'h8000, 16'h0002);

		for (idx = 0; idx < 50; idx = idx + 1) begin
			run_case($random(seed), $random(seed));
		end

		if (errors != 0) begin
			$display("TEST FAILED with %0d mismatches", errors);
			$finish(1);
		end

		$display("TEST PASSED for LOA_K=%0d cfg=%0d_%0d_%0d_%0d", LOA_K, M0_APPROX, M1_APPROX, M2_APPROX, M3_APPROX);
		$finish;
	end
endmodule
