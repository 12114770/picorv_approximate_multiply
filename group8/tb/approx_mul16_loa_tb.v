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

	function [1:0] ppu1_model;
		input bit_a;
		input bit_b;
		input s_in;
		input c_in;
		reg pp;
		begin
			pp = bit_a & bit_b;
			ppu1_model[0] = pp ^ c_in ^ s_in;
			ppu1_model[1] = (pp & s_in) | (pp & c_in) | (s_in & c_in);
		end
	endfunction

	function [2:0] ppu2_model;
		input a_i;
		input a_j;
		input b_i;
		input b_j;
		input s_in;
		input c_in_i;
		input c_in_j;
		reg [1:0] upper;
		reg [1:0] lower;
		begin
			upper = ppu1_model(a_i, b_i, s_in, c_in_i);
			lower = ppu1_model(a_j, b_j, upper[0], c_in_j);
			ppu2_model = {lower[1], upper[1], lower[0]};
		end
	endfunction

	function [2:0] v2_cell_model;
		input a_i;
		input a_j;
		input b_i;
		input b_j;
		input c_in_i;
		input c_in_j;
		begin
			v2_cell_model[0] = (a_j & c_in_j) | (a_j & b_j);
			v2_cell_model[1] = (a_j & b_j) | (a_j & c_in_j) | (b_j & c_in_j);
			v2_cell_model[2] = 1'b0;
		end
	endfunction

	function [11:0] e_8x4_model;
		input [7:0] x;
		input [3:0] y;
		reg [8:0] c [0:3];
		reg [7:0] s [0:3];
		reg [1:0] ppu_out;
		integer r;
		integer i;
		begin
			c[0] = 9'b0;
			c[1] = 9'b0;
			c[2] = 9'b0;
			c[3] = 9'b0;
			s[0] = 8'b0;
			s[1] = 8'b0;
			s[2] = 8'b0;
			s[3] = 8'b0;

			for (i = 0; i < 8; i = i + 1)
				s[0][i] = x[i] & y[0];

			for (r = 1; r < 4; r = r + 1) begin
				for (i = 0; i < 7; i = i + 1) begin
					ppu_out = ppu1_model(x[i], y[1], s[r-1][i+1], c[r][i]);
					s[r][i] = ppu_out[0];
					c[r][i+1] = ppu_out[1];
				end
				ppu_out = ppu1_model(x[7], y[1], c[r-1][8], c[r][7]);
				s[r][7] = ppu_out[0];
				c[r][8] = ppu_out[1];
			end

			e_8x4_model = {c[3][8], s[3], s[2][0], s[1][0], s[0][0]};
		end
	endfunction

	function [11:0] v2_8x4_model;
		input [7:0] x;
		input [3:0] y;
		input integer approx;
		reg [8:0] c_1;
		reg [8:0] c_2;
		reg [8:0] c_3;
		reg [7:0] s_0;
		reg [7:0] s_1;
		reg [7:0] s_2;
		reg [7:0] s_3;
		reg [1:0] ppu1_out;
		reg [2:0] ppu2_out;
		reg [2:0] v2_out;
		integer i;
		begin
			c_1 = 9'b0;
			c_2 = 9'b0;
			c_3 = 9'b0;
			s_0 = 8'b0;
			s_1 = 8'b0;
			s_2 = 8'b0;
			s_3 = 8'b0;

			s_0[0] = x[0] & y[0];

			for (i = 0; i < 7; i = i + 1) begin
				v2_out = v2_cell_model(x[i+1], x[i], y[0], y[1], 1'b0, c_1[i]);
				s_1[i] = v2_out[0];
				c_1[i+1] = v2_out[1];
			end

			ppu1_out = ppu1_model(x[7], y[1], 1'b0, c_1[7]);
			s_1[7] = ppu1_out[0];
			c_1[8] = ppu1_out[1];

			ppu1_out = ppu1_model(x[0], y[2], s_1[1], c_2[0]);
			s_2[0] = ppu1_out[0];
			c_2[1] = ppu1_out[1];

			for (i = 0; i < approx; i = i + 1) begin
				v2_out = v2_cell_model(x[i+1], x[i], y[2], y[3], c_2[i+1], c_3[i]);
				s_3[i] = v2_out[0];
				c_2[i+2] = v2_out[2];
				c_3[i+1] = v2_out[1];
			end

			for (i = approx; i < 6; i = i + 1) begin
				ppu2_out = ppu2_model(x[i+1], x[i], y[2], y[3], s_1[i], c_2[i+1], c_3[i]);
				s_3[i] = ppu2_out[0];
				c_2[i+2] = ppu2_out[1];
				c_3[i+1] = ppu2_out[2];
			end

			ppu2_out = ppu2_model(x[7], x[6], y[2], y[3], c_1[8], c_2[7], c_3[6]);
			s_3[6] = ppu2_out[0];
			c_2[8] = ppu2_out[1];
			c_3[7] = ppu2_out[2];

			ppu1_out = ppu1_model(x[7], y[3], c_2[8], c_3[7]);
			s_3[7] = ppu1_out[0];
			c_3[8] = ppu1_out[1];

			v2_8x4_model = {c_3[8], s_3, s_2[0], s_1[0], s_0[0]};
		end
	endfunction

	function [11:0] mul8x4_model;
		input [7:0] x;
		input [3:0] y;
		input integer approx;
		begin
			if (approx == 0)
				mul8x4_model = e_8x4_model(x, y);
			else
				mul8x4_model = v2_8x4_model(x, y, approx);
		end
	endfunction

	function [11:0] loa_sum12_model;
		input [11:0] x;
		input [11:0] y;
		reg [11:0] tmp;
		reg carry;
		reg [12-LOA_K:0] upper;
		integer i;
		begin
			tmp = 12'b0;
			for (i = 0; i < LOA_K; i = i + 1)
				tmp[i] = x[i] | y[i];
			carry = x[LOA_K-1] & y[LOA_K-1];
			upper = {1'b0, x[11:LOA_K]} + {1'b0, y[11:LOA_K]} + carry;
			tmp[11:LOA_K] = upper[11-LOA_K:0];
			loa_sum12_model = tmp;
		end
	endfunction

	function [15:0] v2_mul8_model;
		input [7:0] x;
		input [7:0] y;
		input integer approx_group_a;
		input integer approx_group_b;
		reg [11:0] group_a_out;
		reg [11:0] group_b_out;
		reg [11:0] loa_input_a;
		reg [11:0] loa_input_b;
		reg [11:0] loa_sum;
		begin
			group_a_out = mul8x4_model(x, y[3:0], approx_group_a);
			group_b_out = mul8x4_model(x, y[7:4], approx_group_b);
			loa_input_a = {4'b0000, group_a_out[11:4]};
			loa_input_b = group_b_out;
			loa_sum = loa_sum12_model(loa_input_a, loa_input_b);
			v2_mul8_model = {loa_sum, group_a_out[3:0]};
		end
	endfunction

	function [31:0] approx_mul16_model;
		input [15:0] x;
		input [15:0] y;
		reg [15:0] m0;
		reg [15:0] m1;
		reg [15:0] m2;
		reg [15:0] m3;
		reg [7:0] part_sum0;
		reg [7:0] part_sum1;
		reg [7:0] part_sum2;
		reg [7:0] part_sum3;
		begin
			m0 = v2_mul8_model(x[7:0], y[7:0], M0_APPROX, M0_APPROX);
			m1 = v2_mul8_model(x[7:0], y[15:8], M1_APPROX, M1_APPROX);
			m2 = v2_mul8_model(x[15:8], y[7:0], M2_APPROX, M2_APPROX);
			m3 = v2_mul8_model(x[15:8], y[15:8], M3_APPROX, M3_APPROX);
			part_sum0 = m0[15:8] + m1[7:0];
			part_sum1 = part_sum0 + m2[7:0];
			part_sum2 = m2[15:8] + m1[15:8];
			part_sum3 = part_sum2 + m3[7:0];
			approx_mul16_model = {m3[15:8], part_sum3, part_sum1, m0[7:0]};
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
