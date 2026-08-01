`timescale 1ns/1ps
`default_nettype none
`include "supermips_defs.vh"

module tb_memory_backend;
    integer errors;
    integer stall_cycles;
    integer conflict_pulses;
    integer i;

    reg clk, reset;
    reg hold_de, hold_em, hold_mw;
    reg flush_de, flush_em, flush_mw;

    reg valid0, valid1;
    reg [31:0] pc0, pc1;
    reg [4:0] rs0, rt0, rs1, rt1;
    reg uses_rs0, uses_rt0, uses_rs1, uses_rt1;
    reg [31:0] src_a0, src_b0, imm0, src_a1, src_b1, imm1;
    reg alu_src0, alu_src1;
    reg [3:0] alu_op0, alu_op1;
    reg writes0, writes1;
    reg [4:0] dest0, dest1;
    reg mem_read0, mem_write0, mem_read1, mem_write1;
    reg [1:0] wb_sel0, wb_sel1;
    reg branch0, branch1;
    reg [31:0] branch_target0, branch_target1;

    reg [31:0] dmem [0:255];
    integer write_count [0:255];

    wire [31:0] mem_read_data;
    wire mem_req_valid, mem_req_write;
    wire [31:0] mem_word_addr, mem_write_data;
    wire mem_grant0, mem_grant1;
    wire memory_conflict, memory_conflict_active, memory_busy;
    wire memory_alignment_error;

    wire input_ready, load_use_stall, stall_lane0, stall_lane1;
    wire [7:0] load_hazard_mask;
    wire [3:0] forwarding_wait_mask;
    wire [2:0] fwd_a_sel0, fwd_b_sel0, fwd_a_sel1, fwd_b_sel1;
    wire [31:0] fwd_a_data0, fwd_b_data0, fwd_a_data1, fwd_b_data1;
    wire em_valid0, em_valid1;
    wire [31:0] em_result0, em_result1, em_store0, em_store1;
    wire em_mem_read0, em_mem_read1, em_mem_write0, em_mem_write1;
    wire wb_valid0, wb_valid1, wb_we0, wb_we1;
    wire [4:0] wb_dest0, wb_dest1;
    wire [31:0] wb_data0, wb_data1;
    wire wb_collision;

    assign mem_read_data = dmem[mem_word_addr[7:0]];

    always #5 clk = ~clk;

    always @(posedge clk) begin
        if (!reset && mem_req_valid && mem_req_write) begin
            dmem[mem_word_addr[7:0]] <= mem_write_data;
            write_count[mem_word_addr[7:0]] = write_count[mem_word_addr[7:0]] + 1;
        end
        if (!reset && load_use_stall)
            stall_cycles = stall_cycles + 1;
        if (!reset && memory_conflict)
            conflict_pulses = conflict_pulses + 1;
    end

    dual_memory_backend dut (
        .clk(clk), .reset(reset),
        .hold_de(hold_de), .hold_em(hold_em), .hold_mw(hold_mw),
        .flush_de(flush_de), .flush_em(flush_em), .flush_mw(flush_mw),

        .in_valid0(valid0), .in_pc0(pc0), .in_rs0(rs0), .in_rt0(rt0),
        .in_uses_rs0(uses_rs0), .in_uses_rt0(uses_rt0),
        .in_src_a0(src_a0), .in_src_b0(src_b0), .in_imm0(imm0),
        .in_alu_src_imm0(alu_src0), .in_alu_op0(alu_op0),
        .in_writes_reg0(writes0), .in_dest_reg0(dest0),
        .in_mem_read0(mem_read0), .in_mem_write0(mem_write0),
        .in_wb_sel0(wb_sel0), .in_is_branch0(branch0),
        .in_branch_target0(branch_target0),

        .in_valid1(valid1), .in_pc1(pc1), .in_rs1(rs1), .in_rt1(rt1),
        .in_uses_rs1(uses_rs1), .in_uses_rt1(uses_rt1),
        .in_src_a1(src_a1), .in_src_b1(src_b1), .in_imm1(imm1),
        .in_alu_src_imm1(alu_src1), .in_alu_op1(alu_op1),
        .in_writes_reg1(writes1), .in_dest_reg1(dest1),
        .in_mem_read1(mem_read1), .in_mem_write1(mem_write1),
        .in_wb_sel1(wb_sel1), .in_is_branch1(branch1),
        .in_branch_target1(branch_target1),

        .mem_read_data(mem_read_data),
        .mem_req_valid(mem_req_valid), .mem_req_write(mem_req_write),
        .mem_word_addr(mem_word_addr), .mem_write_data(mem_write_data),
        .mem_grant0(mem_grant0), .mem_grant1(mem_grant1),
        .memory_conflict(memory_conflict),
        .memory_conflict_active(memory_conflict_active),
        .memory_busy(memory_busy),
        .memory_alignment_error(memory_alignment_error),

        .input_ready(input_ready), .load_use_stall(load_use_stall),
        .stall_lane0(stall_lane0), .stall_lane1(stall_lane1),
        .load_hazard_mask(load_hazard_mask),
        .forwarding_wait_mask(forwarding_wait_mask),
        .fwd_a_sel0(fwd_a_sel0), .fwd_b_sel0(fwd_b_sel0),
        .fwd_a_sel1(fwd_a_sel1), .fwd_b_sel1(fwd_b_sel1),
        .fwd_a_data0(fwd_a_data0), .fwd_b_data0(fwd_b_data0),
        .fwd_a_data1(fwd_a_data1), .fwd_b_data1(fwd_b_data1),

        .em_valid0(em_valid0), .em_alu_result0(em_result0),
        .em_store_data0(em_store0), .em_mem_read0(em_mem_read0),
        .em_mem_write0(em_mem_write0),
        .em_valid1(em_valid1), .em_alu_result1(em_result1),
        .em_store_data1(em_store1), .em_mem_read1(em_mem_read1),
        .em_mem_write1(em_mem_write1),

        .wb_valid0(wb_valid0), .wb_we0(wb_we0),
        .wb_dest0(wb_dest0), .wb_data0(wb_data0),
        .wb_valid1(wb_valid1), .wb_we1(wb_we1),
        .wb_dest1(wb_dest1), .wb_data1(wb_data1),
        .wb_collision(wb_collision)
    );

    task step;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    task clear_inputs;
        begin
            valid0=0; valid1=0; pc0=0; pc1=0;
            rs0=0; rt0=0; rs1=0; rt1=0;
            uses_rs0=0; uses_rt0=0; uses_rs1=0; uses_rt1=0;
            src_a0=0; src_b0=0; imm0=0;
            src_a1=0; src_b1=0; imm1=0;
            alu_src0=0; alu_src1=0;
            alu_op0=`ALU_ADD; alu_op1=`ALU_ADD;
            writes0=0; writes1=0; dest0=0; dest1=0;
            mem_read0=0; mem_write0=0; mem_read1=0; mem_write1=0;
            wb_sel0=`WB_ALU; wb_sel1=`WB_ALU;
            branch0=0; branch1=0;
            branch_target0=0; branch_target1=0;
        end
    endtask

    task reset_dut;
        begin
            clear_inputs();
            hold_de=0; hold_em=0; hold_mw=0;
            flush_de=0; flush_em=0; flush_mw=0;
            reset=1;
            step();
            reset=0;
            step();
            stall_cycles=0;
            conflict_pulses=0;
        end
    endtask

    task clear_memory;
        begin
            for (i=0; i<256; i=i+1) begin
                dmem[i]=0;
                write_count[i]=0;
            end
        end
    endtask

    task expect_bit;
        input [511:0] name;
        input actual, expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s actual=%b expected=%b", name, actual, expected);
                errors=errors+1;
            end else $display("[PASS] %0s", name);
        end
    endtask

    task expect_32;
        input [511:0] name;
        input [31:0] actual, expected;
        begin
            if (actual !== expected) begin
                $display("[FAIL] %0s actual=0x%08x expected=0x%08x", name, actual, expected);
                errors=errors+1;
            end else $display("[PASS] %0s = 0x%08x", name, actual);
        end
    endtask

    initial begin
        errors=0; clk=0; reset=0;
        hold_de=0; hold_em=0; hold_mw=0;
        flush_de=0; flush_em=0; flush_mw=0;
        clear_inputs();
        clear_memory();

        $display("\n--- Shared-memory backend integration tests ---");

        // ------------------------------------------------------------------
        // A real load and an independent ALU instruction share the cycle.
        // ------------------------------------------------------------------
        reset_dut();
        dmem[5]=32'd99;
        valid0=1; pc0=32'h100; rs0=0; uses_rs0=1;
        imm0=32'd20; alu_src0=1; alu_op0=`ALU_ADD;
        writes0=1; dest0=10; mem_read0=1; wb_sel0=`WB_MEM;
        valid1=1; pc1=32'h104; imm1=32'd3; alu_src1=1;
        writes1=1; dest1=11; wb_sel1=`WB_ALU;
        step();
        clear_inputs();
        step();
        expect_bit("Load owns shared port", mem_grant0, 1);
        expect_bit("ALU lane needs no memory grant", mem_grant1, 0);
        expect_bit("Load raises RAM request", mem_req_valid, 1);
        expect_bit("Load request is a read", mem_req_write, 0);
        expect_32("Load word address", mem_word_addr, 5);
        expect_32("Memory supplies load data", mem_read_data, 99);
        step();
        expect_bit("Load writes back", wb_we0, 1);
        expect_32("Load returns real RAM value", wb_data0, 99);
        expect_bit("Companion ALU writes back", wb_we1, 1);
        expect_32("Companion ALU result", wb_data1, 3);

        // ------------------------------------------------------------------
        // Store data is forwarded from the previous bundle across lanes.
        // ------------------------------------------------------------------
        reset_dut();
        clear_memory();
        valid0=1; imm0=32'd42; alu_src0=1; writes0=1; dest0=13;
        step();
        valid0=1; imm0=32'd1; alu_src0=1; writes0=1; dest0=14;
        valid1=1; rs1=0; rt1=13; uses_rs1=1; uses_rt1=1;
        src_a1=0; src_b1=0; imm1=32'd16; alu_src1=1;
        mem_write1=1; writes1=0;
        step();
        expect_32("Store rt forwards producer value", fwd_b_data1, 42);
        clear_inputs();
        step();
        expect_bit("Lane1 store owns shared port", mem_grant1, 1);
        expect_bit("Store request writes", mem_req_write, 1);
        expect_32("Forwarded store word address", mem_word_addr, 4);
        expect_32("Forwarded store payload", mem_write_data, 42);
        step();
        expect_32("Store updates RAM", dmem[4], 42);
        expect_32("Store executes exactly once", write_count[4], 1);
        expect_bit("Independent ALU companion still commits", wb_we0, 1);
        expect_32("ALU companion data", wb_data0, 1);

        // ------------------------------------------------------------------
        // Load-use uses the real RAM value after exactly one bubble.
        // ------------------------------------------------------------------
        reset_dut();
        clear_memory();
        dmem[7]=32'd123;
        valid0=1; rs0=0; uses_rs0=1; imm0=32'd28; alu_src0=1;
        writes0=1; dest0=20; mem_read0=1; wb_sel0=`WB_MEM;
        step();
        valid0=1; rs0=20; uses_rs0=1; src_a0=0; src_b0=1;
        alu_src0=0; writes0=1; dest0=21;
        valid1=1; imm1=2; alu_src1=1; writes1=1; dest1=22;
        step();
        expect_bit("Real-memory load-use stalls", load_use_stall, 1);
        expect_bit("Load-use blocks new input", input_ready, 0);
        expect_bit("Load-use marks consuming lane", stall_lane0, 1);
        clear_inputs();
        step();
        expect_bit("Load reaches WB after memory cycle", wb_we0, 1);
        expect_32("Load WB contains RAM value", wb_data0, 123);
        expect_bit("Load-use stall clears", load_use_stall, 0);
        expect_32("Consumer receives load through MW forwarding", fwd_a_data0, 123);
        step();
        expect_32("Consumer executes with loaded value", em_result0, 124);
        expect_32("Held companion executes once", em_result1, 2);
        expect_32("Exactly one load-use stall", stall_cycles, 1);

        // ------------------------------------------------------------------
        // A held consumer must retain another transient forwarded operand.
        // This is the integrated-core R8 regression: r6(load) + r5(M/W).
        // ------------------------------------------------------------------
        reset_dut();
        clear_memory();
        dmem[8]=32'd12;

        // Older lane1 producer: r5 = 1.
        valid1=1; imm1=32'd1; alu_src1=1; writes1=1; dest1=5;
        step();

        // Following bundle: load r6 and an independent companion.
        clear_inputs();
        valid0=1; rs0=0; uses_rs0=1; imm0=32'd32; alu_src0=1;
        writes0=1; dest0=6; mem_read0=1; wb_sel0=`WB_MEM;
        valid1=1; imm1=32'd2; alu_src1=1; writes1=1; dest1=7;
        step();

        // Consumer needs the load and the older value currently reaching M/W.
        clear_inputs();
        valid0=1; rs0=6; rt0=5; uses_rs0=1; uses_rt0=1;
        src_a0=0; src_b0=0; alu_src0=0; alu_op0=`ALU_ADD;
        writes0=1; dest0=8;
        valid1=1; imm1=32'd9; alu_src1=1; writes1=1; dest1=9;
        step();
        expect_bit("Two-source load-use stalls", load_use_stall, 1);
        expect_32("Transient second operand is visible before hold", fwd_b_data0, 1);

        clear_inputs();
        step();
        expect_bit("Two-source load-use clears", load_use_stall, 0);
        expect_32("Held second operand survives producer exit", fwd_b_data0, 1);
        expect_32("Held second operand keeps source selection", fwd_b_sel0, 2);
        expect_32("Loaded first operand reaches consumer", fwd_a_data0, 12);
        step();
        expect_32("Two-source held consumer result", em_result0, 13);
        expect_32("Two-source held companion executes once", em_result1, 9);
        expect_32("Two-source case stalls once", stall_cycles, 1);

        // ------------------------------------------------------------------
        // Defensive conflict: two stores are serialized lane0 then lane1.
        // ------------------------------------------------------------------
        reset_dut();
        clear_memory();
        valid0=1; rs0=0; rt0=1; uses_rs0=1; uses_rt0=1;
        src_a0=0; src_b0=32'h1111_1111; imm0=32'd32; alu_src0=1;
        mem_write0=1;
        valid1=1; rs1=0; rt1=2; uses_rs1=1; uses_rt1=1;
        src_a1=0; src_b1=32'h2222_2222; imm1=32'd36; alu_src1=1;
        mem_write1=1;
        step();
        clear_inputs();
        step();
        expect_bit("Two E/M memory ops raise conflict", memory_conflict, 1);
        expect_bit("Conflict first grants lane0", mem_grant0, 1);
        expect_bit("Conflict first blocks lane1", mem_grant1, 0);
        expect_bit("Conflict holds backend input", input_ready, 0);
        expect_32("First store address", mem_word_addr, 8);
        step();
        expect_bit("Conflict enters second phase", memory_conflict_active, 1);
        expect_bit("Second phase grants lane1", mem_grant1, 1);
        expect_32("Second store address", mem_word_addr, 9);
        expect_32("First store committed once", write_count[8], 1);
        step();
        expect_bit("Conflict clears after lane1", memory_conflict_active, 0);
        expect_32("First serialized store data", dmem[8], 32'h1111_1111);
        expect_32("Second serialized store data", dmem[9], 32'h2222_2222);
        expect_32("First store count", write_count[8], 1);
        expect_32("Second store count", write_count[9], 1);
        expect_32("Exactly one conflict pulse", conflict_pulses, 1);
        step();
        expect_32("No duplicate first store", write_count[8], 1);
        expect_32("No duplicate second store", write_count[9], 1);

        // ------------------------------------------------------------------
        // Defensive conflict also preserves both load return values.
        // ------------------------------------------------------------------
        reset_dut();
        clear_memory();
        dmem[12]=32'd111;
        dmem[13]=32'd222;
        valid0=1; rs0=0; uses_rs0=1; imm0=32'd48; alu_src0=1;
        writes0=1; dest0=23; mem_read0=1; wb_sel0=`WB_MEM;
        valid1=1; rs1=0; uses_rs1=1; imm1=32'd52; alu_src1=1;
        writes1=1; dest1=24; mem_read1=1; wb_sel1=`WB_MEM;
        step(); clear_inputs(); step();
        expect_bit("Dual loads start conflict", memory_conflict, 1);
        expect_32("First load sees lane0 RAM word", mem_read_data, 111);
        step();
        expect_bit("Dual loads service lane1 second", mem_grant1, 1);
        expect_32("Second load sees lane1 RAM word", mem_read_data, 222);
        step();
        expect_bit("Serialized lane0 load writes back", wb_we0, 1);
        expect_bit("Serialized lane1 load writes back", wb_we1, 1);
        expect_32("Serialized lane0 load data", wb_data0, 111);
        expect_32("Serialized lane1 load data", wb_data1, 222);

        // ------------------------------------------------------------------
        // External E/M hold must suppress repeated store side effects.
        // ------------------------------------------------------------------
        reset_dut();
        clear_memory();
        valid0=1; src_a0=0; src_b0=32'hABCD_1234;
        imm0=32'd60; alu_src0=1; mem_write0=1;
        step(); clear_inputs(); step();
        hold_em=1;
        #1;
        expect_bit("Held E/M suppresses RAM request", mem_req_valid, 0);
        step(); step();
        expect_32("Held store has no side effect", write_count[15], 0);
        hold_em=0; #1;
        expect_bit("Released E/M re-enables store", mem_req_valid, 1);
        step();
        expect_32("Released store commits once", dmem[15], 32'hABCD_1234);
        expect_32("Released store count", write_count[15], 1);
        step();
        expect_32("Released store is not duplicated", write_count[15], 1);

        // ------------------------------------------------------------------
        // Flushing E/M before the memory edge prevents a wrong-path store.
        // ------------------------------------------------------------------
        reset_dut();
        clear_memory();
        valid0=1; src_a0=0; src_b0=32'hDEAD_BEEF;
        imm0=32'd64; alu_src0=1; mem_write0=1;
        step(); clear_inputs(); step();
        flush_em=1; #1;
        expect_bit("E/M flush suppresses RAM request", mem_req_valid, 0);
        step();
        flush_em=0;
        step();
        expect_32("Flushed store never reaches RAM", write_count[16], 0);

        expect_bit("No unexpected WB collision", wb_collision, 0);
        expect_bit("All tested addresses were aligned", memory_alignment_error, 0);

        if (errors == 0)
            $display("\nMEMORY_BACKEND_TESTS_PASS");
        else begin
            $display("\nMEMORY_BACKEND_TESTS_FAIL: %0d error(s)", errors);
            $fatal(1);
        end
        $finish;
    end
endmodule

`default_nettype wire
