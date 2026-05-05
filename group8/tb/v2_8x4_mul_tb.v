`timescale 1ns/1ps

module v2_8x4_multiplier_tb;

    parameter integer APPROX = 6;

    reg  [7:0]  a;
    reg  [3:0]  b;
    wire [11:0] p;

    integer i, j;
    integer errors;
    integer abs_err;
    integer total_abs_err;
    integer max_abs_err;
    integer exact;

    v2_8x4_multiplier #(
        .APPROX(APPROX)
    ) dut (
        .a(a),
        .b(b),
        .s_out(p)
    );

    initial begin
        errors = 0;
        total_abs_err = 0;
        max_abs_err = 0;

        for (i = 0; i < 256; i = i + 1) begin
            for (j = 0; j < 16; j = j + 1) begin
                a = i[7:0];
                b = j[3:0];
                #1;

                if (^p === 1'bx) begin
                    $display("ERROR X/Z: a=%0d b=%0d p=%b", i, j, p);
                    errors = errors + 1;
                end

                exact = i * j;
                abs_err = (p > exact) ? (p - exact) : (exact - p);
                total_abs_err = total_abs_err + abs_err;

                if (abs_err > max_abs_err)
                    max_abs_err = abs_err;
            end
        end

        $display("v2_8x4 APPROX=%0d total_abs_err=%0d max_abs_err=%0d x_errors=%0d",
                 APPROX, total_abs_err, max_abs_err, errors);

        $finish;
    end

endmodule