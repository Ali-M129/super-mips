`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

module tb_control_backend;
    integer errors;
    integer i;
    integer commit_count [0:31];

    reg clk, reset;
    reg manual_hold_de, hold_em, hold_mw;
    reg manual_flush_de, flush_em, flush_mw;

    reg in_valid0, in_valid1;
    reg [31:0] in_pc0, in_pc1;
    reg [4:0] in_rs0, in_rt0, in_rs1, in_rt1;
    reg in_uses_rs0, in_uses_rt0, in_uses_rs1, in_uses_rt1;
    reg [31:0] in_src_a0, in_src_b0, in_imm0;
    reg [31:0] in_src_a1, in_src_b1, in_imm1;
    reg in_alu_src0, in_alu_src1;
    reg [3:0] in_alu_op0, in_alu_op1;
    reg in_writes0, in_writes1;
    reg [4:0] in_dest0, in_dest1;
    reg in_mem_read0, in_mem_write0, in_mem_read1, in_mem_write1;
    reg [1:0] in_wb_sel0, in_wb_sel1;
    reg in_branch0, in_branch1;
    reg [31:0] in_branch_target0, in_branch_target1;

    // ID-stage control candidate held outside the backend.
    reg id_valid0, id_legal0, id_jump0, id_jr0;
    reg [31:0] id_pc0; reg [25:0] id_index0; reg [4:0] id_rs0; reg [31:0] id_rf0;
    reg id_valid1, id_legal1, id_jump1, id_jr1;
    reg [31:0] id_pc1; reg [25:0] id_index1; reg [4:0] id_rs1; reg [31:0] id_rf1;
    reg slot1_preblocked;

    reg [31:0] dmem [0:255];
    wire [31:0] mem_read_data;
    wire mem_req_valid, mem_req_write;
    wire [31:0] mem_word_addr, mem_write_data;

    wire backend_input_ready;
    wire load_use_stall;

    wire de_valid0, de_valid1;
    wire [4:0] de_dest0, de_dest1;
    wire de_writes0, de_writes1;

    wire em_valid0, em_valid1;
    wire [31:0] em_pc0, em_pc1;
    wire [31:0] em_result0, em_result1;
    wire [4:0] em_dest0, em_dest1;
    wire em_writes0, em_writes1;
    wire em_load0, em_load1;
    wire [1:0] em_wb_sel0, em_wb_sel1;
    wire em_branch_taken0, em_branch_taken1;
    wire [31:0] em_branch_target0, em_branch_target1;

    wire mw_valid0, mw_valid1;
    wire wb_valid0, wb_valid1, wb_we0, wb_we1;
    wire [4:0] wb_dest0, wb_dest1;
    wire [31:0] wb_data0, wb_data1;

    wire [31:0] em_forward0 = (em_wb_sel0 == `WB_PC4) ? (em_pc0 + 32'd4) : em_result0;
    wire [31:0] em_forward1 = (em_wb_sel1 == `WB_PC4) ? (em_pc1 + 32'd4) : em_result1;

    wire [31:0] jr_target0, jr_target1;
    wire [2:0] jr_sel0, jr_sel1;
    wire jr_stall0, jr_stall1, jr_stall;
    wire control_issue_ready;
    wire branch_redirect_valid, id_redirect_valid;
    wire redirect_valid; wire [31:0] redirect_pc; wire [2:0] redirect_cause;
    wire redirect_lane1, control_flush_fd, control_flush_de, control_squash_de, kill_issue;

    wire auto_issue0 = id_valid0 && id_legal0 && control_issue_ready;
    wire auto_issue1 = id_valid1 && id_legal1 && control_issue_ready && !slot1_preblocked;

    wire backend_hold_de  = manual_hold_de  || control_squash_de;
    wire backend_flush_de = manual_flush_de || control_flush_de;

    // Small frontend instance used only to prove that control redirects replace
    // the current pair even when the ordinary path would hold.
    reg frontend_hold, frontend_flush;
    reg [1:0] frontend_advance;
    wire [31:0] imem_addr0, imem_addr1;
    wire fd_valid0, fd_valid1; wire [31:0] fd_pc0, fd_pc1, fd_instr0, fd_instr1;
    wire [31:0] current_base_pc, requested_base_pc;
    wire fetch_load, advance_illegal;

    assign mem_read_data = dmem[mem_word_addr[7:0]];

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!reset && mem_req_valid && mem_req_write)
            dmem[mem_word_addr[7:0]] <= mem_write_data;
        if (!reset && wb_we0 && (wb_dest0 != 0))
            commit_count[wb_dest0] = commit_count[wb_dest0] + 1;
        if (!reset && wb_we1 && (wb_dest1 != 0))
            commit_count[wb_dest1] = commit_count[wb_dest1] + 1;
    end

    dual_memory_backend backend (
        .clk(clk), .reset(reset),
        .hold_de(backend_hold_de), .hold_em(hold_em), .hold_mw(hold_mw),
        .flush_de(backend_flush_de), .flush_em(flush_em), .flush_mw(flush_mw),

        .in_valid0(in_valid0), .in_pc0(in_pc0), .in_rs0(in_rs0), .in_rt0(in_rt0),
        .in_uses_rs0(in_uses_rs0), .in_uses_rt0(in_uses_rt0),
        .in_src_a0(in_src_a0), .in_src_b0(in_src_b0), .in_imm0(in_imm0),
        .in_alu_src_imm0(in_alu_src0), .in_alu_op0(in_alu_op0),
        .in_writes_reg0(in_writes0), .in_dest_reg0(in_dest0),
        .in_mem_read0(in_mem_read0), .in_mem_write0(in_mem_write0),
        .in_wb_sel0(in_wb_sel0), .in_is_branch0(in_branch0), .in_branch_target0(in_branch_target0),

        .in_valid1(in_valid1), .in_pc1(in_pc1), .in_rs1(in_rs1), .in_rt1(in_rt1),
        .in_uses_rs1(in_uses_rs1), .in_uses_rt1(in_uses_rt1),
        .in_src_a1(in_src_a1), .in_src_b1(in_src_b1), .in_imm1(in_imm1),
        .in_alu_src_imm1(in_alu_src1), .in_alu_op1(in_alu_op1),
        .in_writes_reg1(in_writes1), .in_dest_reg1(in_dest1),
        .in_mem_read1(in_mem_read1), .in_mem_write1(in_mem_write1),
        .in_wb_sel1(in_wb_sel1), .in_is_branch1(in_branch1), .in_branch_target1(in_branch_target1),

        .mem_read_data(mem_read_data),
        .mem_req_valid(mem_req_valid), .mem_req_write(mem_req_write),
        .mem_word_addr(mem_word_addr), .mem_write_data(mem_write_data),
        .input_ready(backend_input_ready), .load_use_stall(load_use_stall),

        .de_valid0(de_valid0), .de_writes_reg0(de_writes0), .de_dest_reg0(de_dest0),
        .de_valid1(de_valid1), .de_writes_reg1(de_writes1), .de_dest_reg1(de_dest1),

        .em_valid0(em_valid0), .em_pc0(em_pc0), .em_alu_result0(em_result0),
        .em_dest_reg0(em_dest0), .em_writes_reg0(em_writes0),
        .em_mem_read0(em_load0), .em_wb_sel0(em_wb_sel0),
        .em_branch_taken0(em_branch_taken0), .em_branch_target0(em_branch_target0),
        .em_valid1(em_valid1), .em_pc1(em_pc1), .em_alu_result1(em_result1),
        .em_dest_reg1(em_dest1), .em_writes_reg1(em_writes1),
        .em_mem_read1(em_load1), .em_wb_sel1(em_wb_sel1),
        .em_branch_taken1(em_branch_taken1), .em_branch_target1(em_branch_target1),

        .mw_valid0(mw_valid0), .mw_valid1(mw_valid1),
        .wb_valid0(wb_valid0), .wb_we0(wb_we0), .wb_dest0(wb_dest0), .wb_data0(wb_data0),
        .wb_valid1(wb_valid1), .wb_we1(wb_we1), .wb_dest1(wb_dest1), .wb_data1(wb_data1)
    );

    dual_control_hazard_unit control (
        .backend_ready_raw(backend_input_ready), .slot1_preblocked(slot1_preblocked),
        .id_valid0(id_valid0), .id_legal0(id_legal0), .id_is_jump0(id_jump0), .id_is_jr0(id_jr0),
        .id_pc0(id_pc0), .id_jump_index0(id_index0), .id_rs0(id_rs0), .id_rs_value0(id_rf0),
        .id_valid1(id_valid1), .id_legal1(id_legal1), .id_is_jump1(id_jump1), .id_is_jr1(id_jr1),
        .id_pc1(id_pc1), .id_jump_index1(id_index1), .id_rs1(id_rs1), .id_rs_value1(id_rf1),
        .issue0(auto_issue0), .issue1(auto_issue1),
        .de_valid0(de_valid0), .de_writes_reg0(de_writes0), .de_dest0(de_dest0),
        .de_valid1(de_valid1), .de_writes_reg1(de_writes1), .de_dest1(de_dest1),
        .em_valid0(em_valid0), .em_writes_reg0(em_writes0), .em_mem_read0(em_load0),
        .em_dest0(em_dest0), .em_forward_data0(em_forward0),
        .em_valid1(em_valid1), .em_writes_reg1(em_writes1), .em_mem_read1(em_load1),
        .em_dest1(em_dest1), .em_forward_data1(em_forward1),
        .mw_valid0(wb_valid0), .mw_writes_reg0(wb_we0), .mw_dest0(wb_dest0), .mw_data0(wb_data0),
        .mw_valid1(wb_valid1), .mw_writes_reg1(wb_we1), .mw_dest1(wb_dest1), .mw_data1(wb_data1),
        .branch_valid0(em_valid0), .branch_taken0(em_branch_taken0), .branch_target0(em_branch_target0),
        .branch_valid1(em_valid1), .branch_taken1(em_branch_taken1), .branch_target1(em_branch_target1),
        .jr_target0(jr_target0), .jr_target1(jr_target1),
        .jr_source_sel0(jr_sel0), .jr_source_sel1(jr_sel1),
        .jr_stall0(jr_stall0), .jr_stall1(jr_stall1), .jr_stall(jr_stall),
        .backend_ready_for_issue(control_issue_ready),
        .branch_redirect_valid(branch_redirect_valid), .id_redirect_valid(id_redirect_valid),
        .redirect_valid(redirect_valid), .redirect_pc(redirect_pc), .redirect_cause(redirect_cause),
        .redirect_lane1(redirect_lane1), .flush_fd(control_flush_fd),
        .flush_de(control_flush_de), .squash_de(control_squash_de), .kill_issue(kill_issue)
    );

    dual_fetch_frontend frontend (
        .clk(clk), .reset(reset), .hold(frontend_hold), .flush(frontend_flush),
        .redirect_valid(redirect_valid), .redirect_pc(redirect_pc),
        .advance_count(frontend_advance),
        .imem_addr0(imem_addr0), .imem_addr1(imem_addr1),
        .imem_valid0_in(1'b1), .imem_valid1_in(1'b1),
        .imem_instr0_in(imem_addr0), .imem_instr1_in(imem_addr1),
        .fd_valid0(fd_valid0), .fd_valid1(fd_valid1),
        .fd_pc0(fd_pc0), .fd_pc1(fd_pc1), .fd_instr0(fd_instr0), .fd_instr1(fd_instr1),
        .current_base_pc(current_base_pc), .requested_base_pc(requested_base_pc),
        .fetch_load(fetch_load), .advance_count_illegal(advance_illegal)
    );

    task step;
        begin @(posedge clk); #1; end
    endtask

    task clear_backend_inputs;
        begin
            in_valid0=0; in_valid1=0; in_pc0=0; in_pc1=0;
            in_rs0=0; in_rt0=0; in_rs1=0; in_rt1=0;
            in_uses_rs0=0; in_uses_rt0=0; in_uses_rs1=0; in_uses_rt1=0;
            in_src_a0=0; in_src_b0=0; in_imm0=0; in_src_a1=0; in_src_b1=0; in_imm1=0;
            in_alu_src0=0; in_alu_src1=0; in_alu_op0=`ALU_ADD; in_alu_op1=`ALU_ADD;
            in_writes0=0; in_writes1=0; in_dest0=0; in_dest1=0;
            in_mem_read0=0; in_mem_write0=0; in_mem_read1=0; in_mem_write1=0;
            in_wb_sel0=`WB_ALU; in_wb_sel1=`WB_ALU;
            in_branch0=0; in_branch1=0; in_branch_target0=0; in_branch_target1=0;
        end
    endtask

    task clear_id;
        begin
            id_valid0=0; id_legal0=0; id_jump0=0; id_jr0=0; id_pc0=0; id_index0=0; id_rs0=0; id_rf0=0;
            id_valid1=0; id_legal1=0; id_jump1=0; id_jr1=0; id_pc1=0; id_index1=0; id_rs1=0; id_rf1=0;
            slot1_preblocked=0;
        end
    endtask

    task reset_dut;
        begin
            clear_backend_inputs(); clear_id();
            manual_hold_de=0; hold_em=0; hold_mw=0;
            manual_flush_de=0; flush_em=0; flush_mw=0;
            frontend_hold=0; frontend_flush=0; frontend_advance=0;
            for (i=0; i<32; i=i+1) commit_count[i]=0;
            reset=1; step(); reset=0; step();
        end
    endtask

    task expect_bit;
        input [511:0] name; input actual, expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s actual=%b expected=%b", name, actual, expected);
                errors=errors+1;
            end else $display("[PASS] %0s", name);
        end
    endtask

    task expect_3;
        input [511:0] name; input [2:0] actual, expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s actual=%0d expected=%0d", name, actual, expected);
                errors=errors+1;
            end else $display("[PASS] %0s = %0d", name, actual);
        end
    endtask

    task expect_32;
        input [511:0] name; input [31:0] actual, expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s actual=0x%08x expected=0x%08x", name, actual, expected);
                errors=errors+1;
            end else $display("[PASS] %0s = 0x%08x", name, actual);
        end
    endtask

    initial begin
        errors=0; clk=0; reset=0;
        clear_backend_inputs(); clear_id();
        manual_hold_de=0; hold_em=0; hold_mw=0;
        manual_flush_de=0; flush_em=0; flush_mw=0;
        frontend_hold=0; frontend_flush=0; frontend_advance=0;
        for (i=0; i<256; i=i+1) dmem[i]=0;
        for (i=0; i<32; i=i+1) commit_count[i]=0;

        $display("\n--- Control + backend integration tests ---");

        // --------------------------------------------------------------
        // Taken lane1 branch preserves older lane0 but squashes the two
        // younger instructions that are already resident in D/E.
        // --------------------------------------------------------------
        reset_dut();
        in_valid0=1; in_pc0=32'h100; in_imm0=7; in_alu_src0=1;
        in_writes0=1; in_dest0=1;
        in_valid1=1; in_pc1=32'h104; in_src_a1=32'h55; in_src_b1=32'h55;
        in_uses_rs1=1; in_uses_rt1=1; in_branch1=1; in_alu_op1=`ALU_SUB;
        in_branch_target1=32'h0000_0080;
        step();

        in_valid0=1; in_pc0=32'h108; in_imm0=11; in_alu_src0=1; in_writes0=1; in_dest0=2;
        in_valid1=1; in_pc1=32'h10c; in_imm1=12; in_alu_src1=1; in_writes1=1; in_dest1=3;
        step();
        expect_bit("Lane1 branch resolves taken", branch_redirect_valid, 1);
        expect_32("Taken branch redirect target", redirect_pc, 32'h0000_0080);
        expect_3("Taken branch cause is lane1", redirect_cause, 2);
        expect_bit("Taken branch flushes younger D/E", control_flush_de, 1);
        expect_bit("Taken branch blocks D/E advance", control_squash_de, 1);
        expect_bit("Taken branch blocks current issue", control_issue_ready, 0);

        clear_backend_inputs();
        step();
        expect_bit("Older lane0 result still writes back", wb_we0, 1);
        expect_32("Older lane0 result preserved", wb_data0, 7);
        step(); step();
        expect_32("Older result committed exactly once", commit_count[1], 1);
        expect_32("Wrong-path lane0 never committed", commit_count[2], 0);
        expect_32("Wrong-path lane1 never committed", commit_count[3], 0);

        // --------------------------------------------------------------
        // A not-taken branch does not flush younger instructions.
        // --------------------------------------------------------------
        reset_dut();
        in_valid0=1; in_pc0=32'h200; in_imm0=1; in_alu_src0=1; in_writes0=1; in_dest0=4;
        in_valid1=1; in_pc1=32'h204; in_src_a1=1; in_src_b1=2;
        in_uses_rs1=1; in_uses_rt1=1; in_branch1=1; in_alu_op1=`ALU_SUB;
        in_branch_target1=32'h0000_0090;
        step();
        in_valid0=1; in_pc0=32'h208; in_imm0=13; in_alu_src0=1; in_writes0=1; in_dest0=5;
        in_valid1=1; in_pc1=32'h20c; in_imm1=14; in_alu_src1=1; in_writes1=1; in_dest1=6;
        step();
        expect_bit("Unequal branch is not redirected", branch_redirect_valid, 0);
        expect_bit("Not-taken branch does not flush D/E", control_flush_de, 0);
        clear_backend_inputs(); step(); step(); step();
        expect_32("Not-taken younger lane0 commits", commit_count[5], 1);
        expect_32("Not-taken younger lane1 commits", commit_count[6], 1);

        // --------------------------------------------------------------
        // ID jump redirect immediately replaces the frontend pair, even if
        // the ordinary sequential path is held.
        // --------------------------------------------------------------
        reset_dut();
        frontend_hold=1;
        id_valid1=1; id_legal1=1; id_jump1=1; id_pc1=32'h0000_0004;
        id_index1=26'h000010;
        #1;
        expect_bit("Slot1 jump is accepted", auto_issue1, 1);
        expect_32("Jump requests target pair", requested_base_pc, 32'h0000_0040);
        step();
        expect_32("Frontend base replaced by jump", current_base_pc, 32'h0000_0040);
        expect_32("Frontend slot0 is jump target", fd_pc0, 32'h0000_0040);
        expect_bit("ID jump does not squash backend D/E", control_squash_de, 0);
        frontend_hold=0; clear_id();

        // --------------------------------------------------------------
        // An ALU producer directly ahead of JR stalls in D/E, then forwards
        // from E/M without waiting for writeback.
        // --------------------------------------------------------------
        reset_dut();
        in_valid0=1; in_pc0=32'h300; in_imm0=32'h0000_0120;
        in_alu_src0=1; in_writes0=1; in_dest0=7;
        step();
        clear_backend_inputs();
        id_valid0=1; id_legal0=1; id_jump0=1; id_jr0=1; id_rs0=7; id_rf0=0;
        #1;
        expect_bit("JR waits for D/E ALU producer", jr_stall0, 1);
        expect_bit("Stalled JR emits no redirect", redirect_valid, 0);
        step();
        expect_bit("JR releases when ALU reaches E/M", jr_stall0, 0);
        expect_3("JR forwards ALU target from EM0", jr_sel0, 3);
        expect_32("JR forwarded ALU target", jr_target0, 32'h0000_0120);
        expect_bit("Resolved JR redirects", redirect_valid, 1);
        expect_32("Resolved JR redirect PC", redirect_pc, 32'h0000_0120);
        clear_id(); step();

        // --------------------------------------------------------------
        // A load target is unavailable in both D/E and E/M. JR releases only
        // when the real RAM value reaches M/W.
        // --------------------------------------------------------------
        reset_dut();
        dmem[8]=32'h0000_0180;
        in_valid0=1; in_pc0=32'h400; in_src_a0=0; in_imm0=32'd32;
        in_uses_rs0=1; in_alu_src0=1; in_writes0=1; in_dest0=8;
        in_mem_read0=1; in_wb_sel0=`WB_MEM;
        step();
        clear_backend_inputs();
        id_valid0=1; id_legal0=1; id_jump0=1; id_jr0=1; id_rs0=8;
        #1;
        expect_bit("JR waits for D/E load", jr_stall0, 1);
        step();
        expect_bit("JR still waits for E/M load", jr_stall0, 1);
        expect_3("JR identifies EM0 load block", jr_sel0, 6);
        step();
        expect_bit("JR releases at M/W", jr_stall0, 0);
        expect_3("JR forwards loaded target from MW0", jr_sel0, 1);
        expect_32("JR receives real loaded target", jr_target0, 32'h0000_0180);
        expect_32("Loaded JR redirects correctly", redirect_pc, 32'h0000_0180);

        expect_bit("No illegal frontend advance", advance_illegal, 0);
        expect_bit("No unexpected load-use stall in control tests", load_use_stall, 0);

        if (errors == 0)
            $display("\nCONTROL_BACKEND_TESTS_PASS");
        else begin
            $display("\nCONTROL_BACKEND_TESTS_FAIL: %0d error(s)", errors);
            $fatal(1);
        end
        $finish;
    end
endmodule

`default_nettype wire
