`timescale 1ns/1ps
`default_nettype none

module tb_control_hazard;
    integer errors;

    reg backend_ready_raw, slot1_preblocked;
    reg id_valid0, id_legal0, id_jump0, id_jr0;
    reg [31:0] id_pc0;
    reg [25:0] id_index0;
    reg [4:0] id_rs0;
    reg [31:0] id_rs_value0;
    reg id_valid1, id_legal1, id_jump1, id_jr1;
    reg [31:0] id_pc1;
    reg [25:0] id_index1;
    reg [4:0] id_rs1;
    reg [31:0] id_rs_value1;
    reg issue0, issue1;

    reg de_valid0, de_writes0; reg [4:0] de_dest0;
    reg de_valid1, de_writes1; reg [4:0] de_dest1;
    reg em_valid0, em_writes0, em_load0; reg [4:0] em_dest0; reg [31:0] em_data0;
    reg em_valid1, em_writes1, em_load1; reg [4:0] em_dest1; reg [31:0] em_data1;
    reg mw_valid0, mw_writes0; reg [4:0] mw_dest0; reg [31:0] mw_data0;
    reg mw_valid1, mw_writes1; reg [4:0] mw_dest1; reg [31:0] mw_data1;
    reg branch_valid0, branch_taken0; reg [31:0] branch_target0;
    reg branch_valid1, branch_taken1; reg [31:0] branch_target1;

    wire [31:0] jr_target0, jr_target1;
    wire [2:0] jr_sel0, jr_sel1;
    wire jr_stall0, jr_stall1, jr_stall;
    wire issue_ready;
    wire branch_redirect_valid, id_redirect_valid;
    wire redirect_valid; wire [31:0] redirect_pc; wire [2:0] redirect_cause;
    wire redirect_lane1, flush_fd, flush_de, squash_de, kill_issue;

    dual_control_hazard_unit dut (
        .backend_ready_raw(backend_ready_raw), .slot1_preblocked(slot1_preblocked),
        .id_valid0(id_valid0), .id_legal0(id_legal0), .id_is_jump0(id_jump0),
        .id_is_jr0(id_jr0), .id_pc0(id_pc0), .id_jump_index0(id_index0),
        .id_rs0(id_rs0), .id_rs_value0(id_rs_value0),
        .id_valid1(id_valid1), .id_legal1(id_legal1), .id_is_jump1(id_jump1),
        .id_is_jr1(id_jr1), .id_pc1(id_pc1), .id_jump_index1(id_index1),
        .id_rs1(id_rs1), .id_rs_value1(id_rs_value1),
        .issue0(issue0), .issue1(issue1),
        .de_valid0(de_valid0), .de_writes_reg0(de_writes0), .de_dest0(de_dest0),
        .de_valid1(de_valid1), .de_writes_reg1(de_writes1), .de_dest1(de_dest1),
        .em_valid0(em_valid0), .em_writes_reg0(em_writes0), .em_mem_read0(em_load0),
        .em_dest0(em_dest0), .em_forward_data0(em_data0),
        .em_valid1(em_valid1), .em_writes_reg1(em_writes1), .em_mem_read1(em_load1),
        .em_dest1(em_dest1), .em_forward_data1(em_data1),
        .mw_valid0(mw_valid0), .mw_writes_reg0(mw_writes0), .mw_dest0(mw_dest0), .mw_data0(mw_data0),
        .mw_valid1(mw_valid1), .mw_writes_reg1(mw_writes1), .mw_dest1(mw_dest1), .mw_data1(mw_data1),
        .branch_valid0(branch_valid0), .branch_taken0(branch_taken0), .branch_target0(branch_target0),
        .branch_valid1(branch_valid1), .branch_taken1(branch_taken1), .branch_target1(branch_target1),
        .jr_target0(jr_target0), .jr_target1(jr_target1),
        .jr_source_sel0(jr_sel0), .jr_source_sel1(jr_sel1),
        .jr_stall0(jr_stall0), .jr_stall1(jr_stall1), .jr_stall(jr_stall),
        .backend_ready_for_issue(issue_ready),
        .branch_redirect_valid(branch_redirect_valid), .id_redirect_valid(id_redirect_valid),
        .redirect_valid(redirect_valid), .redirect_pc(redirect_pc),
        .redirect_cause(redirect_cause), .redirect_lane1(redirect_lane1),
        .flush_fd(flush_fd), .flush_de(flush_de), .squash_de(squash_de),
        .kill_issue(kill_issue)
    );

    task clear_all;
        begin
            backend_ready_raw=1; slot1_preblocked=0;
            id_valid0=0; id_legal0=0; id_jump0=0; id_jr0=0; id_pc0=0; id_index0=0; id_rs0=0; id_rs_value0=0;
            id_valid1=0; id_legal1=0; id_jump1=0; id_jr1=0; id_pc1=0; id_index1=0; id_rs1=0; id_rs_value1=0;
            issue0=0; issue1=0;
            de_valid0=0; de_writes0=0; de_dest0=0; de_valid1=0; de_writes1=0; de_dest1=0;
            em_valid0=0; em_writes0=0; em_load0=0; em_dest0=0; em_data0=0;
            em_valid1=0; em_writes1=0; em_load1=0; em_dest1=0; em_data1=0;
            mw_valid0=0; mw_writes0=0; mw_dest0=0; mw_data0=0;
            mw_valid1=0; mw_writes1=0; mw_dest1=0; mw_data1=0;
            branch_valid0=0; branch_taken0=0; branch_target0=0;
            branch_valid1=0; branch_taken1=0; branch_target1=0;
        end
    endtask

    task settle;
        begin #1; end
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
        errors=0;
        clear_all();
        $display("\n--- Dual control-hazard direct tests ---");

        settle();
        expect_bit("Idle control path is ready", issue_ready, 1);
        expect_bit("Idle path has no redirect", redirect_valid, 0);

        // Direct J in slot0; upper target bits come from PC+4.
        clear_all();
        id_valid0=1; id_legal0=1; id_jump0=1; id_pc0=32'h0fff_fffc;
        id_index0=26'h000001; issue0=1;
        settle();
        expect_bit("Slot0 J redirects", redirect_valid, 1);
        expect_32("Slot0 J target uses PC+4 high nibble", redirect_pc, 32'h1000_0004);
        expect_3("Slot0 J cause", redirect_cause, 3);
        expect_bit("ID jump flushes fetch", flush_fd, 1);
        expect_bit("ID jump preserves D/E", flush_de, 0);
        expect_bit("ID jump does not kill its own issue", kill_issue, 0);

        // Direct J in slot1.
        clear_all();
        id_valid1=1; id_legal1=1; id_jump1=1; id_pc1=32'h2000_0004;
        id_index1=26'h000010; issue1=1;
        settle();
        expect_32("Slot1 J target", redirect_pc, 32'h2000_0040);
        expect_3("Slot1 J cause", redirect_cause, 4);
        expect_bit("Slot1 redirect is identified", redirect_lane1, 1);

        // JR from the register file.
        clear_all();
        id_valid0=1; id_legal0=1; id_jump0=1; id_jr0=1;
        id_rs0=5; id_rs_value0=32'h0000_1234; issue0=1;
        settle();
        expect_bit("RF-backed JR does not stall", jr_stall, 0);
        expect_3("RF-backed JR select", jr_sel0, 0);
        expect_32("RF-backed JR target", redirect_pc, 32'h0000_1234);

        // R0 is always immediately available and resolves to zero.
        clear_all();
        id_valid0=1; id_legal0=1; id_jump0=1; id_jr0=1;
        id_rs0=0; id_rs_value0=32'hdead_beef; issue0=1;
        settle();
        expect_bit("JR R0 never stalls", jr_stall, 0);
        expect_32("JR R0 resolves to zero", jr_target0, 0);

        // D/E producer is unavailable and shadows older M/W data.
        clear_all();
        id_valid0=1; id_legal0=1; id_jump0=1; id_jr0=1; id_rs0=7;
        de_valid1=1; de_writes1=1; de_dest1=7;
        mw_valid0=1; mw_writes0=1; mw_dest0=7; mw_data0=32'h1111_1111;
        settle();
        expect_bit("D/E producer stalls JR", jr_stall0, 1);
        expect_3("D/E block select", jr_sel0, 5);
        expect_bit("JR stall blocks issue readiness", issue_ready, 0);

        // A preblocked slot1 JR must not delay the older slot0 instruction.
        clear_all();
        slot1_preblocked=1;
        id_valid1=1; id_legal1=1; id_jump1=1; id_jr1=1; id_rs1=8;
        de_valid0=1; de_writes0=1; de_dest0=8;
        settle();
        expect_bit("Preblocked slot1 JR does not stall bundle", jr_stall1, 0);
        expect_bit("Older slot0 may still issue", issue_ready, 1);

        // E/M ALU forwarding; lane1 is the younger same-stage producer.
        clear_all();
        id_valid0=1; id_legal0=1; id_jump0=1; id_jr0=1; id_rs0=9;
        em_valid0=1; em_writes0=1; em_dest0=9; em_data0=32'h0000_1000;
        settle();
        expect_3("JR forwards from EM0", jr_sel0, 3);
        expect_32("JR EM0 value", jr_target0, 32'h0000_1000);
        em_valid1=1; em_writes1=1; em_dest1=9; em_data1=32'h0000_2000;
        settle();
        expect_3("Younger EM1 beats EM0", jr_sel0, 4);
        expect_32("JR gets youngest EM value", jr_target0, 32'h0000_2000);

        // E/M loads are unavailable and shadow older WB data.
        clear_all();
        id_valid0=1; id_legal0=1; id_jump0=1; id_jr0=1; id_rs0=10;
        em_valid0=1; em_writes0=1; em_load0=1; em_dest0=10;
        mw_valid1=1; mw_writes1=1; mw_dest1=10; mw_data1=32'h3333_3333;
        settle();
        expect_bit("EM0 load stalls JR", jr_stall0, 1);
        expect_3("EM0 load block select", jr_sel0, 6);
        em_valid1=1; em_writes1=1; em_load1=1; em_dest1=10;
        settle();
        expect_3("Younger EM1 load owns block", jr_sel0, 7);

        // M/W forwarding with lane1 priority.
        clear_all();
        id_valid0=1; id_legal0=1; id_jump0=1; id_jr0=1; id_rs0=11;
        mw_valid0=1; mw_writes0=1; mw_dest0=11; mw_data0=32'h4444_4444;
        settle();
        expect_3("JR forwards from MW0", jr_sel0, 1);
        expect_32("JR MW0 value", jr_target0, 32'h4444_4444);
        mw_valid1=1; mw_writes1=1; mw_dest1=11; mw_data1=32'h5555_5555;
        settle();
        expect_3("Younger MW1 beats MW0", jr_sel0, 2);
        expect_32("JR MW1 value", jr_target0, 32'h5555_5555);

        // Taken branch is older than every current ID jump.
        clear_all();
        branch_valid1=1; branch_taken1=1; branch_target1=32'h0000_0080;
        id_valid0=1; id_legal0=1; id_jump0=1; id_pc0=0; id_index0=1; issue0=1;
        settle();
        expect_bit("Taken branch redirect asserted", branch_redirect_valid, 1);
        expect_32("Taken branch beats ID jump", redirect_pc, 32'h0000_0080);
        expect_3("Branch1 redirect cause", redirect_cause, 2);
        expect_bit("Taken branch flushes D/E", flush_de, 1);
        expect_bit("Taken branch blocks D/E advance", squash_de, 1);
        expect_bit("Taken branch kills current issue", kill_issue, 1);
        expect_bit("Taken branch blocks issue readiness", issue_ready, 0);

        // If both defensive branch inputs assert, older lane0 wins.
        branch_valid0=1; branch_taken0=1; branch_target0=32'h0000_0040;
        settle();
        expect_32("Older branch0 wins dual-branch defense", redirect_pc, 32'h0000_0040);
        expect_3("Branch0 redirect cause", redirect_cause, 1);
        expect_bit("Branch0 identifies lane0", redirect_lane1, 0);

        // Raw backend pressure is preserved by the control wrapper.
        clear_all(); backend_ready_raw=0; settle();
        expect_bit("Backend pressure blocks issue", issue_ready, 0);

        if (errors == 0)
            $display("\nCONTROL_HAZARD_TESTS_PASS");
        else begin
            $display("\nCONTROL_HAZARD_TESTS_FAIL: %0d error(s)", errors);
            $fatal(1);
        end
        $finish;
    end
endmodule

`default_nettype wire
