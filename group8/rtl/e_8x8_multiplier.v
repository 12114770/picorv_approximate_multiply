module e_8x8_multiplier #(
    parameter integer APPROX_LOA = 0
) (
    input  [7:0] a,
    input  [7:0] b,
    output [15:0] p
);

    if (APPROX_LOA < 0 || APPROX_LOA >= 12) begin
        $display("ERROR: APPROX_LOA must be in range 0..11 for WIDTH=12, got %0d", APPROX_LOA);
        $finish;
    end

    wire [11:0] group_a_out;
    wire [11:0] group_b_out;
    wire [11:0] loa_input_a;
	wire [11:0] loa_input_b;

    e_8x4_multiplier group_a (
        .a(a),
        .b(b[3:0]),
        .s_out(group_a_out)
    );

    e_8x4_multiplier group_b (
        .a(a),
        .b(b[7:4]),
        .s_out(group_b_out)
    );

	assign loa_input_a[11:8] = 4'b0000;
	assign loa_input_a[7:0]  = group_a_out[11:4];
	assign loa_input_b[11:0] = group_b_out;

	loa_adder #(
		.WIDTH(12), 
		.K(APPROX_LOA)
	) adder (
		.a(loa_input_a),
		.b(loa_input_b),
		.sum(p[15:4]),
		.carry_out()
	);

	assign p[3:0] = group_a_out[3:0];

endmodule