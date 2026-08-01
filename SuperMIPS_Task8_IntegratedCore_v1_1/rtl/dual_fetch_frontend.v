`timescale 1ns/1ps
`default_nettype none

// -----------------------------------------------------------------------------
// Dual-fetch PC controller plus a two-slot IF/ID buffer.
//
// Memory contract:
//   * imem_addr0/imem_addr1 are combinational request addresses.
//   * imem_instr*_in and imem_valid*_in must correspond to those addresses in
//     the same cycle (a combinational/asynchronous instruction memory model).
//   * On the active clock edge, the requested pair is captured into IF/ID.
//
// Consumption contract:
//   advance_count=0 -> refetch/retain the current base address
//   advance_count=1 -> next pair starts at old slot 1 (PC + 4)
//   advance_count=2 -> next pair starts after both words (PC + 8)
//
// redirect_valid has priority over flush and hold.  This lets a resolved jump
// or taken branch replace all younger sequential words immediately.
// Illegal advance_count=3 is handled as a safe hold and reported explicitly.
// -----------------------------------------------------------------------------
module dual_fetch_frontend #(
    parameter [31:0] RESET_PC = 32'd0
) (
    input  wire        clk,
    input  wire        reset,

    input  wire        hold,
    input  wire        flush,
    input  wire        redirect_valid,
    input  wire [31:0] redirect_pc,
    input  wire [1:0]  advance_count,

    output wire [31:0] imem_addr0,
    output wire [31:0] imem_addr1,
    input  wire        imem_valid0_in,
    input  wire        imem_valid1_in,
    input  wire [31:0] imem_instr0_in,
    input  wire [31:0] imem_instr1_in,

    output wire        fd_valid0,
    output wire        fd_valid1,
    output wire [31:0] fd_pc0,
    output wire [31:0] fd_pc1,
    output wire [31:0] fd_instr0,
    output wire [31:0] fd_instr1,

    output wire [31:0] current_base_pc,
    output wire [31:0] requested_base_pc,
    output wire        fetch_load,
    output wire        advance_count_illegal
);
    reg [31:0] base_pc_q;
    reg [31:0] sequential_next_pc;

    assign advance_count_illegal = (advance_count == 2'b11);

    always @(*) begin
        case (advance_count)
            2'd0: sequential_next_pc = base_pc_q;
            2'd1: sequential_next_pc = base_pc_q + 32'd4;
            2'd2: sequential_next_pc = base_pc_q + 32'd8;
            default: sequential_next_pc = base_pc_q;
        endcase
    end

    // The address sent to instruction memory is the pair that will become the
    // next IF/ID contents on the upcoming clock edge.
    assign requested_base_pc = redirect_valid ? redirect_pc :
                               (flush || hold || advance_count_illegal) ? base_pc_q :
                               sequential_next_pc;

    assign imem_addr0 = requested_base_pc;
    assign imem_addr1 = requested_base_pc + 32'd4;

    // A redirect performs an immediate replacement load. A plain flush creates
    // an empty IF/ID pair for one cycle; the same base can be refetched later.
    assign fetch_load = redirect_valid ||
                        (!flush && !hold && !advance_count_illegal);

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            base_pc_q <= RESET_PC;
        end else if (redirect_valid) begin
            base_pc_q <= redirect_pc;
        end else if (flush || hold || advance_count_illegal) begin
            base_pc_q <= base_pc_q;
        end else begin
            base_pc_q <= sequential_next_pc;
        end
    end

    fetch_pair_buffer #(.RESET_PC(RESET_PC)) fd_buffer (
        .clk(clk),
        .reset(reset),
        .flush(flush && !redirect_valid),
        .hold((hold || advance_count_illegal) && !redirect_valid && !flush),
        .load(fetch_load),
        .in_valid0(imem_valid0_in),
        .in_valid1(imem_valid1_in),
        .in_pc0(imem_addr0),
        .in_pc1(imem_addr1),
        .in_instr0(imem_instr0_in),
        .in_instr1(imem_instr1_in),
        .out_valid0(fd_valid0),
        .out_valid1(fd_valid1),
        .out_pc0(fd_pc0),
        .out_pc1(fd_pc1),
        .out_instr0(fd_instr0),
        .out_instr1(fd_instr1)
    );

    assign current_base_pc = base_pc_q;
endmodule

`default_nettype wire
