//Single PPU
module ppu1
(
    input a,
    input b,
    input s_in,
    input c_in,
    output s_out,
    output c_out
);
    assign s_out = (a & b) ^ (c_in) ^ (s_in);
    assign c_out = (a & b & s_in) | (a & b & c_in) | (s_in & c_in);
endmodule


//Two PPUs stacked vertically
module ppu2
(
    input a_i,
    input a_j,
    input b_i,
    input b_j,
    input s_in,
    input c_in_i,
    input c_in_j,
    output c_out_i,
    output c_out_j,
    output s_out
);
    wire s_int;

    ppu1 ppu_i(
        .a(a_i),
        .b(b_i),
        .s_in(s_in),
        .c_in(c_in_i),
        .s_out(s_int),
        .c_out(c_out_i)
    );

    ppu1 ppu_j(
        .a(a_j),
        .b(b_j),
        .s_in(s_int),
        .c_in(c_in_j),
        .s_out(s_out),
        .c_out_j(c_out_j)
    );
endmodule