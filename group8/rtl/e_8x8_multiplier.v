/*
module e_8x8_multiplier (
    input  [7:0] a,
    input  [7:0] b,
    output [15:0] p
);
    assign p = a * b;
endmodule
*/

module e_8x8_multiplier (
    input  [7:0] a,
    input  [7:0] b,
    output [15:0] p
);

    wire [11:0] group_a_out;
    wire [11:0] group_b_out;

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

    wire [12:0] exact_sum;
    assign exact_sum = {1'b0, group_a_out[11:4]} + {1'b0, group_b_out};

    assign p[3:0]  = group_a_out[3:0];
    assign p[15:4] = exact_sum[11:0];

endmodule