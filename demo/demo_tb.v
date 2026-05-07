/*
    Description:
    Demo testbench of the 16x16 approximate multiplier.
    Uses random generated input values depending if N_INPUT which gives the number
    of inputs and USE_RAND macro is defined or not.
    If USE_RAND is not defined values from 0 to N_INPUT-1 are used as operands.
    If USE_RAND is defined N_INPUT of random values are read from hex file.
    If N_INPUT is not defined the default value will be 100.
*/

`ifndef N_INPUT
    `define N_INPUT 100
`endif

module mod_16x16_mul_tb#(
    parameter NUM_INPUTS=`N_INPUT
)();
    // Number of inputs
    localparam integer N = NUM_INPUTS;

    // DUT Inputs and output
    reg [15:0] a_in;
    reg [15:0] b_in;
    wire [31:0] s_out;

    // Instantiate DUT
    mod_16x16_mul dut(
        .a_in(a_in),
        .b_in(b_in),
        .s_out(s_out)
    );

    //approx_mul16_loa  #(
    //    .LOA_K(4),
    //    .M0_APPROX(2),
    //    .M1_APPROX(2),
    //    .M2_APPROX(2),
    //    .M3_APPROX(2)
    //)dut(
    //    .a(a_in),
    //    .b(b_in),
    //    .p(s_out)
    //)

    // Loop indexes
    integer i,j;

    // Stimulus
    reg [15:0] a [0:N-1];
    reg [15:0] b [0:N-1];

    initial begin
        `ifdef USE_RAND
            // Read random generated inputs
            $readmemh("build/sim/sim_input_a.hex", a);
            $readmemh("build/sim/sim_input_b.hex", b);
        `else
            // If no input is given just use all numbers from 0 to N-1
            for(i = 0; i < N; i = i + 1) begin
               a[i] = i;
               b[i] = i;
            end
        `endif

        // Calculate approximated product for all input combinations
        for(i = 0; i < N; i = i + 1) begin
            a_in = a[i];
            for(j = 0; j < N; j = j  + 1) begin
                b_in = b[j];
                #1
                /*
                Display inputs and result - this will be written to a text file
                via the make file to calculate error metrics with python script.
                */
                $display("%0d %0d %0d", a_in, b_in, s_out);
            end
        end
    end
endmodule