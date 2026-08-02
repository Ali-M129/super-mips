`default_nettype none

module dual_control_redirect_unit (
    input  wire        branch_valid0,
    input  wire        branch_taken0,
    input  wire [31:0] branch_target0,
    input  wire        branch_valid1,
    input  wire        branch_taken1,
    input  wire [31:0] branch_target1,

    input  wire        id_issue0,
    input  wire        id_is_jump0,
    input  wire        id_is_jr0,
    input  wire [31:0] id_pc0,
    input  wire [25:0] id_jump_index0,
    input  wire [31:0] id_jr_target0,

    input  wire        id_issue1,
    input  wire        id_is_jump1,
    input  wire        id_is_jr1,
    input  wire [31:0] id_pc1,
    input  wire [25:0] id_jump_index1,
    input  wire [31:0] id_jr_target1,

    output wire        branch_redirect_valid,
    output wire        id_redirect_valid,
    output reg         redirect_valid,
    output reg  [31:0] redirect_pc,
    output reg  [2:0]  redirect_cause,
    output wire        redirect_lane1,
    output wire        flush_fd,
    output wire        flush_de,
    output wire        squash_de,
    output wire        kill_issue
);
    localparam [2:0] CAUSE_NONE    = 3'd0;
    localparam [2:0] CAUSE_BRANCH0 = 3'd1;
    localparam [2:0] CAUSE_BRANCH1 = 3'd2;
    localparam [2:0] CAUSE_JUMP0   = 3'd3;
    localparam [2:0] CAUSE_JUMP1   = 3'd4;

    wire branch_req0 = branch_valid0 && branch_taken0;
    wire branch_req1 = branch_valid1 && branch_taken1;
    wire jump_req0   = id_issue0 && id_is_jump0;
    wire jump_req1   = id_issue1 && id_is_jump1;

    wire [31:0] pc4_0 = id_pc0 + 32'd4;
    wire [31:0] pc4_1 = id_pc1 + 32'd4;
    wire [31:0] direct_jump_target0 = {pc4_0[31:28], id_jump_index0, 2'b00};
    wire [31:0] direct_jump_target1 = {pc4_1[31:28], id_jump_index1, 2'b00};
    wire [31:0] jump_target0 = id_is_jr0 ? id_jr_target0 : direct_jump_target0;
    wire [31:0] jump_target1 = id_is_jr1 ? id_jr_target1 : direct_jump_target1;

    assign branch_redirect_valid = branch_req0 || branch_req1;
    assign id_redirect_valid     = jump_req0 || jump_req1;

    always @(*) begin
        redirect_valid = 1'b0;
        redirect_pc    = 32'b0;
        redirect_cause = CAUSE_NONE;

        if (branch_req0) begin
            redirect_valid = 1'b1;
            redirect_pc    = branch_target0;
            redirect_cause = CAUSE_BRANCH0;
        end else if (branch_req1) begin
            redirect_valid = 1'b1;
            redirect_pc    = branch_target1;
            redirect_cause = CAUSE_BRANCH1;
        end else if (jump_req0) begin
            redirect_valid = 1'b1;
            redirect_pc    = jump_target0;
            redirect_cause = CAUSE_JUMP0;
        end else if (jump_req1) begin
            redirect_valid = 1'b1;
            redirect_pc    = jump_target1;
            redirect_cause = CAUSE_JUMP1;
        end
    end

    assign redirect_lane1 = (redirect_cause == CAUSE_BRANCH1) ||
                            (redirect_cause == CAUSE_JUMP1);
    assign flush_fd   = redirect_valid;
    assign flush_de   = branch_redirect_valid;
    assign squash_de  = branch_redirect_valid;
    assign kill_issue = branch_redirect_valid;
endmodule

`default_nettype wire
