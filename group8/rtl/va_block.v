module va
(
    input  a_i,
    input  a_j,
    input  b_i,
    input  b_j,
    output s_out_j,
    output c_out_j
);

    assign c_out_j = 1'b0;
    assign s_out_j = (a_i & b_i) ^ (a_j & b_j);

endmodule