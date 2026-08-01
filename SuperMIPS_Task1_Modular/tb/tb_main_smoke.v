`timescale 1ns/1ps
`default_nettype none

module tb_main_smoke;
    reg Clk;
    reg Rst;
    wire [31:0] InstrIn;
    wire [31:0] DataIn;

    wire [31:0] R0, R1, R2, R3, R4, R5, R6, R7;
    wire [31:0] R8, R9, R10, R11, R12, R13, R14, R15;
    wire [31:0] R16, R17, R18, R19, R20, R21, R22, R23;
    wire [31:0] R24, R25, R26, R27, R28, R29, R30, R31;
    wire [31:0] InstrAddr, DataAddr, DataOut;
    wire DataWrite;
    wire [31:0] D_PC, D_Instr, D_Rs, D_Rt;
    wire D_Valid, D_RsValid, D_RtValid, D_ImmValid, D_AddressValid;
    wire [15:0] D_Imm;
    wire [25:0] D_Address;
    wire [31:0] E_PC, E_Instr, E_Res;
    wire E_Valid, E_ResValid;
    wire [31:0] W_PC, W_Instr;
    wire W_Valid;

    reg [31:0] imem [0:255];
    reg [31:0] dmem [0:255];
    integer i;
    integer errors;
    integer cycles;
    integer retired;
    integer stalls;
    integer branch_redirects;
    integer jump_redirects;

    main dut (
        .Clk(Clk), .Rst(Rst), .InstrIn(InstrIn), .DataIn(DataIn),
        .R0(R0), .R1(R1), .R2(R2), .R3(R3), .R4(R4), .R5(R5), .R6(R6), .R7(R7),
        .R8(R8), .R9(R9), .R10(R10), .R11(R11), .R12(R12), .R13(R13), .R14(R14), .R15(R15),
        .R16(R16), .R17(R17), .R18(R18), .R19(R19), .R20(R20), .R21(R21), .R22(R22), .R23(R23),
        .R24(R24), .R25(R25), .R26(R26), .R27(R27), .R28(R28), .R29(R29), .R30(R30), .R31(R31),
        .InstrAddr(InstrAddr), .DataAddr(DataAddr), .DataWrite(DataWrite), .DataOut(DataOut),
        .D_PC(D_PC), .D_Instr(D_Instr), .D_Rs(D_Rs), .D_Rt(D_Rt),
        .D_Valid(D_Valid), .D_RsValid(D_RsValid), .D_RtValid(D_RtValid),
        .D_ImmValid(D_ImmValid), .D_AddressValid(D_AddressValid),
        .D_Imm(D_Imm), .D_Address(D_Address),
        .E_PC(E_PC), .E_Instr(E_Instr), .E_Res(E_Res), .E_Valid(E_Valid), .E_ResValid(E_ResValid),
        .W_PC(W_PC), .W_Instr(W_Instr), .W_Valid(W_Valid)
    );

    assign InstrIn = imem[InstrAddr[7:0]];
    assign DataIn  = dmem[DataAddr[7:0]];

    always #5 Clk = ~Clk;

    always @(posedge Clk) begin
        if (Rst) begin
            cycles <= 0;
            retired <= 0;
            stalls <= 0;
            branch_redirects <= 0;
            jump_redirects <= 0;
        end else begin
            cycles <= cycles + 1;
            if (W_Valid)
                retired <= retired + 1;
            if (dut.hold_pipe)
                stalls <= stalls + 1;
            if (dut.do_branch_exec)
                branch_redirects <= branch_redirects + 1;
            if (dut.do_jump_decode)
                jump_redirects <= jump_redirects + 1;

            // Fail at the first X-producing architectural side effect instead
            // of allowing an unknown array index to poison the entire RF/DMEM.
            if (dut.wb_write_enable &&
                ((^dut.m2w_dest === 1'bx) || (^dut.wb_final_val === 1'bx))) begin
                $display("[FATAL] Unknown WB side effect: dst=%b data=%h", dut.m2w_dest, dut.wb_final_val);
                $fatal(1);
            end
            if (DataWrite &&
                ((^DataAddr === 1'bx) || (^DataOut === 1'bx))) begin
                $display("[FATAL] Unknown store side effect: addr=%h data=%h", DataAddr, DataOut);
                $fatal(1);
            end
            if (DataWrite)
                dmem[DataAddr[7:0]] <= DataOut;
        end
    end

    function [31:0] enc_r;
        input [4:0] rs;
        input [4:0] rt;
        input [4:0] rd;
        input [5:0] funct;
        begin
            enc_r = {6'b000000, rs, rt, rd, 5'b00000, funct};
        end
    endfunction

    function [31:0] enc_i;
        input [5:0] opcode;
        input [4:0] rs;
        input [4:0] rt;
        input [15:0] imm;
        begin
            enc_i = {opcode, rs, rt, imm};
        end
    endfunction

    function [31:0] enc_j;
        input [5:0] opcode;
        input [25:0] target_word;
        begin
            enc_j = {opcode, target_word};
        end
    endfunction

    task expect_reg;
        input [511:0] name;
        input [31:0] actual;
        input [31:0] expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s = 0x%08x expected 0x%08x", name, actual, expected);
                errors = errors + 1;
            end else
                $display("[PASS] %0s = 0x%08x", name, actual);
        end
    endtask

    initial begin
        Clk = 1'b0;
        Rst = 1'b1;
        errors = 0;
        cycles = 0;
        retired = 0;
        stalls = 0;
        branch_redirects = 0;
        jump_redirects = 0;

        for (i = 0; i < 256; i = i + 1) begin
            imem[i] = 32'd0;
            dmem[i] = 32'd0;
        end

        // Arithmetic and EX/MEM + MEM/WB forwarding.
        imem[0]  = enc_i(6'b001000, 5'd0, 5'd1, 16'd5);       // addi r1,r0,5
        imem[1]  = enc_i(6'b001000, 5'd0, 5'd2, 16'd7);       // addi r2,r0,7
        imem[2]  = enc_r(5'd1, 5'd2, 5'd3, 6'b100000);        // add r3,r1,r2
        imem[3]  = enc_r(5'd3, 5'd1, 5'd4, 6'b100010);        // sub r4,r3,r1

        // Store data forwarding, load, and a real load-use stall.
        imem[4]  = enc_i(6'b101011, 5'd0, 5'd4, 16'd0);       // sw r4,0(r0)
        imem[5]  = enc_i(6'b100011, 5'd0, 5'd5, 16'd0);       // lw r5,0(r0)
        imem[6]  = enc_r(5'd5, 5'd1, 5'd6, 6'b100000);        // add r6,r5,r1

        // Taken branch squashes word 8.
        imem[7]  = enc_i(6'b000100, 5'd6, 5'd3, 16'd1);       // beq r6,r3,+1
        imem[8]  = enc_i(6'b001000, 5'd0, 5'd7, 16'd99);      // wrong path
        imem[9]  = enc_i(6'b001000, 5'd0, 5'd7, 16'd1);       // branch target

        // jal/jr and unconditional jump.
        imem[10] = enc_j(6'b000011, 26'd14);                  // jal word14
        imem[11] = enc_i(6'b001000, 5'd0, 5'd8, 16'd2);       // return point
        imem[12] = enc_j(6'b000010, 26'd17);                  // j word17
        imem[13] = 32'd0;
        imem[14] = enc_i(6'b001000, 5'd0, 5'd9, 16'd42);      // subroutine
        imem[15] = enc_r(5'd31, 5'd0, 5'd0, 6'b001000);       // jr r31
        imem[16] = enc_i(6'b001000, 5'd0, 5'd8, 16'd99);      // wrong path
        imem[17] = enc_i(6'b001000, 5'd0, 5'd10, 16'd55);     // marker
        imem[18] = enc_j(6'b000010, 26'd18);                  // terminal loop

        $dumpfile("out/main_smoke.vcd");
        $dumpvars(0, tb_main_smoke);

        repeat (3) @(posedge Clk);
        #1 Rst = 1'b0;
        repeat (70) @(posedge Clk);
        #1;

        $display("\n--- Main smoke summary ---");
        $display("cycles=%0d retired=%0d stalls=%0d branch_redirects=%0d jump_redirects=%0d",
                 cycles, retired, stalls, branch_redirects, jump_redirects);

        expect_reg("R0", R0, 32'd0);
        expect_reg("R1", R1, 32'd5);
        expect_reg("R2", R2, 32'd7);
        expect_reg("R3", R3, 32'd12);
        expect_reg("R4", R4, 32'd7);
        expect_reg("R5", R5, 32'd7);
        expect_reg("R6", R6, 32'd12);
        expect_reg("R7", R7, 32'd1);
        expect_reg("R8", R8, 32'd2);
        expect_reg("R9", R9, 32'd42);
        expect_reg("R10", R10, 32'd55);
        expect_reg("R31", R31, 32'd44);

        if (dmem[0] !== 32'd7) begin
            $display("[FAIL] DMEM[0]=0x%08x expected 0x00000007", dmem[0]);
            errors = errors + 1;
        end else
            $display("[PASS] DMEM[0]=0x%08x", dmem[0]);

        if (stalls < 1) begin
            $display("[FAIL] Expected at least one true load-use stall");
            errors = errors + 1;
        end else
            $display("[PASS] Observed %0d stall cycle(s)", stalls);

        if (branch_redirects < 1) begin
            $display("[FAIL] Expected a taken branch redirect");
            errors = errors + 1;
        end

        if (jump_redirects < 3) begin
            $display("[FAIL] Expected J/JAL/JR redirects");
            errors = errors + 1;
        end

        if (errors == 0) begin
            $display("\nMAIN_SMOKE_PASS");
            $finish;
        end else begin
            $display("\nMAIN_SMOKE_FAIL: %0d error(s)", errors);
            $fatal(1);
        end
    end
endmodule

`default_nettype wire
