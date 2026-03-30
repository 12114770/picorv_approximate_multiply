`timescale 1 ns / 1 ps

module picorv32_pcpi_mul16_seq #(
	parameter integer LOA_K = 4,
	parameter integer M0_APPROX = 2,
	parameter integer M1_APPROX = 2,
	parameter integer M2_APPROX = 2,
	parameter integer M3_APPROX = 2,
	parameter [6:0] CUSTOM_OPCODE = 7'b0001011,
	parameter [2:0] CUSTOM_FUNCT3 = 3'b000,
	parameter [6:0] CUSTOM_FUNCT7 = 7'b0101010
) (
	input             clk,
	input             resetn,
	input             pcpi_valid,
	input      [31:0] pcpi_insn,
	input      [31:0] pcpi_rs1,
	input      [31:0] pcpi_rs2,
	output reg        pcpi_wr,
	output reg [31:0] pcpi_rd,
	output            pcpi_wait,
	output reg        pcpi_ready
);
	localparam [3:0] ST_IDLE   = 4'd0;
	localparam [3:0] ST_M0     = 4'd1;
	localparam [3:0] ST_M1     = 4'd2;
	localparam [3:0] ST_M2     = 4'd3;
	localparam [3:0] ST_M3     = 4'd4;
	localparam [3:0] ST_ACC0   = 4'd5;
	localparam [3:0] ST_ACC1   = 4'd6;
	localparam [3:0] ST_ACC2   = 4'd7;
	localparam [3:0] ST_DONE   = 4'd8;

	reg [3:0] state;
	wire insn_mul16;
	wire busy;
	reg load_operands;
	reg capture_partial;
	reg [1:0] partial_sel;
	reg capture_stage0;
	reg capture_stage1;
	reg capture_stage2;
	wire [31:0] datapath_result;

	assign insn_mul16 = pcpi_valid &&
		(pcpi_insn[6:0]   == CUSTOM_OPCODE) &&
		(pcpi_insn[14:12] == CUSTOM_FUNCT3) &&
		(pcpi_insn[31:25] == CUSTOM_FUNCT7);

	assign busy = (state != ST_IDLE);
	assign pcpi_wait = insn_mul16 || busy;

	approx_mul16_iter_datapath #(
		.LOA_K(LOA_K),
		.M0_APPROX(M0_APPROX),
		.M1_APPROX(M1_APPROX),
		.M2_APPROX(M2_APPROX),
		.M3_APPROX(M3_APPROX)
	) datapath (
		.clk(clk),
		.resetn(resetn),
		.load_operands(load_operands),
		.capture_partial(capture_partial),
		.partial_sel(partial_sel),
		.capture_stage0(capture_stage0),
		.capture_stage1(capture_stage1),
		.capture_stage2(capture_stage2),
		.a_in(pcpi_rs1[15:0]),
		.b_in(pcpi_rs2[15:0]),
		.result(datapath_result)
	);

	always @* begin
		load_operands = 1'b0;
		capture_partial = 1'b0;
		partial_sel = 2'd0;
		capture_stage0 = 1'b0;
		capture_stage1 = 1'b0;
		capture_stage2 = 1'b0;

		case (state)
			ST_IDLE: begin
				if (insn_mul16)
					load_operands = 1'b1;
			end
			ST_M0: begin
				capture_partial = 1'b1;
				partial_sel = 2'd0;
			end
			ST_M1: begin
				capture_partial = 1'b1;
				partial_sel = 2'd1;
			end
			ST_M2: begin
				capture_partial = 1'b1;
				partial_sel = 2'd2;
			end
			ST_M3: begin
				capture_partial = 1'b1;
				partial_sel = 2'd3;
			end
			ST_ACC0: capture_stage0 = 1'b1;
			ST_ACC1: capture_stage1 = 1'b1;
			ST_ACC2: capture_stage2 = 1'b1;
			default: begin end
		endcase
	end

	always @(posedge clk) begin
		if (!resetn) begin
			state <= ST_IDLE;
			pcpi_wr <= 1'b0;
			pcpi_ready <= 1'b0;
			pcpi_rd <= 32'b0;
		end else begin
			pcpi_wr <= 1'b0;
			pcpi_ready <= 1'b0;

			case (state)
				ST_IDLE: if (insn_mul16) state <= ST_M0;
				ST_M0: state <= ST_M1;
				ST_M1: state <= ST_M2;
				ST_M2: state <= ST_M3;
				ST_M3: state <= ST_ACC0;
				ST_ACC0: state <= ST_ACC1;
				ST_ACC1: state <= ST_ACC2;
				ST_ACC2: state <= ST_DONE;
				ST_DONE: begin
					pcpi_wr <= 1'b1;
					pcpi_ready <= 1'b1;
					pcpi_rd <= datapath_result;
					state <= ST_IDLE;
				end
				default: state <= ST_IDLE;
			endcase
		end
	end
endmodule
