module ppu
(
    input a,
    input b,
    input s_in,
    input c_in,
    output p_out,
    output s_out,
    output c_out
);
    assign p_out = (a & b);
    assign s_out = (a & b) ^ (c_in) ^ (s_in);
    assign c_out = (a & b & s_in) | (a & b & c_in) | (s_in & c_in);
endmodule