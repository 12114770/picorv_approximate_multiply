`timescale 1ns/1ps

module approx_mul16_loa_tb;

    parameter integer LOA_K = 4;
	parameter integer M0_APPROX = 2;
	parameter integer M1_APPROX = 2;
	parameter integer M2_APPROX = 2;
	parameter integer M3_APPROX = 2;
    parameter integer TESTS = 1000;

    reg  [15:0] a;
    reg  [15:0] b;
    wire [31:0] p;

    integer i;
    integer errors;
    integer x_errors;

    reg [31:0] exact;
    reg [31:0] abs_err;
    reg [31:0] max_abs_err;
    reg [63:0] total_abs_err;

    real nmed;
    real mred;
    real total_rel_err;
    integer rel_count;
    integer total_tests;
    real max_exact_real;

    approx_mul16_loa #(
        .LOA_K(LOA_K),
        .M0_APPROX(M0_APPROX),
        .M1_APPROX(M1_APPROX),
        .M2_APPROX(M2_APPROX),
        .M3_APPROX(M3_APPROX)
    ) dut (
        .a(a),
        .b(b),
        .p(p)
    );

    task check_case;
        input [15:0] ta;
        input [15:0] tb;
        begin
            a = ta;
            b = tb;
            #1;

            exact = ta * tb;

            if (^p === 1'bx) begin
                $display("X/Z ERROR: a=0x%04h b=0x%04h p=%b", ta, tb, p);
                x_errors = x_errors + 1;
            end

            if (p > exact)
                abs_err = p - exact;
            else
                abs_err = exact - p;

            total_abs_err = total_abs_err + abs_err;

            if (exact != 0) begin
                total_rel_err = total_rel_err + (abs_err * 1.0) / (exact * 1.0);
                rel_count = rel_count + 1;
            end

            if (abs_err > max_abs_err)
                max_abs_err = abs_err;

            if ((M0_APPROX == 0) &&
                (M1_APPROX == 0) &&
                (M2_APPROX == 0) &&
                (M3_APPROX == 0)) begin

                if (p !== exact) begin
                    $display("FAIL exact: a=0x%04h b=0x%04h got=0x%08h expected=0x%08h",
                             ta, tb, p, exact);
                    errors = errors + 1;
                end
            end
        end
    endtask

    initial begin
        errors        = 0;
        x_errors      = 0;
        total_abs_err = 0;
        max_abs_err   = 0;

        total_rel_err = 0.0;
        rel_count = 0;
        total_tests = TESTS + 11;
        max_exact_real = 32'hfffe0001 * 1.0; // 65535 * 65535

        // Directed edge cases
        check_case(16'h0000, 16'h0000);
        check_case(16'h0001, 16'h0001);
        check_case(16'h000f, 16'h0003);
        check_case(16'h00ff, 16'h0002);
        check_case(16'h00ff, 16'h00ff);
        check_case(16'h0100, 16'h0100);
        check_case(16'hffff, 16'h0001);
        check_case(16'hffff, 16'hffff);
        check_case(16'h8000, 16'h8000);
        check_case(16'h1234, 16'h5678);
        check_case(16'ha5a5, 16'h5a5a);

        // Random tests
        for (i = 0; i < TESTS; i = i + 1) begin
            check_case($urandom, $urandom);
        end

        $display("approx_mul16 LOA_K=%0d M=%0d_%0d_%0d_%0d tests=%0d",
                 LOA_K,
                 M0_APPROX,
                 M1_APPROX,
                 M2_APPROX,
                 M3_APPROX,
                 TESTS + 11);

        $display("total_abs_err=%0d max_abs_err=%0d x_errors=%0d exact_errors=%0d",
                 total_abs_err, max_abs_err, x_errors, errors);

        if (x_errors != 0) begin
            $display("FAIL: X/Z errors detected");
            $finish(1);
        end

        if ((M0_APPROX == 0) &&
            (M1_APPROX == 0) &&
            (M2_APPROX == 0) &&
            (M3_APPROX == 0) &&
            (errors != 0)) begin
            $display("FAIL: exact 16x16 mode is incorrect");
            $finish(1);
        end

        // after all tests:
        nmed = (total_abs_err * 1.0) / (total_tests * max_exact_real);
        mred = total_rel_err / rel_count;

        $display("NMED=%0.10f", nmed);
        $display("MRED=%0.10f", mred);

        $display("PASS");
        $finish;
    end

endmodule