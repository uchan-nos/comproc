`include "common.sv"

module decoder_tb;

logic [15:0] insn;
logic imm, sign, wr_stk1, pop, push, load_stk, load_fp, load_ip, ind_jmp,
  cpop, cpush, byt, rd_mem, wr_mem;
logic [15:0] imm_mask;
logic [1:0] src_a;
logic [5:0] alu_sel;

decoder decoder(.*);

`define test_sig1(SIG) \
  if (e_``SIG !== 1'bx && SIG !== e_``SIG) $error("%s must be %d", `"SIG`", e_``SIG);

task test_sig(
  input e_imm,
  input e_sign,
  input [15:0] e_imm_mask,
  input [1:0] e_src_a,
  input [5:0] e_alu_sel,
  input e_wr_stk1,
  input e_pop,
  input e_push,
  input e_load_stk,
  input e_load_fp,
  input e_load_ip,
  input e_ind_jmp,
  input e_cpop,
  input e_cpush,
  input e_byt,
  input e_rd_mem,
  input e_wr_mem);
begin
  `test_sig1(imm);
  `test_sig1(sign);
  if (e_imm_mask !== 16'hxxxx && imm_mask !== e_imm_mask)
    $error("imm_mask must be 0x%04x", e_imm_mask);
  if (e_src_a  !== 2'hx  && src_a  !== e_src_a)
    $error("src_a must be %d", e_src_a);
  if (e_alu_sel  !== 6'hxx  && alu_sel  !== e_alu_sel)
    $error("alu_sel must be 0x%02x", e_alu_sel);
  `test_sig1(wr_stk1);
  `test_sig1(pop);
  `test_sig1(push);
  `test_sig1(load_stk);
  `test_sig1(load_fp);
  `test_sig1(load_ip);
  `test_sig1(ind_jmp);
  `test_sig1(cpop);
  `test_sig1(cpush);
  `test_sig1(byt);
  `test_sig1(rd_mem);
  `test_sig1(wr_mem);
end
endtask

`define x 1'bx
`define src_stk0 2'h0
`define src_fp   2'h1
`define src_ip   2'h2
`define src_cstk 2'h3
`define src_x    2'hx

initial begin
  $monitor("%d: insn=%04x imm=%d sign=%d mask=%04x src_a=%d alu=%02x wr_stk1=%d",
           $time, insn, imm, sign, imm_mask, src_a, alu_sel, wr_stk1,
           " pop=%d push=%d load_stk=%d fp=%d ip=%d ind_jmp=%d cpop=%d cpush=%d",
           pop, push, load_stk, load_fp, load_ip, ind_jmp, cpop, cpush,
           " byt=%d rd=%d wr=%d",
           byt, rd_mem, wr_mem);

  insn <= 16'h8BEF;     // push uimm15
  #1 test_sig(1,        // imm,
              0,        // sign,
              16'h7fff, // imm_mask
              `src_x,   // src_a
              `ALU_B,   // alu
              `x,       // wr_stk1
              0,        // pop
              1,        // push
              1,        // load_stk
              0,        // load_fp
              0,        // load_ip
              `x,       // ind_jmp
              0,        // cpop
              0,        // cpush
              `x,       // byt
              0,        // rd_mem
              0         // wr_mem
            );

  #1 insn <= 16'h0020;  // jmp ip+0x20
  #1 test_sig(1,        // imm,
              0,        // sign,
              16'h0ffe, // imm_mask
              `src_ip,  // src_a
              `ALU_ADD, // alu
              `x,       // wr_stk1
              0,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              1,        // load_ip
              0,        // ind_jmp
              0,        // cpop
              0,        // cpush
              `x,       // byt
              `x,       // rd_mem
              0         // wr_mem
            );

  #1 insn <= 16'h0ff1;  // call ip+0xff0
  #1 test_sig(1,        // imm,
              1,        // sign,
              16'h0ffe, // imm_mask
              `src_ip,  // src_a
              `ALU_ADD, // alu
              `x,       // wr_stk1
              0,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              1,        // load_ip
              0,        // ind_jmp
              0,        // cpop
              1,        // cpush
              `x,       // byt
              `x,       // rd_mem
              0         // wr_mem
            );

  #1 insn <= 16'h2BCE;  // ld.1 ip-0x32
  #1 test_sig(1,        // imm,
              1,        // sign,
              16'h03ff, // imm_mask
              `src_ip,  // src_a
              `ALU_ADD, // alu
              0,        // wr_stk1
              0,        // pop
              1,        // push
              1,        // load_stk
              0,        // load_fp
              0,        // load_ip
              `x,       // ind_jmp
              0,        // cpop
              0,        // cpush
              1,        // byt
              1,        // rd_mem
              0         // wr_mem
            );

  #1 insn <= 16'h3439;  // st.1 fp+0x39
  #1 test_sig(1,        // imm,
              0,        // sign,
              16'h03ff, // imm_mask
              `src_fp,  // src_a
              `ALU_ADD, // alu
              0,        // wr_stk1
              1,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              0,        // load_ip
              `x,       // ind_jmp
              0,        // cpop
              0,        // cpush
              1,        // byt
              `x,       // rd_mem
              1         // wr_mem
            );

  #1 insn <= 16'h4c20;  // ld cstack+0x20
  #1 test_sig(1,        // imm,
              0,        // sign,
              16'h03fe, // imm_mask
              `src_cstk,// src_a
              `ALU_ADD, // alu
              0,        // wr_stk1
              0,        // pop
              1,        // push
              1,        // load_stk
              0,        // load_fp
              0,        // load_ip
              `x,       // ind_jmp
              0,        // cpop
              0,        // cpush
              0,        // byt
              1,        // rd_mem
              0         // wr_mem
            );

  #1 insn <= 16'h4439;  // st fp+0x38
  #1 test_sig(1,        // imm,
              0,        // sign,
              16'h03fe, // imm_mask
              `src_fp,  // src_a
              `ALU_ADD, // alu
              0,        // wr_stk1
              1,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              0,        // load_ip
              `x,       // ind_jmp
              0,        // cpop
              0,        // cpush
              0,        // byt
              `x,       // rd_mem
              1         // wr_mem
            );

  #1 insn <= 16'h4039;  // st 0+0x38
  #1 test_sig(1,        // imm,
              0,        // sign,
              16'h03fe, // imm_mask
              `src_x,   // src_a
              `ALU_B,   // alu
              0,        // wr_stk1
              1,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              0,        // load_ip
              `x,       // ind_jmp
              0,        // cpop
              0,        // cpush
              0,        // byt
              `x,       // rd_mem
              1         // wr_mem
            );

  #1 insn <= 16'h6004;  // int 4
  #1 test_sig(1,        // imm,
              0,        // sign,
              16'h03ff, // imm_mask
              2'hx,     // src_a
              `ALU_B,   // alu
              `x,       // wr_stk1
              0,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              1,        // load_ip
              1,        // ind_jmp
              0,        // cpop
              1,        // cpush
              0,        // byt
              `x,       // rd_mem
              0         // wr_mem
            );

  #1 insn <= 16'h6420;  // add fp,0x20
  #1 test_sig(1,        // imm,
              0,        // sign,
              16'h03ff, // imm_mask
              `src_fp,  // src_a
              `ALU_ADD, // alu
              `x,       // wr_stk1
              0,        // pop
              0,        // push
              0,        // load_stk
              1,        // load_fp
              0,        // load_ip
              `x,       // ind_jmp
              0,        // cpop
              0,        // cpush
              `x,       // byt
              `x,       // rd_mem
              0         // wr_mem
            );

  #1 insn <= 16'h7001;  // inc
  #1 test_sig(0,        // imm,
              `x,       // sign,
              16'hxxxx, // imm_mask
              `src_stk0,// src_a
              `ALU_INC, // alu
              `x,       // wr_stk1
              0,        // pop
              0,        // push
              1,        // load_stk
              0,        // load_fp
              0,        // load_ip
              `x,       // ind_jmp
              0,        // cpop
              0,        // cpush
              `x,       // byt
              0,        // rd_mem
              0         // wr_mem
            );

  #1 insn <= 16'h7050;  // and
  #1 test_sig(0,        // imm,
              `x,       // sign,
              16'hxxxx, // imm_mask
              `src_stk0,// src_a
              `ALU_AND, // alu
              `x,       // wr_stk1
              1,        // pop
              0,        // push
              1,        // load_stk
              0,        // load_fp
              0,        // load_ip
              `x,       // ind_jmp
              0,        // cpop
              0,        // cpush
              `x,       // byt
              0,        // rd_mem
              0         // wr_mem
            );

  #1 insn <= 16'h708F;  // dup 1
  #1 test_sig(0,        // imm,
              `x,       // sign,
              16'hxxxx, // imm_mask
              2'hx,     // src_a
              `ALU_B,   // alu
              `x,       // wr_stk1
              0,        // pop
              1,        // push
              1,        // load_stk
              0,        // load_fp
              0,        // load_ip
              `x,       // ind_jmp
              0,        // cpop
              0,        // cpush
              `x,       // byt
              0,        // rd_mem
              0         // wr_mem
            );

  #1 insn <= 16'h7800;  // ret
  #1 test_sig(0,        // imm,
              `x,       // sign,
              16'hxxxx, // imm_mask
              `src_cstk,// src_a
              `ALU_A,   // alu
              `x,       // wr_stk1
              0,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              1,        // load_ip
              0,        // ind_jmp
              1,        // cpop
              0,        // cpush
              0,        // byt
              `x,       // rd_mem
              0         // wr_mem
            );

  #1 insn <= 16'h7808;  // ldd
  #1 test_sig(0,        // imm,
              `x,       // sign,
              16'hxxxx, // imm_mask
              `src_stk0,// src_a
              `ALU_A,   // alu
              `x,       // wr_stk1
              0,        // pop
              0,        // push
              1,        // load_stk
              0,        // load_fp
              0,        // load_ip
              `x,       // ind_jmp
              0,        // cpop
              0,        // cpush
              0,        // byt
              1,        // rd_mem
              0         // wr_mem
            );

  #1 insn <= 16'h780C;  // sta
  #1 test_sig(0,        // imm,
              `x,       // sign,
              16'hxxxx, // imm_mask
              `src_stk0,// src_a
              `ALU_A,   // alu
              1,        // wr_stk1
              1,        // pop
              0,        // push
              1,        // load_stk
              0,        // load_fp
              0,        // load_ip
              `x,       // ind_jmp
              0,        // cpop
              0,        // cpush
              0,        // byt
              0,        // rd_mem
              1         // wr_mem
            );

  #1 insn <= 16'h780E;  // std
  #1 test_sig(0,        // imm,
              `x,       // sign,
              16'hxxxx, // imm_mask
              `src_stk0,// src_a
              `ALU_A,   // alu
              1,        // wr_stk1
              1,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              0,        // load_ip
              `x,       // ind_jmp
              0,        // cpop
              0,        // cpush
              0,        // byt
              `x,       // rd_mem
              1         // wr_mem
            );

end

endmodule
