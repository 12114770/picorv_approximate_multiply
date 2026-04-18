module v2
(
    input a_i,
    input a_j,
    input b_i,
    input b_j,
    input c_in_i,
    input c_in_j,
    output s_out_j,
    output c_out_i,
    output c_out_j
);
    assign c_out_i = 0;
    assign c_out_j = (a_j & b_j) | (a_j & c_in_j) | (b_j & c_in_j);
    assign s_out_j = (a_j & c_in_j) | (a_j & b_j);    
endmodule