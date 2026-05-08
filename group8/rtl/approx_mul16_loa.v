`timescale 1 ns / 1 ps

module approx_mul16_loa #(
	parameter integer LOA_K = 4,
	parameter integer M0_APPROX = 2, // M0 = highest-order
	parameter integer M1_APPROX = 2,
	parameter integer M2_APPROX = 2,
	parameter integer M3_APPROX = 2  // M3 = lowest-order
) (
	input  [15:0] a,
	input  [15:0] b,
	output [31:0] p
);

	wire [15:0] m0; // high * high
	wire [15:0] m1; // high * low
	wire [15:0] m2; // low  * high
	wire [15:0] m3; // low  * low

    generate
        if (M0_APPROX == 0) begin : gen_m0_exact
            e_8x8_multiplier #(
                .APPROX_LOA(LOA_K)
            ) u_m0 (.a(a[15:8]), .b(b[15:8]), .p(m0));
        end else begin : gen_m0_approx
            v2_8x8_multiplier #(
                .APPROX_GROUP_B(M0_APPROX),
                .APPROX_GROUP_A(M0_APPROX),
                .APPROX_LOA(LOA_K)
            ) u_m0 (.a(a[15:8]), .b(b[15:8]), .p(m0));
        end

        if (M1_APPROX == 0) begin : gen_m1_exact
            e_8x8_multiplier #(
                .APPROX_LOA(LOA_K)
            ) u_m1 (.a(a[15:8]), .b(b[7:0]), .p(m1));
        end else begin : gen_m1_approx
            v2_8x8_multiplier #(
                .APPROX_GROUP_B(M1_APPROX),
                .APPROX_GROUP_A(M1_APPROX),
                .APPROX_LOA(LOA_K)
            ) u_m1 (.a(a[15:8]), .b(b[7:0]), .p(m1));
        end

        if (M2_APPROX == 0) begin : gen_m2_exact
            e_8x8_multiplier #(
                .APPROX_LOA(LOA_K)
            ) u_m2 (.a(a[7:0]), .b(b[15:8]), .p(m2));
        end else begin : gen_m2_approx
            v2_8x8_multiplier #(
                .APPROX_GROUP_B(M2_APPROX),
                .APPROX_GROUP_A(M2_APPROX),
                .APPROX_LOA(LOA_K)
            ) u_m2 (.a(a[7:0]), .b(b[15:8]), .p(m2));
        end

        if (M3_APPROX == 0) begin : gen_m3_exact
            e_8x8_multiplier  #(
                .APPROX_LOA(LOA_K)
            ) u_m3 (.a(a[7:0]), .b(b[7:0]), .p(m3));
        end else begin : gen_m3_approx
            v2_8x8_multiplier #(
                .APPROX_GROUP_B(M3_APPROX),
                .APPROX_GROUP_A(M3_APPROX),
                .APPROX_LOA(LOA_K)
            ) u_m3 (.a(a[7:0]), .b(b[7:0]), .p(m3));
        end
    endgenerate

    // Byte-wise recombination without any carry propagation:
    // P = {m0[15:8], m1[15:8] + m2[15:8] + m0[7:0],
    //      m3[15:8] + m2[7:0] + m1[7:0], m3[7:0]}

    assign p[31:24] = m0[15:8];
    assign p[23:16] = m1[15:8] + m2[15:8] + m0[7:0];
    assign p[15:8]  = m3[15:8] + m2[7:0] + m1[7:0];
    assign p[7:0]   = m3[7:0];

endmodule