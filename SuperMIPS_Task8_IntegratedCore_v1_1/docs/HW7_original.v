module main (
    input wire        Clk,        
    input wire        Rst,        
    input wire [31:0] InstrIn,    
    input wire [31:0] DataIn,     

    output wire [31:0] R0,  R1,  R2,  R3,  R4,  R5,  R6,  R7,
    output wire [31:0] R8,  R9,  R10, R11, R12, R13, R14, R15,
    output wire [31:0] R16, R17, R18, R19, R20, R21, R22, R23,
    output wire [31:0] R24, R25, R26, R27, R28, R29, R30, R31,

    output wire [31:0] InstrAddr,
    output wire [31:0] DataAddr, 
    output wire        DataWrite,
    output wire [31:0] DataOut,   

    output wire [31:0] D_PC, D_Instr, D_Rs, D_Rt, 
    output wire        D_Valid, D_RsValid, D_RtValid, D_ImmValid, D_AddressValid,
    output wire [15:0] D_Imm,
    output wire [25:0] D_Address,

    output wire [31:0] E_PC, E_Instr, E_Res,
    output wire        E_Valid, E_ResValid,

    output wire [31:0] W_PC, W_Instr,
    output wire        W_Valid
);

    // Register File Array
    reg [31:0] RF[31:1];
    integer k;


    reg [31:0] reg_F2D_pc, reg_F2D_inst;
    reg        reg_F2D_vld;

    reg [31:0] reg_D2E_pc, reg_D2E_inst, reg_D2E_src1, reg_D2E_src2, reg_D2E_imm32;
    reg [4:0]  reg_D2E_rs, reg_D2E_rt, reg_D2E_dst;
    reg        reg_D2E_vld, reg_D2E_wr_en, reg_D2E_mem_rd, reg_D2E_mem_wr, reg_D2E_br, reg_D2E_alu_src;
    reg [1:0]  reg_D2E_wb_sel;
    reg [3:0]  reg_D2E_alu_op;

    reg [31:0] reg_E2M_pc, reg_E2M_inst, reg_E2M_alu, reg_E2M_wdata;
    reg [4:0]  reg_E2M_dst;
    reg        reg_E2M_vld, reg_E2M_wr_en, reg_E2M_mem_rd, reg_E2M_mem_wr;
    reg [1:0]  reg_E2M_wb_sel;

    reg [31:0] reg_M2W_pc, reg_M2W_inst, reg_M2W_alu, reg_M2W_mem;
    reg [4:0]  reg_M2W_dst;
    reg        reg_M2W_vld, reg_M2W_wr_en;
    reg [1:0]  reg_M2W_wb_sel;


    wire [5:0] opc = reg_F2D_inst[31:26];
    wire [4:0] f_rs = reg_F2D_inst[25:21];
    wire [4:0] f_rt = reg_F2D_inst[20:16];
    wire [4:0] f_rd = reg_F2D_inst[15:11];
    wire [5:0] fnc = reg_F2D_inst[5:0];

    wire d_is_r    = (opc == 6'b000000);
    wire d_is_addi = (opc == 6'b001000);
    wire d_is_subi = (opc == 6'b001001);
    wire d_is_lui  = (opc == 6'b001111);
    wire d_is_lw   = (opc == 6'b100011);
    wire d_is_sw   = (opc == 6'b101011);
    wire d_is_beq  = (opc == 6'b000100);
    wire d_is_j    = (opc == 6'b000010);
    wire d_is_jal  = (opc == 6'b000011);
    wire d_is_jr   = (d_is_r && fnc == 6'b001000);


    reg [31:0] curr_pc;
    assign InstrAddr = curr_pc >> 2;
    wire hold_pipe;
    wire do_branch_exec;
    wire [31:0] wb_final_val;
    wire [31:0] d_val_rs;


    wire flush_fetch = do_branch_exec || ((d_is_j || d_is_jal || d_is_jr) && !hold_pipe && reg_F2D_vld);

    always @(posedge Clk or posedge Rst) begin
        if (Rst) curr_pc <= 0;
        else if (do_branch_exec) curr_pc <= reg_D2E_pc + 4 + (reg_D2E_imm32 << 2);
        else if (!hold_pipe && (d_is_j || d_is_jal || d_is_jr) && reg_F2D_vld)
            curr_pc <= d_is_jr ? d_val_rs : {reg_F2D_pc[31:28], reg_F2D_inst[25:0], 2'b00};
        else if (!hold_pipe) curr_pc <= curr_pc + 4;
    end


    reg [4:0] ctrl_dst;
    reg ctrl_we, ctrl_alu_src, ctrl_mr, ctrl_mw, ctrl_br;
    reg [1:0] ctrl_wbsel;
    reg [3:0] ctrl_alu_op;

    always @(*) begin
        ctrl_dst = 0; ctrl_we = 0; ctrl_alu_src = 0; ctrl_wbsel = 0;
        ctrl_mr = 0; ctrl_mw = 0; ctrl_br = 0; ctrl_alu_op = 0;
        if (reg_F2D_vld) begin
            case (opc)
                6'b000000: begin
                    ctrl_dst = f_rd;
                    if (!d_is_jr) begin
                        ctrl_we = 1;
                        case (fnc)
                            6'b100000: ctrl_alu_op = 4'b0000;
                            6'b100010: ctrl_alu_op = 4'b0001;
                            6'b011000: ctrl_alu_op = 4'b0100;
                            6'b011010: ctrl_alu_op = 4'b0110;
                        endcase
                    end
                end
                6'b100011: begin ctrl_dst = f_rt; ctrl_we = 1; ctrl_alu_src = 1; ctrl_wbsel = 2'b01; ctrl_mr = 1; end
                6'b101011: begin ctrl_alu_src = 1; ctrl_mw = 1; end
                6'b001000: begin ctrl_dst = f_rt; ctrl_we = 1; ctrl_alu_src = 1; end
                6'b001001: begin ctrl_dst = f_rt; ctrl_we = 1; ctrl_alu_src = 1; ctrl_alu_op = 4'b0001; end
                6'b001111: begin ctrl_dst = f_rt; ctrl_we = 1; ctrl_alu_src = 1; ctrl_alu_op = 4'b0111; end
                6'b000100: begin ctrl_br = 1; ctrl_alu_op = 4'b0001; end
                6'b000011: begin ctrl_dst = 5'd31; ctrl_we = 1; ctrl_wbsel = 2'b10; end
            endcase
        end
    end

    hz_unit u_hazard (
        .is_jr(d_is_jr), .rs_D(f_rs), .rt_D(f_rt),
        .dest_E(reg_D2E_dst), .dest_M(reg_E2M_dst),
        .mem_read_E(reg_D2E_mem_rd), .reg_wr_E(reg_D2E_wr_en), .reg_wr_M(reg_E2M_wr_en),
        .stall_out(hold_pipe)
    );

    assign d_val_rs = (f_rs != 0 && f_rs == reg_M2W_dst && reg_M2W_wr_en) ? wb_final_val : (f_rs == 0 ? 0 : RF[f_rs]);
    wire [31:0] d_val_rt = (f_rt != 0 && f_rt == reg_M2W_dst && reg_M2W_wr_en) ? wb_final_val : (f_rt == 0 ? 0 : RF[f_rt]);
    wire [31:0] d_imm_ext = {{16{reg_F2D_inst[15]}}, reg_F2D_inst[15:0]};


    assign D_PC = reg_F2D_pc >> 2;
    assign D_Instr = reg_F2D_inst;
    assign D_Valid = reg_F2D_vld;
    assign D_Rs = d_val_rs;
    assign D_Rt = d_val_rt;
    assign D_Imm = reg_F2D_inst[15:0];
    assign D_Address = reg_F2D_inst[25:0];
    assign D_RsValid = reg_F2D_vld && ((d_is_r && !d_is_jr && (fnc == 6'b100000 || fnc == 6'b100010 || fnc == 6'b011000 || fnc == 6'b011010)) || d_is_jr || d_is_addi || d_is_subi || d_is_lw || d_is_sw || d_is_beq);
    assign D_RtValid = reg_F2D_vld && ((d_is_r && !d_is_jr && (fnc == 6'b100000 || fnc == 6'b100010 || fnc == 6'b011000 || fnc == 6'b011010)) || d_is_sw || d_is_beq);
    assign D_ImmValid = reg_F2D_vld && (d_is_addi || d_is_subi || d_is_lui || d_is_lw || d_is_sw || d_is_beq);
    assign D_AddressValid = reg_F2D_vld && (d_is_j || d_is_jal);


    wire [1:0] sel_fwdA, sel_fwdB;
    

    fw_unit u_forwarding (
        .rs_E(reg_D2E_rs), .rt_E(reg_D2E_rt),
        .dst_M(reg_E2M_dst), .dst_W(reg_M2W_dst),
        .we_M(reg_E2M_wr_en), .we_W(reg_M2W_wr_en),
        .fwd_a(sel_fwdA), .fwd_b(sel_fwdB)
    );

    wire [31:0] alu_in1 = (sel_fwdA == 2'b10) ? reg_E2M_alu : (sel_fwdA == 2'b01) ? wb_final_val : reg_D2E_src1;
    wire [31:0] bypass_rt = (sel_fwdB == 2'b10) ? reg_E2M_alu : (sel_fwdB == 2'b01) ? wb_final_val : reg_D2E_src2;
    wire [31:0] alu_in2 = reg_D2E_alu_src ? reg_D2E_imm32 : bypass_rt;

    wire [31:0] calc_res;
    wire flag_z;
    alu_core math_unit (.a(alu_in1), .b(alu_in2), .op(reg_D2E_alu_op), .res(calc_res), .zero(flag_z));

    assign do_branch_exec = reg_D2E_vld && reg_D2E_br && (alu_in1 == bypass_rt);

    assign E_PC = reg_D2E_pc >> 2;
    assign E_Instr = reg_D2E_inst;
    assign E_Valid = reg_D2E_vld;
    assign E_Res = calc_res;
    assign E_ResValid = reg_D2E_vld && reg_D2E_wr_en && !reg_D2E_mem_rd;


    assign DataAddr = (reg_E2M_mem_rd || reg_E2M_mem_wr) ? (reg_E2M_alu >> 2) : 32'h00004000;
    assign DataWrite = reg_E2M_mem_wr;
    assign DataOut = reg_E2M_wdata;


    assign wb_final_val = (reg_M2W_wb_sel == 2'b00) ? reg_M2W_alu :
                          (reg_M2W_wb_sel == 2'b01) ? reg_M2W_mem :
                          (reg_M2W_pc + 4); 

    assign W_PC = reg_M2W_pc >> 2;
    assign W_Instr = reg_M2W_inst;
    assign W_Valid = reg_M2W_vld;


    assign R0 = 0;
    assign R1  = (reg_M2W_wr_en && reg_M2W_dst == 1)  ? wb_final_val : RF[1];
    assign R2  = (reg_M2W_wr_en && reg_M2W_dst == 2)  ? wb_final_val : RF[2];
    assign R3  = (reg_M2W_wr_en && reg_M2W_dst == 3)  ? wb_final_val : RF[3];
    assign R4  = (reg_M2W_wr_en && reg_M2W_dst == 4)  ? wb_final_val : RF[4];
    assign R5  = (reg_M2W_wr_en && reg_M2W_dst == 5)  ? wb_final_val : RF[5];
    assign R6  = (reg_M2W_wr_en && reg_M2W_dst == 6)  ? wb_final_val : RF[6];
    assign R7  = (reg_M2W_wr_en && reg_M2W_dst == 7)  ? wb_final_val : RF[7];
    assign R8  = (reg_M2W_wr_en && reg_M2W_dst == 8)  ? wb_final_val : RF[8];
    assign R9  = (reg_M2W_wr_en && reg_M2W_dst == 9)  ? wb_final_val : RF[9];
    assign R10 = (reg_M2W_wr_en && reg_M2W_dst == 10) ? wb_final_val : RF[10];
    assign R11 = (reg_M2W_wr_en && reg_M2W_dst == 11) ? wb_final_val : RF[11];
    assign R12 = (reg_M2W_wr_en && reg_M2W_dst == 12) ? wb_final_val : RF[12];
    assign R13 = (reg_M2W_wr_en && reg_M2W_dst == 13) ? wb_final_val : RF[13];
    assign R14 = (reg_M2W_wr_en && reg_M2W_dst == 14) ? wb_final_val : RF[14];
    assign R15 = (reg_M2W_wr_en && reg_M2W_dst == 15) ? wb_final_val : RF[15];
    assign R16 = (reg_M2W_wr_en && reg_M2W_dst == 16) ? wb_final_val : RF[16];
    assign R17 = (reg_M2W_wr_en && reg_M2W_dst == 17) ? wb_final_val : RF[17];
    assign R18 = (reg_M2W_wr_en && reg_M2W_dst == 18) ? wb_final_val : RF[18];
    assign R19 = (reg_M2W_wr_en && reg_M2W_dst == 19) ? wb_final_val : RF[19];
    assign R20 = (reg_M2W_wr_en && reg_M2W_dst == 20) ? wb_final_val : RF[20];
    assign R21 = (reg_M2W_wr_en && reg_M2W_dst == 21) ? wb_final_val : RF[21];
    assign R22 = (reg_M2W_wr_en && reg_M2W_dst == 22) ? wb_final_val : RF[22];
    assign R23 = (reg_M2W_wr_en && reg_M2W_dst == 23) ? wb_final_val : RF[23];
    assign R24 = (reg_M2W_wr_en && reg_M2W_dst == 24) ? wb_final_val : RF[24];
    assign R25 = (reg_M2W_wr_en && reg_M2W_dst == 25) ? wb_final_val : RF[25];
    assign R26 = (reg_M2W_wr_en && reg_M2W_dst == 26) ? wb_final_val : RF[26];
    assign R27 = (reg_M2W_wr_en && reg_M2W_dst == 27) ? wb_final_val : RF[27];
    assign R28 = (reg_M2W_wr_en && reg_M2W_dst == 28) ? wb_final_val : RF[28];
    assign R29 = (reg_M2W_wr_en && reg_M2W_dst == 29) ? wb_final_val : RF[29];
    assign R30 = (reg_M2W_wr_en && reg_M2W_dst == 30) ? wb_final_val : RF[30];
    assign R31 = (reg_M2W_wr_en && reg_M2W_dst == 31) ? wb_final_val : RF[31];


    always @(posedge Clk or posedge Rst) begin
        if (Rst) begin
            reg_F2D_pc <= 0; reg_F2D_inst <= 0; reg_F2D_vld <= 0;
            reg_D2E_pc <= 0; reg_D2E_inst <= 0; reg_D2E_vld <= 0;
            reg_D2E_src1 <= 0; reg_D2E_src2 <= 0; reg_D2E_imm32 <= 0;
            reg_D2E_rs <= 0; reg_D2E_rt <= 0; reg_D2E_dst <= 0;
            reg_D2E_wr_en <= 0; reg_D2E_mem_rd <= 0; reg_D2E_mem_wr <= 0; reg_D2E_br <= 0; reg_D2E_alu_src <= 0;
            reg_D2E_wb_sel <= 0; reg_D2E_alu_op <= 0;
            reg_E2M_pc <= 0; reg_E2M_inst <= 0; reg_E2M_vld <= 0;
            reg_E2M_alu <= 0; reg_E2M_wdata <= 0; reg_E2M_dst <= 0;
            reg_E2M_wr_en <= 0; reg_E2M_mem_rd <= 0; reg_E2M_mem_wr <= 0; reg_E2M_wb_sel <= 0;
            reg_M2W_pc <= 0; reg_M2W_inst <= 0; reg_M2W_vld <= 0;
            reg_M2W_alu <= 0; reg_M2W_mem <= 0; reg_M2W_dst <= 0;
            reg_M2W_wr_en <= 0; reg_M2W_wb_sel <= 0;
            for (k=1; k<=31; k=k+1) RF[k] <= 0;
        end else begin
            // F -> D
            if (do_branch_exec || flush_fetch) reg_F2D_vld <= 0;
            else if (!hold_pipe) begin reg_F2D_pc <= curr_pc; reg_F2D_inst <= InstrIn; reg_F2D_vld <= 1; end

            // D -> E
            if (do_branch_exec || hold_pipe) begin
                reg_D2E_vld <= 0; reg_D2E_wr_en <= 0; reg_D2E_mem_rd <= 0; reg_D2E_mem_wr <= 0; reg_D2E_br <= 0;
            end else begin
                reg_D2E_pc <= reg_F2D_pc; reg_D2E_inst <= reg_F2D_inst; reg_D2E_vld <= reg_F2D_vld;
                reg_D2E_src1 <= d_val_rs; reg_D2E_src2 <= d_val_rt; reg_D2E_imm32 <= d_imm_ext;
                reg_D2E_rs <= f_rs; reg_D2E_rt <= f_rt; reg_D2E_dst <= ctrl_dst;
                reg_D2E_alu_op <= ctrl_alu_op; reg_D2E_alu_src <= ctrl_alu_src; reg_D2E_wb_sel <= ctrl_wbsel;
                reg_D2E_wr_en <= reg_F2D_vld ? ctrl_we : 0;
                reg_D2E_mem_rd <= reg_F2D_vld ? ctrl_mr : 0;
                reg_D2E_mem_wr <= reg_F2D_vld ? ctrl_mw : 0;
                reg_D2E_br <= reg_F2D_vld ? ctrl_br : 0;
            end

            // E -> M
            reg_E2M_pc <= reg_D2E_pc; reg_E2M_inst <= reg_D2E_inst; reg_E2M_vld <= reg_D2E_vld;
            reg_E2M_alu <= calc_res; reg_E2M_wdata <= bypass_rt; reg_E2M_dst <= reg_D2E_dst;
            reg_E2M_wr_en <= reg_D2E_vld ? reg_D2E_wr_en : 0;
            reg_E2M_mem_rd <= reg_D2E_vld ? reg_D2E_mem_rd : 0;
            reg_E2M_mem_wr <= reg_D2E_vld ? reg_D2E_mem_wr : 0;
            reg_E2M_wb_sel <= reg_D2E_wb_sel;

            // M -> W
            reg_M2W_pc <= reg_E2M_pc; reg_M2W_inst <= reg_E2M_inst; reg_M2W_vld <= reg_E2M_vld;
            reg_M2W_alu <= reg_E2M_alu; reg_M2W_mem <= DataIn; reg_M2W_dst <= reg_E2M_dst;
            reg_M2W_wr_en <= reg_E2M_vld ? reg_E2M_wr_en : 0;
            reg_M2W_wb_sel <= reg_E2M_wb_sel;

            // RF Write
            if (reg_M2W_wr_en && reg_M2W_dst != 0) RF[reg_M2W_dst] <= wb_final_val;
        end
    end
endmodule


module fw_unit (
    input [4:0] rs_E, rt_E,
    input [4:0] dst_M, dst_W,
    input we_M, we_W,
    output [1:0] fwd_a, fwd_b
);
    assign fwd_a = (we_M && dst_M != 0 && dst_M == rs_E) ? 2'b10 :
                   (we_W && dst_W != 0 && dst_W == rs_E) ? 2'b01 : 2'b00;
                   
    assign fwd_b = (we_M && dst_M != 0 && dst_M == rt_E) ? 2'b10 :
                   (we_W && dst_W != 0 && dst_W == rt_E) ? 2'b01 : 2'b00;
endmodule


module hz_unit (
    input is_jr,
    input [4:0] rs_D, rt_D,
    input [4:0] dest_E, dest_M,
    input mem_read_E, reg_wr_E, reg_wr_M,
    output stall_out
);
    wire chk_lw = mem_read_E && (dest_E != 0) && ((dest_E == rs_D) || (dest_E == rt_D));
    wire chk_jr = is_jr && ((reg_wr_E && dest_E == rs_D) || (reg_wr_M && dest_M == rs_D));
    
    assign stall_out = chk_lw | chk_jr;
endmodule


module alu_core (
    input  wire [31:0] a, b,
    input  wire [3:0]  op,
    output reg  [31:0] res,
    output wire        zero
);
    integer idx;
    reg [31:0] t_mul, t_rem, t_quot;

    always @(*) begin
        t_mul = 32'b0; t_quot = 32'b0; t_rem = 32'b0;
        case (op)
            4'b0000: res = a + b;
            4'b0001: res = a - b;
            4'b0100: begin
                for (idx = 0; idx < 32; idx = idx + 1) begin
                    if (b[idx]) t_mul = t_mul + (a << idx);
                end
                res = t_mul;
            end
            4'b0110: begin
                if (b == 32'b0) res = 32'b0;
                else begin
                    for (idx = 31; idx >= 0; idx = idx - 1) begin
                        t_rem = (t_rem << 1); t_rem[0] = a[idx];
                        if (t_rem >= b) begin t_rem = t_rem - b; t_quot[idx] = 1'b1; end
                    end
                    res = t_quot;
                end
            end
            4'b0111: res = {b[15:0], 16'b0};
            default: res = 32'b0;
        endcase
    end
    assign zero = (res == 32'b0) ? 1'b1 : 1'b0;
endmodule