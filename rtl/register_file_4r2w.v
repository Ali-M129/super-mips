`default_nettype none

module register_file_4r2w (
    input  wire        clk,
    input  wire        rst,

    input  wire [4:0]  raddr0,
    input  wire [4:0]  raddr1,
    input  wire [4:0]  raddr2,
    input  wire [4:0]  raddr3,
    output wire [31:0] rdata0,
    output wire [31:0] rdata1,
    output wire [31:0] rdata2,
    output wire [31:0] rdata3,

    input  wire        we0,
    input  wire [4:0]  waddr0,
    input  wire [31:0] wdata0,
    input  wire        we1,
    input  wire [4:0]  waddr1,
    input  wire [31:0] wdata1,

    output wire [31:0] R0,  R1,  R2,  R3,  R4,  R5,  R6,  R7,
    output wire [31:0] R8,  R9,  R10, R11, R12, R13, R14, R15,
    output wire [31:0] R16, R17, R18, R19, R20, R21, R22, R23,
    output wire [31:0] R24, R25, R26, R27, R28, R29, R30, R31
);
    reg [31:0] regs [31:1];
    integer i;

    function automatic [31:0] apply_bypass;
        input [4:0]  addr;
        input [31:0] stored_value;
        input        we0_i;
        input [4:0]  waddr0_i;
        input [31:0] wdata0_i;
        input        we1_i;
        input [4:0]  waddr1_i;
        input [31:0] wdata1_i;
        begin
            if (addr == 5'd0)
                apply_bypass = 32'd0;
            else if (we1_i && (waddr1_i != 5'd0) && (waddr1_i == addr))
                apply_bypass = wdata1_i;
            else if (we0_i && (waddr0_i != 5'd0) && (waddr0_i == addr))
                apply_bypass = wdata0_i;
            else
                apply_bypass = stored_value;
        end
    endfunction

    wire [31:0] stored0 = (raddr0 == 5'd0) ? 32'd0 : regs[raddr0];
    wire [31:0] stored1 = (raddr1 == 5'd0) ? 32'd0 : regs[raddr1];
    wire [31:0] stored2 = (raddr2 == 5'd0) ? 32'd0 : regs[raddr2];
    wire [31:0] stored3 = (raddr3 == 5'd0) ? 32'd0 : regs[raddr3];

    assign rdata0 = apply_bypass(raddr0, stored0, we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign rdata1 = apply_bypass(raddr1, stored1, we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign rdata2 = apply_bypass(raddr2, stored2, we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign rdata3 = apply_bypass(raddr3, stored3, we0, waddr0, wdata0, we1, waddr1, wdata1);

    assign R0  = 32'd0;
    assign R1  = apply_bypass(5'd1,  regs[1],  we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R2  = apply_bypass(5'd2,  regs[2],  we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R3  = apply_bypass(5'd3,  regs[3],  we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R4  = apply_bypass(5'd4,  regs[4],  we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R5  = apply_bypass(5'd5,  regs[5],  we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R6  = apply_bypass(5'd6,  regs[6],  we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R7  = apply_bypass(5'd7,  regs[7],  we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R8  = apply_bypass(5'd8,  regs[8],  we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R9  = apply_bypass(5'd9,  regs[9],  we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R10 = apply_bypass(5'd10, regs[10], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R11 = apply_bypass(5'd11, regs[11], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R12 = apply_bypass(5'd12, regs[12], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R13 = apply_bypass(5'd13, regs[13], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R14 = apply_bypass(5'd14, regs[14], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R15 = apply_bypass(5'd15, regs[15], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R16 = apply_bypass(5'd16, regs[16], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R17 = apply_bypass(5'd17, regs[17], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R18 = apply_bypass(5'd18, regs[18], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R19 = apply_bypass(5'd19, regs[19], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R20 = apply_bypass(5'd20, regs[20], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R21 = apply_bypass(5'd21, regs[21], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R22 = apply_bypass(5'd22, regs[22], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R23 = apply_bypass(5'd23, regs[23], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R24 = apply_bypass(5'd24, regs[24], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R25 = apply_bypass(5'd25, regs[25], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R26 = apply_bypass(5'd26, regs[26], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R27 = apply_bypass(5'd27, regs[27], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R28 = apply_bypass(5'd28, regs[28], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R29 = apply_bypass(5'd29, regs[29], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R30 = apply_bypass(5'd30, regs[30], we0, waddr0, wdata0, we1, waddr1, wdata1);
    assign R31 = apply_bypass(5'd31, regs[31], we0, waddr0, wdata0, we1, waddr1, wdata1);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 1; i <= 31; i = i + 1)
                regs[i] <= 32'd0;
        end else begin
            if (we0 && (waddr0 != 5'd0))
                regs[waddr0] <= wdata0;
            if (we1 && (waddr1 != 5'd0))
                regs[waddr1] <= wdata1;
        end
    end
endmodule

`default_nettype wire
