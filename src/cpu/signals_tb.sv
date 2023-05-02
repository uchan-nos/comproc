`include "common.sv"

module signals_tb;

logic rst, clk;
logic [15:0] insn;
logic imm, src_a_stk0, src_a_fp, src_a_ip, src_a_cstk, wr_stk1, pop, push,
  load_stk, load_fp, load_ip, cpop, cpush, byt, rd_mem, wr_mem;
logic [15:0] imm_mask;
logic [5:0] alu_sel;

signals signals(.*);

initial begin
  $dumpvars;
  $monitor("%d: rst=%d phase=%d%d%d%d insn=%04x imm=%d[%04x] src_a=%d%d%d%d alu=%02x",
           $time, rst, signals.phase_decode, signals.phase_exec,
           signals.phase_rdmem, signals.phase_fetch, insn, imm, imm_mask,
           src_a_stk0, src_a_fp, src_a_ip, src_a_cstk, alu_sel,
           " wr_stk1=%d pop/sh=%d%d load=%d%d%d cpop/sh=%d%d byt=%d rd=%d wr=%d",
           wr_stk1, pop, push, load_stk, load_fp, load_ip,
           cpop, cpush, byt, rd_mem, wr_mem
           , " insn_cpush=%d", signals.insn_cpush
         );

  rst <= 1;
  clk <= 1;
  insn <= 16'h0000;

  #13
    rst <= 0;
    test_sig_fetch;

  @(posedge clk)
    insn <= 16'h80A5; // PUSH 0xA5
    test_sig_phases(0,         // call
                    1,         // imm
                    16'h7fff,  // imm_mask
                    x,         // src_a_stk0
                    x,         // src_a_fp
                    x,         // src_a_ip
                    x,         // src_a_cstk
                    `ALU_B,    // alu_sel
                    x,         // wr_stk1
                    0,         // pop
                    1,         // push
                    1,         // load_stk
                    0,         // load_fp
                    0,         // load_ip
                    0,         // cpop
                    0,         // cpush
                    x,         // byt
                    0,         // rd_mem
                    0          // wr_mem
                  );

  @(posedge clk)
    insn <= 16'h0234; // JMP 0x234
    test_sig_phases(0,         // call
                    1,         // imm
                    16'h0ffe,  // imm_mask
                    0,         // src_a_stk0
                    0,         // src_a_fp
                    1,         // src_a_ip
                    0,         // src_a_cstk
                    `ALU_ADD,  // alu_sel
                    x,         // wr_stk1
                    0,         // pop
                    0,         // push
                    0,         // load_stk
                    0,         // load_fp
                    1,         // load_ip
                    0,         // cpop
                    0,         // cpush
                    x,         // byt
                    0,         // rd_mem
                    0          // wr_mem
                  );

  @(posedge clk)
    insn <= 16'h0235; // CALL 0x234
    test_sig_phases(1,         // call
                    1,         // imm
                    16'h0ffe,  // imm_mask
                    0,         // src_a_stk0
                    0,         // src_a_fp
                    1,         // src_a_ip
                    0,         // src_a_cstk
                    `ALU_ADD,  // alu_sel
                    x,         // wr_stk1
                    0,         // pop
                    0,         // push
                    0,         // load_stk
                    0,         // load_fp
                    1,         // load_ip
                    0,         // cpop
                    0,         // cpush
                    x,         // byt
                    0,         // rd_mem
                    0          // wr_mem
                  );

  @(posedge clk)
    insn <= 16'h1234; // JZ 0x234
    test_sig_phases(0,         // call
                    1,         // imm
                    16'h0ffe,  // imm_mask
                    0,         // src_a_stk0
                    0,         // src_a_fp
                    1,         // src_a_ip
                    0,         // src_a_cstk
                    `ALU_ADDZ, // alu_sel
                    x,         // wr_stk1
                    1,         // pop
                    0,         // push
                    0,         // load_stk
                    0,         // load_fp
                    1,         // load_ip
                    0,         // cpop
                    0,         // cpush
                    x,         // byt
                    0,         // rd_mem
                    0          // wr_mem
                  );

  @(posedge clk)
    insn <= 16'h3420; // ST FP+0x20
    test_sig_phases(0,         // call
                    1,         // imm
                    16'h03fe,  // imm_mask
                    0,         // src_a_stk0
                    1,         // src_a_fp
                    0,         // src_a_ip
                    0,         // src_a_cstk
                    `ALU_ADD,  // alu_sel
                    0,         // wr_stk1
                    1,         // pop
                    0,         // push
                    0,         // load_stk
                    0,         // load_fp
                    0,         // load_ip
                    0,         // cpop
                    0,         // cpush
                    0,         // byt
                    0,         // rd_mem
                    1          // wr_mem
                  );

  @(posedge clk)
    insn <= 16'h704F; // POP
    test_sig_phases(0,         // call
                    0,         // imm
                    16'hxxxx,  // imm_mask
                    x,         // src_a_stk0
                    x,         // src_a_fp
                    x,         // src_a_ip
                    x,         // src_a_cstk
                    `ALU_B,    // alu_sel
                    x,         // wr_stk1
                    1,         // pop
                    0,         // push
                    1,         // load_stk
                    0,         // load_fp
                    0,         // load_ip
                    0,         // cpop
                    0,         // cpush
                    x,         // byt
                    0,         // rd_mem
                    0          // wr_mem
                  );

  @(posedge clk)
    insn <= 16'h7004; // NOT
    test_sig_phases(0,         // call
                    0,         // imm
                    16'hxxxx,  // imm_mask
                    1,         // src_a_stk0
                    0,         // src_a_fp
                    0,         // src_a_ip
                    0,         // src_a_cstk
                    `ALU_NOT,  // alu_sel
                    x,         // wr_stk1
                    0,         // pop
                    0,         // push
                    1,         // load_stk
                    0,         // load_fp
                    0,         // load_ip
                    0,         // cpop
                    0,         // cpush
                    x,         // byt
                    0,         // rd_mem
                    0          // wr_mem
                  );

  @(posedge clk)
    insn <= 16'h7809; // LDD.1
  @(negedge clk)
    if (~signals.phase_decode) $error("phase_decode must be 1");
    test_sig_decode(0);

  @(negedge clk)
    if (~signals.phase_exec) $error("phase_exec must be 1");
    test_sig(0,         // imm
             16'hxxxx,  // imm_mask
             1,         // src_a_stk0
             0,         // src_a_fp
             0,         // src_a_ip
             0,         // src_a_cstk
             `ALU_A,    // alu_sel
             x,         // wr_stk1
             0,         // pop
             0,         // push
             0,         // load_stk
             0,         // load_fp
             0,         // load_ip
             0,         // cpop
             0,         // cpush
             x,         // byt
             x,         // rd_mem
             0          // wr_mem
           );

  @(negedge clk)
    if (~signals.phase_rdmem) $error("phase_rdmem must be 1");
    test_sig(0,         // imm
             16'hxxxx,  // imm_mask
             0,         // src_a_stk0
             0,         // src_a_fp
             1,         // src_a_ip
             0,         // src_a_cstk
             `ALU_A,    // alu_sel
             x,         // wr_stk1
             0,         // pop
             0,         // push
             1,         // load_stk
             0,         // load_fp
             0,         // load_ip
             0,         // cpop
             0,         // cpush
             1,         // byt
             1,         // rd_mem
             0          // wr_mem
           );

  @(negedge clk)
    if (~signals.phase_fetch) $error("phase_fetch must be 1");
    test_sig_fetch;

  $finish;
end

always #5 begin
  clk <= ~clk;
end

`define test_sig1(SIG) \
  if (e_``SIG !== 1'bx && SIG !== e_``SIG) $error("%s must be %d", `"SIG`", e_``SIG);

task test_sig(
  input e_imm,
  input [15:0] e_imm_mask,
  input e_src_a_stk0,
  input e_src_a_fp,
  input e_src_a_ip,
  input e_src_a_cstk,
  input [5:0] e_alu_sel,
  input e_wr_stk1,
  input e_pop,
  input e_push,
  input e_load_stk,
  input e_load_fp,
  input e_load_ip,
  input e_cpop,
  input e_cpush,
  input e_byt,
  input e_rd_mem,
  input e_wr_mem);
begin
  `test_sig1(imm);
  if (e_imm_mask !== 16'hxxxx && imm_mask !== e_imm_mask)
    $error("imm_mask must be 0x%04x", e_imm_mask);
  `test_sig1(src_a_stk0);
  `test_sig1(src_a_fp);
  `test_sig1(src_a_ip);
  `test_sig1(src_a_cstk);
  if (e_alu_sel !== 6'hxx && alu_sel !== e_alu_sel)
    $error("alu_sel must be 0x%02x", e_alu_sel);
  `test_sig1(wr_stk1);
  `test_sig1(pop);
  `test_sig1(push);
  `test_sig1(load_stk);
  `test_sig1(load_fp);
  `test_sig1(load_ip);
  `test_sig1(cpop);
  `test_sig1(cpush);
  `test_sig1(byt);
  `test_sig1(rd_mem);
  `test_sig1(wr_mem);
end
endtask

task test_sig_decode(input call);
begin
  if (call)
    test_sig(x,         // imm
             16'hxxxx,  // imm_mask
             0,         // src_a_stk0
             0,         // src_a_fp
             1,         // src_a_ip
             0,         // src_a_cstk
             `ALU_A,    // alu_sel
             x,         // wr_stk1
             0,         // pop
             0,         // push
             0,         // load_stk
             0,         // load_fp
             0,         // load_ip
             0,         // cpop
             1,         // cpush
             x,         // byt
             0,         // rd_mem
             0          // wr_mem
           );
  else
    test_sig(x,         // imm
             16'hxxxx,  // imm_mask
             x,         // src_a_stk0
             x,         // src_a_fp
             x,         // src_a_ip
             x,         // src_a_cstk
             6'hxx,     // alu_sel
             x,         // wr_stk1
             0,         // pop
             0,         // push
             0,         // load_stk
             0,         // load_fp
             0,         // load_ip
             0,         // cpop
             0,         // cpush
             x,         // byt
             0,         // rd_mem
             0          // wr_mem
           );
end
endtask

task test_sig_rdmem;
begin
  if (~signals.phase_rdmem) $error("phase_rdmem must be 1");
  test_sig(x,         // imm
           16'hxxxx,  // imm_mask
           0,         // src_a_stk0
           0,         // src_a_fp
           1,         // src_a_ip
           0,         // src_a_cstk
           `ALU_A,    // alu_sel
           x,         // wr_stk1
           0,         // pop
           0,         // push
           0,         // load_stk
           0,         // load_fp
           0,         // load_ip
           0,         // cpop
           0,         // cpush
           x,         // byt
           x,         // rd_mem
           0          // wr_mem
         );
end
endtask

task test_sig_fetch;
begin
  if (~signals.phase_fetch) $error("phase_fetch must be 1");
  test_sig(x,         // imm
           16'hxxxx,  // imm_mask
           0,         // src_a_stk0
           0,         // src_a_fp
           1,         // src_a_ip
           0,         // src_a_cstk
           `ALU_INC2, // alu_sel
           x,         // wr_stk1
           0,         // pop
           0,         // push
           0,         // load_stk
           0,         // load_fp
           1,         // load_ip
           0,         // cpop
           0,         // cpush
           0,         // byt
           0,         // rd_mem
           0          // wr_mem
         );
end
endtask

task test_sig_phases(
  input call,
  input e_imm,
  input [15:0] e_imm_mask,
  input e_src_a_stk0,
  input e_src_a_fp,
  input e_src_a_ip,
  input e_src_a_cstk,
  input [5:0] e_alu_sel,
  input e_wr_stk1,
  input e_pop,
  input e_push,
  input e_load_stk,
  input e_load_fp,
  input e_load_ip,
  input e_cpop,
  input e_cpush,
  input e_byt,
  input e_rd_mem,
  input e_wr_mem);
begin
  @(negedge clk)
    if (~signals.phase_decode) $error("phase_decode must be 1");
    test_sig_decode(call);

  @(negedge clk)
    if (~signals.phase_exec) $error("phase_exec must be 1");
    test_sig(e_imm, e_imm_mask, e_src_a_stk0, e_src_a_fp, e_src_a_ip, e_src_a_cstk,
             e_alu_sel, e_wr_stk1, e_pop, e_push, e_load_stk, e_load_fp, e_load_ip,
             e_cpop, e_cpush, e_byt, e_rd_mem, e_wr_mem);

  @(negedge clk)
    if (~signals.phase_rdmem) $error("phase_rdmem must be 1");
    test_sig_rdmem;

  @(negedge clk)
    if (~signals.phase_fetch) $error("phase_fetch must be 1");
    test_sig_fetch;
end
endtask

//`define x 1'bx
logic x;
assign x = 1'bx;

endmodule
