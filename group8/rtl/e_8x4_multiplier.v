`timescale 1 ns / 1 ps

//Exact 8x4 multiplier
module e_8x4_multiplier 
(
	input  [7:0] a,
	input  [3:0] b,
	output [11:0] s_out
);	
	genvar r,i;

	//Carry chains
	//There is only carry chains for row 1-3
    wire [8:0] c[0:3];
    assign c[0] = 9'b000000000;
	assign c[1][0] = 1'b0;
	assign c[2][0] = 1'b0;
	assign c[3][0] = 1'b0;
	//Sum chains
	wire [7:0] s[0:3];

	//Row 0
    generate
        for (i = 0; i < 8; i = i + 1) begin : row_0
            assign s[0][i] = a[i] & b[0]; 
        end
    endgenerate
	//Row 1
	generate 
        for(r = 1; r < 4; r = r + 1) begin : row
            for (i = 0; i < 7; i = i + 1) begin : block
                ppu1 ppu(
                    .a(a[i]),
                    .b(b[r]),
                    .s_in(s[r-1][i+1]),
                    .c_in(c[r][i]),
                    .s_out(s[r][i]),
                    .c_out(c[r][i+1])
                );
            end
            ppu1 block_7_ppu(
                .a(a[7]),
                .b(b[r]),
                .s_in(c[r-1][8]),
                .c_in(c[r][7]),
                .s_out(s[r][7]),
                .c_out(c[r][8])
            );
        end
	endgenerate

	assign s_out[0] = s[0][0];
	assign s_out[1] = s[1][0];
	assign s_out[2] = s[2][0];
	assign s_out[10:3] = s[3];
	assign s_out[11] = c[3][8];
endmodule
