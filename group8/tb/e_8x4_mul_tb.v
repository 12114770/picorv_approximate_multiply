`timescale 1ns/1ps

module e_8x4_multiplier_tb;

    reg  [7:0]  a;
    reg  [3:0]  b;
    wire [11:0] p;

    integer i, j;
    integer errors;

    e_8x4_multiplier dut (
        .a(a),
        .b(b),
        .s_out(p)
    );

    initial begin
        errors = 0;

        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                a = i[7:0];
                b = j[3:0];
                #1;

                if (p !== (i * j)) begin
                    $display("ERROR e_8x4: a=%0d b=%0d got=%0d expected=%0d",
                             i, j, p, i*j);
                    errors = errors + 1;
                end
            end
        end

        if (errors == 0)
            $display("PASS: e_8x4_multiplier exhaustive test");
        else
            $display("FAIL: e_8x4_multiplier errors=%0d", errors);

        $finish;
    end

endmodule