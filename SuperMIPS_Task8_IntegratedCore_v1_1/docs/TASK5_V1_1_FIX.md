# Task 5 v1.1 fix

Two failures in `tb_forwarding_backend` were analyzed.

1. **Priority-consumer test setup:** the test inherited `alu_src0=1` and
   `imm0=20` from the preceding ADDI producer. The consumer therefore executed
   `20+20`, even though the forwarding selector correctly chose the newer E/M
   value. The test now explicitly selects the register-B path and checks
   `20+1=21`.

2. **Branch comparison robustness:** branch-taken previously reused the ALU
   zero output. That made branch correctness depend on `alu_src_imm` and the
   selected arithmetic operation. The execute stage now compares the two
   forwarded register operands directly:

   `branch_taken = is_branch && (forwarded_rs == forwarded_rt)`

The branch test intentionally selects the immediate ALU path to prove that the
branch comparator is independent from the arithmetic ALU-B mux.
