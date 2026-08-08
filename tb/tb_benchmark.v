`timescale 1ns/1ps
`default_nettype none

module tb_benchmark;
    localparam integer IMEM_WORDS = 4096;
    localparam integer DMEM_WORDS = 256;

    integer i;
    integer errors;
    integer timeout_cycles;
    integer program_words;
    integer max_cycles;
    integer mem_compare_words;
    integer have_dmem_init;
    integer have_expected_regs;
    integer have_expected_dmem;
    integer have_vcd;
    integer plusarg_ignored;

    real dual_ipc;
    real single_ipc;
    real dual_cpi;
    real single_cpi;
    real speedup;
    real improvement_pct;

    reg clk;
    reg reset;
    reg [31:0] imem [0:IMEM_WORDS-1];
    reg [31:0] dmem_dual [0:DMEM_WORDS-1];
    reg [31:0] dmem_single [0:DMEM_WORDS-1];
    reg [31:0] expected_regs [0:31];
    reg [31:0] expected_dmem [0:DMEM_WORDS-1];

    reg [8*256-1:0] program_file;
    reg [8*256-1:0] dmem_file;
    reg [8*256-1:0] expected_regs_file;
    reg [8*256-1:0] expected_dmem_file;
    reg [8*256-1:0] benchmark_name;
    reg [8*256-1:0] vcd_file;

    wire [31:0] ia0_d, ia1_d, ia0_s, ia1_s;
    wire iv0_d = (ia0_d[1:0] == 2'b00) && (ia0_d[31:2] < program_words);
    wire iv1_d = (ia1_d[1:0] == 2'b00) && (ia1_d[31:2] < program_words);
    wire iv0_s = (ia0_s[1:0] == 2'b00) && (ia0_s[31:2] < program_words);
    wire iv1_s = (ia1_s[1:0] == 2'b00) && (ia1_s[31:2] < program_words);
    wire [31:0] ii0_d = iv0_d ? imem[ia0_d[31:2]] : 32'b0;
    wire [31:0] ii1_d = iv1_d ? imem[ia1_d[31:2]] : 32'b0;
    wire [31:0] ii0_s = iv0_s ? imem[ia0_s[31:2]] : 32'b0;
    wire [31:0] ii1_s = iv1_s ? imem[ia1_s[31:2]] : 32'b0;

    wire mreq_d, mwrite_d;
    wire [31:0] maddr_d, mwdata_d;
    wire mreq_s, mwrite_s;
    wire [31:0] maddr_s, mwdata_s;
    wire [31:0] mrdata_d = dmem_dual[maddr_d[7:0]];
    wire [31:0] mrdata_s = dmem_single[maddr_s[7:0]];

    wire halted_d, halted_s;
    wire [31:0] cycles_d, retired_d, issued_d, dual_issue_d, dual_retire_d;
    wire [31:0] replay_d, front_stall_d, load_stall_d, mem_conflict_d, redirect_d;
    wire [31:0] cycles_s, retired_s, issued_s, dual_issue_s, dual_retire_s;
    wire [31:0] replay_s, front_stall_s, load_stall_s, mem_conflict_s, redirect_s;

    // Clean dual-core aliases for report waveforms. These are simulation-only
    // observations and do not change the synthesized RTL.
    wire        dbg_issue0_d, dbg_issue1_d;
    wire [1:0]  dbg_advance_count_d;
    wire [4:0]  dbg_issue_block_mask_d;
    wire        dbg_redirect_valid_d;
    wire [31:0] dbg_redirect_pc_d;
    wire [2:0]  dbg_redirect_cause_d;
    wire        dbg_load_use_stall_d, dbg_memory_busy_d;
    wire        dbg_wb_valid0_d, dbg_wb_valid1_d;

    wire [31:0] dbg_fd_pc0_d, dbg_fd_pc1_d;
    wire [31:0] dbg_fd_instr0_d, dbg_fd_instr1_d;
    wire        dbg_replay1_d, dbg_frontend_hold_d;
    wire        dbg_de_valid0_d, dbg_de_valid1_d;
    wire [31:0] dbg_de_pc0_d, dbg_de_pc1_d;
    wire        dbg_em_valid0_d, dbg_em_valid1_d;
    wire [31:0] dbg_em_pc0_d, dbg_em_pc1_d;
    wire        dbg_em_mem_read0_d, dbg_em_mem_read1_d;
    wire        dbg_em_branch_taken0_d, dbg_em_branch_taken1_d;
    wire        dbg_mw_valid0_d, dbg_mw_valid1_d;
    wire [31:0] dbg_mw_pc0_d, dbg_mw_pc1_d;
    wire [7:0]  dbg_load_hazard_mask_d;
    wire        dbg_fwd_a_en0_d, dbg_fwd_b_en0_d;
    wire [2:0]  dbg_fwd_a_sel0_d, dbg_fwd_b_sel0_d;
    wire        dbg_flush_fd_d, dbg_flush_de_d, dbg_kill_issue_d;
    wire        dbg_jr_stall_d;
    wire [4:0]  dbg_wb_dest0_d, dbg_wb_dest1_d;
    wire [31:0] dbg_wb_data0_d, dbg_wb_data1_d;

    wire [31:0] dR0,dR1,dR2,dR3,dR4,dR5,dR6,dR7,dR8,dR9,dR10,dR11,dR12,dR13,dR14,dR15;
    wire [31:0] dR16,dR17,dR18,dR19,dR20,dR21,dR22,dR23,dR24,dR25,dR26,dR27,dR28,dR29,dR30,dR31;
    wire [31:0] sR0,sR1,sR2,sR3,sR4,sR5,sR6,sR7,sR8,sR9,sR10,sR11,sR12,sR13,sR14,sR15;
    wire [31:0] sR16,sR17,sR18,sR19,sR20,sR21,sR22,sR23,sR24,sR25,sR26,sR27,sR28,sR29,sR30,sR31;

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!reset && mreq_d && mwrite_d)
            dmem_dual[maddr_d[7:0]] <= mwdata_d;
        if (!reset && mreq_s && mwrite_s)
            dmem_single[maddr_s[7:0]] <= mwdata_s;
    end

    superscalar_core #(.DUAL_ISSUE(1)) dual_core (
        .clk(clk), .reset(reset),
        .imem_addr0(ia0_d), .imem_addr1(ia1_d),
        .imem_valid0(iv0_d), .imem_valid1(iv1_d),
        .imem_instr0(ii0_d), .imem_instr1(ii1_d),
        .dmem_read_data(mrdata_d), .dmem_req_valid(mreq_d),
        .dmem_req_write(mwrite_d), .dmem_word_addr(maddr_d), .dmem_write_data(mwdata_d),
        .halted(halted_d), .cycle_count(cycles_d), .retired_count(retired_d),
        .issued_count(issued_d), .dual_issue_cycles(dual_issue_d),
        .dual_retire_cycles(dual_retire_d), .replay_count(replay_d),
        .frontend_stall_count(front_stall_d), .load_stall_count(load_stall_d),
        .memory_conflict_count(mem_conflict_d), .redirect_count(redirect_d),
        .issue0_debug(dbg_issue0_d), .issue1_debug(dbg_issue1_d),
        .advance_count_debug(dbg_advance_count_d),
        .issue_block_mask_debug(dbg_issue_block_mask_d),
        .redirect_valid_debug(dbg_redirect_valid_d),
        .redirect_pc_debug(dbg_redirect_pc_d),
        .redirect_cause_debug(dbg_redirect_cause_d),
        .load_use_stall_debug(dbg_load_use_stall_d),
        .memory_busy_debug(dbg_memory_busy_d),
        .wb_valid0_debug(dbg_wb_valid0_d), .wb_valid1_debug(dbg_wb_valid1_d),
        .R0(dR0),.R1(dR1),.R2(dR2),.R3(dR3),.R4(dR4),.R5(dR5),.R6(dR6),.R7(dR7),
        .R8(dR8),.R9(dR9),.R10(dR10),.R11(dR11),.R12(dR12),.R13(dR13),.R14(dR14),.R15(dR15),
        .R16(dR16),.R17(dR17),.R18(dR18),.R19(dR19),.R20(dR20),.R21(dR21),.R22(dR22),.R23(dR23),
        .R24(dR24),.R25(dR25),.R26(dR26),.R27(dR27),.R28(dR28),.R29(dR29),.R30(dR30),.R31(dR31)
    );

    superscalar_core #(.DUAL_ISSUE(0)) single_core (
        .clk(clk), .reset(reset),
        .imem_addr0(ia0_s), .imem_addr1(ia1_s),
        .imem_valid0(iv0_s), .imem_valid1(iv1_s),
        .imem_instr0(ii0_s), .imem_instr1(ii1_s),
        .dmem_read_data(mrdata_s), .dmem_req_valid(mreq_s),
        .dmem_req_write(mwrite_s), .dmem_word_addr(maddr_s), .dmem_write_data(mwdata_s),
        .halted(halted_s), .cycle_count(cycles_s), .retired_count(retired_s),
        .issued_count(issued_s), .dual_issue_cycles(dual_issue_s),
        .dual_retire_cycles(dual_retire_s), .replay_count(replay_s),
        .frontend_stall_count(front_stall_s), .load_stall_count(load_stall_s),
        .memory_conflict_count(mem_conflict_s), .redirect_count(redirect_s),
        .R0(sR0),.R1(sR1),.R2(sR2),.R3(sR3),.R4(sR4),.R5(sR5),.R6(sR6),.R7(sR7),
        .R8(sR8),.R9(sR9),.R10(sR10),.R11(sR11),.R12(sR12),.R13(sR13),.R14(sR14),.R15(sR15),
        .R16(sR16),.R17(sR17),.R18(sR18),.R19(sR19),.R20(sR20),.R21(sR21),.R22(sR22),.R23(sR23),
        .R24(sR24),.R25(sR25),.R26(sR26),.R27(sR27),.R28(sR28),.R29(sR29),.R30(sR30),.R31(sR31)
    );

    // Additional report-only aliases expose internal pipeline state under stable,
    // short names in the VCD. Hierarchical observation is legal in a testbench.
    assign dbg_fd_pc0_d             = dual_core.fd_pc0;
    assign dbg_fd_pc1_d             = dual_core.fd_pc1;
    assign dbg_fd_instr0_d          = dual_core.fd_instr0;
    assign dbg_fd_instr1_d          = dual_core.fd_instr1;
    assign dbg_replay1_d            = dual_core.replay1;
    assign dbg_frontend_hold_d      = dual_core.frontend_hold;
    assign dbg_de_valid0_d          = dual_core.de_valid0;
    assign dbg_de_valid1_d          = dual_core.de_valid1;
    assign dbg_de_pc0_d             = dual_core.de_pc0;
    assign dbg_de_pc1_d             = dual_core.de_pc1;
    assign dbg_em_valid0_d          = dual_core.em_valid0;
    assign dbg_em_valid1_d          = dual_core.em_valid1;
    assign dbg_em_pc0_d             = dual_core.em_pc0;
    assign dbg_em_pc1_d             = dual_core.em_pc1;
    assign dbg_em_mem_read0_d       = dual_core.em_mem_read0;
    assign dbg_em_mem_read1_d       = dual_core.em_mem_read1;
    assign dbg_em_branch_taken0_d   = dual_core.em_branch_taken0;
    assign dbg_em_branch_taken1_d   = dual_core.em_branch_taken1;
    assign dbg_mw_valid0_d          = dual_core.mw_valid0;
    assign dbg_mw_valid1_d          = dual_core.mw_valid1;
    assign dbg_mw_pc0_d             = dual_core.mw_pc0;
    assign dbg_mw_pc1_d             = dual_core.mw_pc1;
    assign dbg_load_hazard_mask_d   = dual_core.load_hazard_mask;
    assign dbg_fwd_a_en0_d          = dual_core.fwd_a_en0;
    assign dbg_fwd_b_en0_d          = dual_core.fwd_b_en0;
    assign dbg_fwd_a_sel0_d         = dual_core.fwd_a_sel0;
    assign dbg_fwd_b_sel0_d         = dual_core.fwd_b_sel0;
    assign dbg_flush_fd_d           = dual_core.control_flush_fd;
    assign dbg_flush_de_d           = dual_core.control_flush_de;
    assign dbg_kill_issue_d         = dual_core.kill_issue;
    assign dbg_jr_stall_d           = dual_core.jr_stall;
    assign dbg_wb_dest0_d           = dual_core.wb_dest0;
    assign dbg_wb_dest1_d           = dual_core.wb_dest1;
    assign dbg_wb_data0_d           = dual_core.wb_data0;
    assign dbg_wb_data1_d           = dual_core.wb_data1;

    function automatic [31:0] dual_reg;
        input integer index;
        begin
            case (index)
                0:dual_reg=dR0; 1:dual_reg=dR1; 2:dual_reg=dR2; 3:dual_reg=dR3;
                4:dual_reg=dR4; 5:dual_reg=dR5; 6:dual_reg=dR6; 7:dual_reg=dR7;
                8:dual_reg=dR8; 9:dual_reg=dR9; 10:dual_reg=dR10; 11:dual_reg=dR11;
                12:dual_reg=dR12; 13:dual_reg=dR13; 14:dual_reg=dR14; 15:dual_reg=dR15;
                16:dual_reg=dR16; 17:dual_reg=dR17; 18:dual_reg=dR18; 19:dual_reg=dR19;
                20:dual_reg=dR20; 21:dual_reg=dR21; 22:dual_reg=dR22; 23:dual_reg=dR23;
                24:dual_reg=dR24; 25:dual_reg=dR25; 26:dual_reg=dR26; 27:dual_reg=dR27;
                28:dual_reg=dR28; 29:dual_reg=dR29; 30:dual_reg=dR30; 31:dual_reg=dR31;
                default: dual_reg=32'hxxxxxxxx;
            endcase
        end
    endfunction

    function automatic [31:0] single_reg;
        input integer index;
        begin
            case (index)
                0:single_reg=sR0; 1:single_reg=sR1; 2:single_reg=sR2; 3:single_reg=sR3;
                4:single_reg=sR4; 5:single_reg=sR5; 6:single_reg=sR6; 7:single_reg=sR7;
                8:single_reg=sR8; 9:single_reg=sR9; 10:single_reg=sR10; 11:single_reg=sR11;
                12:single_reg=sR12; 13:single_reg=sR13; 14:single_reg=sR14; 15:single_reg=sR15;
                16:single_reg=sR16; 17:single_reg=sR17; 18:single_reg=sR18; 19:single_reg=sR19;
                20:single_reg=sR20; 21:single_reg=sR21; 22:single_reg=sR22; 23:single_reg=sR23;
                24:single_reg=sR24; 25:single_reg=sR25; 26:single_reg=sR26; 27:single_reg=sR27;
                28:single_reg=sR28; 29:single_reg=sR29; 30:single_reg=sR30; 31:single_reg=sR31;
                default: single_reg=32'hxxxxxxxx;
            endcase
        end
    endfunction

    task step;
        begin @(posedge clk); #1; end
    endtask

    task fail;
        input [8*256-1:0] message;
        begin
            $display("[FAIL] %0s", message);
            errors = errors + 1;
        end
    endtask

    initial begin
        errors = 0;
        clk = 1'b0;
        reset = 1'b1;
        program_words = 0;
        max_cycles = 10000;
        mem_compare_words = DMEM_WORDS;
        benchmark_name = "unnamed";
        vcd_file = "out/benchmarks/benchmark.vcd";

        if (!$value$plusargs("PROGRAM=%s", program_file)) begin
            $display("ERROR: +PROGRAM=<hex file> is required");
            $fatal(1);
        end
        if (!$value$plusargs("PROGRAM_WORDS=%d", program_words) || program_words <= 0 || program_words > IMEM_WORDS) begin
            $display("ERROR: +PROGRAM_WORDS must be in 1..%0d", IMEM_WORDS);
            $fatal(1);
        end
        plusarg_ignored = $value$plusargs("BENCHMARK=%s", benchmark_name);
        plusarg_ignored = $value$plusargs("MAX_CYCLES=%d", max_cycles);
        plusarg_ignored = $value$plusargs("MEM_COMPARE_WORDS=%d", mem_compare_words);
        have_vcd = $value$plusargs("VCD=%s", vcd_file);
        have_dmem_init = $value$plusargs("DMEM_INIT=%s", dmem_file);
        have_expected_regs = $value$plusargs("EXPECT_REGS=%s", expected_regs_file);
        have_expected_dmem = $value$plusargs("EXPECT_DMEM=%s", expected_dmem_file);

        if (mem_compare_words < 0 || mem_compare_words > DMEM_WORDS)
            mem_compare_words = DMEM_WORDS;

        for (i = 0; i < IMEM_WORDS; i = i + 1)
            imem[i] = 32'b0;
        for (i = 0; i < DMEM_WORDS; i = i + 1) begin
            dmem_dual[i] = 32'b0;
            dmem_single[i] = 32'b0;
            expected_dmem[i] = 32'hxxxxxxxx;
        end
        for (i = 0; i < 32; i = i + 1)
            expected_regs[i] = 32'hxxxxxxxx;

        $readmemh(program_file, imem, 0, program_words - 1);
        if (have_dmem_init) begin
            $readmemh(dmem_file, dmem_dual);
            $readmemh(dmem_file, dmem_single);
        end
        if (have_expected_regs)
            $readmemh(expected_regs_file, expected_regs);
        if (have_expected_dmem)
            $readmemh(expected_dmem_file, expected_dmem);

        if (have_vcd) begin
            $dumpfile(vcd_file);
            $dumpvars(0, tb_benchmark);
        end

        repeat (2) step();
        reset = 1'b0;

        timeout_cycles = 0;
        while (!(halted_d && halted_s) && timeout_cycles < max_cycles) begin
            step();
            timeout_cycles = timeout_cycles + 1;
        end

        if (!halted_d)
            fail("dual core did not halt before timeout");
        if (!halted_s)
            fail("single core did not halt before timeout");

        for (i = 0; i < 32; i = i + 1) begin
            if (dual_reg(i) !== single_reg(i)) begin
                $display("[FAIL] architectural register mismatch R%0d dual=0x%08x single=0x%08x", i, dual_reg(i), single_reg(i));
                errors = errors + 1;
            end
            if ((^expected_regs[i] !== 1'bx) && dual_reg(i) !== expected_regs[i]) begin
                $display("[FAIL] expected register mismatch R%0d actual=0x%08x expected=0x%08x", i, dual_reg(i), expected_regs[i]);
                errors = errors + 1;
            end
        end

        for (i = 0; i < mem_compare_words; i = i + 1) begin
            if (dmem_dual[i] !== dmem_single[i]) begin
                $display("[FAIL] architectural memory mismatch M[%0d] dual=0x%08x single=0x%08x", i, dmem_dual[i], dmem_single[i]);
                errors = errors + 1;
            end
            if ((^expected_dmem[i] !== 1'bx) && dmem_dual[i] !== expected_dmem[i]) begin
                $display("[FAIL] expected memory mismatch M[%0d] actual=0x%08x expected=0x%08x", i, dmem_dual[i], expected_dmem[i]);
                errors = errors + 1;
            end
        end

        if (retired_d == 0 || retired_s == 0) begin
            fail("retired instruction count is zero");
            dual_ipc = 0.0;
            single_ipc = 0.0;
            dual_cpi = 0.0;
            single_cpi = 0.0;
        end else begin
            dual_ipc = $itor(retired_d) / $itor(cycles_d);
            single_ipc = $itor(retired_s) / $itor(cycles_s);
            dual_cpi = $itor(cycles_d) / $itor(retired_d);
            single_cpi = $itor(cycles_s) / $itor(retired_s);
        end

        if (cycles_d == 0) begin
            speedup = 0.0;
            improvement_pct = 0.0;
        end else begin
            speedup = $itor(cycles_s) / $itor(cycles_d);
            improvement_pct = 100.0 * ($itor(cycles_s) - $itor(cycles_d)) / $itor(cycles_s);
        end

        $display("\n--- Benchmark summary: %0s ---", benchmark_name);
        $display("dual:   cycles=%0d retired=%0d issued=%0d IPC=%0.6f CPI=%0.6f dual_issue_cycles=%0d dual_retire_cycles=%0d replays=%0d frontend_stalls=%0d load_stalls=%0d memory_conflicts=%0d redirects=%0d",
                 cycles_d, retired_d, issued_d, dual_ipc, dual_cpi, dual_issue_d, dual_retire_d,
                 replay_d, front_stall_d, load_stall_d, mem_conflict_d, redirect_d);
        $display("single: cycles=%0d retired=%0d issued=%0d IPC=%0.6f CPI=%0.6f replays=%0d frontend_stalls=%0d load_stalls=%0d memory_conflicts=%0d redirects=%0d",
                 cycles_s, retired_s, issued_s, single_ipc, single_cpi,
                 replay_s, front_stall_s, load_stall_s, mem_conflict_s, redirect_s);
        $display("speedup=%0.6f improvement_pct=%0.3f", speedup, improvement_pct);

        $display("BENCHMARK_RESULT name=%0s status=%0s program_words=%0d dual_cycles=%0d single_cycles=%0d dual_retired=%0d single_retired=%0d dual_issued=%0d single_issued=%0d dual_ipc=%0.6f single_ipc=%0.6f dual_cpi=%0.6f single_cpi=%0.6f speedup=%0.6f improvement_pct=%0.3f dual_issue_cycles=%0d dual_retire_cycles=%0d dual_replays=%0d single_replays=%0d dual_frontend_stalls=%0d single_frontend_stalls=%0d dual_load_stalls=%0d single_load_stalls=%0d dual_memory_conflicts=%0d single_memory_conflicts=%0d dual_redirects=%0d single_redirects=%0d",
                 benchmark_name, (errors == 0) ? "PASS" : "FAIL", program_words,
                 cycles_d, cycles_s, retired_d, retired_s, issued_d, issued_s,
                 dual_ipc, single_ipc, dual_cpi, single_cpi, speedup, improvement_pct,
                 dual_issue_d, dual_retire_d, replay_d, replay_s, front_stall_d, front_stall_s,
                 load_stall_d, load_stall_s, mem_conflict_d, mem_conflict_s, redirect_d, redirect_s);

        if (errors == 0) begin
            $display("BENCHMARK_PASS: %0s", benchmark_name);
        end else begin
            $display("BENCHMARK_FAIL: %0s errors=%0d", benchmark_name, errors);
            $fatal(1);
        end
        $finish;
    end
endmodule

`default_nettype wire
