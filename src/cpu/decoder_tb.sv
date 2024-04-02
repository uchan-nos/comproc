`include "common.sv"

module decoder_tb;

logic [15:0] insn;
logic sign, wr_stk1, pop, push, load_stk, load_fp, load_ip, load_isr,
  cpop, cpush, byt, rd_mem, wr_mem, set_ien, clear_ien;
logic [15:0] imm_mask;
logic [2:0] src_a;
logic [1:0] src_b;
logic [5:0] alu_sel;

decoder decoder(.*);

`define test_sig1(SIG) \
  if (e_``SIG !== 1'bx && SIG !== e_``SIG) $error("%s must be %d", `"SIG`", e_``SIG);

task test_sig(
  input e_sign,
  input [15:0] e_imm_mask,
  input [2:0] e_src_a,
  input [1:0] e_src_b,
  input [5:0] e_alu_sel,
  input e_wr_stk1,
  input e_pop,
  input e_push,
  input e_load_stk,
  input e_load_fp,
  input e_load_ip,
  input e_load_isr,
  input e_cpop,
  input e_cpush,
  input e_byt,
  input e_rd_mem,
  input e_wr_mem,
  input e_set_ien, e_clear_ien
);
begin
  `test_sig1(sign);
  if (e_imm_mask !== 16'hxxxx && imm_mask !== e_imm_mask)
    $error("imm_mask must be 0x%04x", e_imm_mask);
  if (e_src_a  !== `SRCA_X && src_a  !== e_src_a)
    $error("src_a must be %d", e_src_a);
  if (e_src_b  !== 2'hx && src_b  !== e_src_b)
    $error("src_b must be %d", e_src_b);
  if (e_alu_sel  !== 6'hxx  && alu_sel  !== e_alu_sel)
    $error("alu_sel must be 0x%02x", e_alu_sel);
  `test_sig1(wr_stk1);
  `test_sig1(pop);
  `test_sig1(push);
  `test_sig1(load_stk);
  `test_sig1(load_fp);
  `test_sig1(load_ip);
  `test_sig1(load_isr);
  `test_sig1(cpop);
  `test_sig1(cpush);
  `test_sig1(byt);
  `test_sig1(rd_mem);
  `test_sig1(wr_mem);
  `test_sig1(set_ien);
  `test_sig1(clear_ien);
end
endtask

`define x 1'bx
`define SRC_X 2'hx

initial begin
  $monitor("%d: insn=%04x sign=%d mask=%04x src_a=%d src_b=%d alu=%02x wr_stk1=%d",
           $time, insn, sign, imm_mask, src_a, src_b, alu_sel, wr_stk1,
           " pop=%d push=%d load_stk=%d fp=%d ip=%d isr=%d cpop=%d cpush=%d",
           pop, push, load_stk, load_fp, load_ip, load_isr, cpop, cpush,
           " byt=%d rd=%d wr=%d set/clr_ien=%d/%d",
           byt, rd_mem, wr_mem, set_ien, clear_ien);

  insn <= 16'h8BEF;     // PUSH uimm15
  #1 test_sig(0,        // sign,
              16'h7fff, // imm_mask
              `SRCA_X,  // src_a
              `SRC_IMM, // src_b
              `ALU_B,   // alu
              `x,       // wr_stk1
              0,        // pop
              1,        // push
              1,        // load_stk
              0,        // load_fp
              0,        // load_ip
              0,        // load_isr
              0,        // cpop
              0,        // cpush
              `x,       // byt
              0,        // rd_mem
              0,        // wr_mem
              0,        // set_ien
              0         // clear_ien
            );

  #1 insn <= 16'h0020;  // JMP ip+0x20
  #1 test_sig(0,        // sign,
              16'h0ffe, // imm_mask
              `SRCA_IP, // src_a
              `SRC_IMM, // src_b
              `ALU_ADD, // alu
              `x,       // wr_stk1
              0,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              1,        // load_ip
              0,        // load_isr
              0,        // cpop
              0,        // cpush
              `x,       // byt
              0,        // rd_mem
              0,        // wr_mem
              0,        // set_ien
              0         // clear_ien
            );

  #1 insn <= 16'h0ff1;  // CALL ip+0xff0
  #1 test_sig(1,        // sign,
              16'h0ffe, // imm_mask
              `SRCA_IP, // src_a
              `SRC_IMM, // src_b
              `ALU_ADD, // alu
              `x,       // wr_stk1
              0,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              1,        // load_ip
              0,        // load_isr
              0,        // cpop
              1,        // cpush
              `x,       // byt
              0,        // rd_mem
              0,        // wr_mem
              0,        // set_ien
              0         // clear_ien
            );

  #1 insn <= 16'h2BCE;  // LD1 ip+0x3CE
  #1 test_sig(0,        // sign,
              16'h03ff, // imm_mask
              `SRCA_IP, // src_a
              `SRC_IMM, // src_b
              `ALU_ADD, // alu
              0,        // wr_stk1
              0,        // pop
              1,        // push
              1,        // load_stk
              0,        // load_fp
              0,        // load_ip
              0,        // load_isr
              0,        // cpop
              0,        // cpush
              1,        // byt
              1,        // rd_mem
              0,        // wr_mem
              0,        // set_ien
              0         // clear_ien
            );

  #1 insn <= 16'h3439;  // ST1 bar+0x39
  #1 test_sig(0,        // sign,
              16'h03ff, // imm_mask
              `SRCA_BAR,// src_a
              `SRC_IMM, // src_b
              `ALU_ADD, // alu
              0,        // wr_stk1
              1,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              0,        // load_ip
              0,        // load_isr
              0,        // cpop
              0,        // cpush
              1,        // byt
              0,        // rd_mem
              1,        // wr_mem
              0,        // set_ien
              0         // clear_ien
            );

  #1 insn <= 16'h4e20;  // LD cstack+0x220
  #1 test_sig(0,        // sign,
              16'h03fe, // imm_mask
              `SRCA_CSTK,// src_a
              `SRC_IMM, // src_b
              `ALU_ADD, // alu
              0,        // wr_stk1
              0,        // pop
              1,        // push
              1,        // load_stk
              0,        // load_fp
              0,        // load_ip
              0,        // load_isr
              0,        // cpop
              0,        // cpush
              0,        // byt
              1,        // rd_mem
              0,        // wr_mem
              0,        // set_ien
              0         // clear_ien
            );

  #1 insn <= 16'h4439;  // ST bar+0x38
  #1 test_sig(0,        // sign,
              16'h03fe, // imm_mask
              `SRCA_BAR,// src_a
              `SRC_IMM, // src_b
              `ALU_ADD, // alu
              0,        // wr_stk1
              1,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              0,        // load_ip
              0,        // load_isr
              0,        // cpop
              0,        // cpush
              0,        // byt
              0,        // rd_mem
              1,        // wr_mem
              0,        // set_ien
              0         // clear_ien
            );

  #1 insn <= 16'h4039;  // ST 0+0x38
  #1 test_sig(0,        // sign,
              16'h03fe, // imm_mask
              `SRCA_X,  // src_a
              `SRC_IMM, // src_b
              `ALU_B,   // alu
              0,        // wr_stk1
              1,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              0,        // load_ip
              0,        // load_isr
              0,        // cpop
              0,        // cpush
              0,        // byt
              0,        // rd_mem
              1,        // wr_mem
              0,        // set_ien
              0         // clear_ien
            );

  #1 insn <= 16'h6420;  // ADD fp,0x20
  #1 test_sig(0,        // sign,
              16'h03ff, // imm_mask
              `SRCA_FP, // src_a
              `SRC_IMM, // src_b
              `ALU_ADD, // alu
              `x,       // wr_stk1
              0,        // pop
              0,        // push
              0,        // load_stk
              1,        // load_fp
              0,        // load_ip
              0,        // load_isr
              0,        // cpop
              0,        // cpush
              `x,       // byt
              0,        // rd_mem
              0,        // wr_mem
              0,        // set_ien
              0         // clear_ien
            );

  #1 insn <= 16'h7001;  // INC
  #1 test_sig(`x,       // sign,
              16'hxxxx, // imm_mask
              `SRCA_STK0,// src_a
              `SRC_X,   // src_b
              `ALU_INC, // alu
              `x,       // wr_stk1
              0,        // pop
              0,        // push
              1,        // load_stk
              0,        // load_fp
              0,        // load_ip
              0,        // load_isr
              0,        // cpop
              0,        // cpush
              `x,       // byt
              0,        // rd_mem
              0,        // wr_mem
              0,        // set_ien
              0         // clear_ien
            );

  #1 insn <= 16'h7050;  // AND
  #1 test_sig(`x,       // sign,
              16'hxxxx, // imm_mask
              `SRCA_STK0,// src_a
              `SRC_STK1,// src_b
              `ALU_AND, // alu
              `x,       // wr_stk1
              1,        // pop
              0,        // push
              1,        // load_stk
              0,        // load_fp
              0,        // load_ip
              0,        // load_isr
              0,        // cpop
              0,        // cpush
              `x,       // byt
              0,        // rd_mem
              0,        // wr_mem
              0,        // set_ien
              0         // clear_ien
            );

  #1 insn <= 16'h708F;  // DUP1
  #1 test_sig(`x,       // sign,
              16'hxxxx, // imm_mask
              `SRCA_X,  // src_a
              `SRC_STK1,// src_b
              `ALU_B,   // alu
              `x,       // wr_stk1
              0,        // pop
              1,        // push
              1,        // load_stk
              0,        // load_fp
              0,        // load_ip
              0,        // load_isr
              0,        // cpop
              0,        // cpush
              `x,       // byt
              0,        // rd_mem
              0,        // wr_mem
              0,        // set_ien
              0         // clear_ien
            );

  #1 insn <= 16'h7800;  // RET
  #1 test_sig(`x,       // sign,
              16'hxxxx, // imm_mask
              `SRCA_CSTK,// src_a
              `SRC_X,   // src_b
              `ALU_A,   // alu
              `x,       // wr_stk1
              0,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              1,        // load_ip
              0,        // load_isr
              1,        // cpop
              0,        // cpush
              0,        // byt
              0,        // rd_mem
              0,        // wr_mem
              0,        // set_ien
              0         // clear_ien
            );

  #1 insn <= 16'h7808;  // LDD
  #1 test_sig(`x,       // sign,
              16'hxxxx, // imm_mask
              `SRCA_STK0,// src_a
              `SRC_X,   // src_b
              `ALU_A,   // alu
              `x,       // wr_stk1
              0,        // pop
              0,        // push
              1,        // load_stk
              0,        // load_fp
              0,        // load_ip
              0,        // load_isr
              0,        // cpop
              0,        // cpush
              0,        // byt
              1,        // rd_mem
              0,        // wr_mem
              0,        // set_ien
              0         // clear_ien
            );

  #1 insn <= 16'h780C;  // STA
  #1 test_sig(`x,       // sign,
              16'hxxxx, // imm_mask
              `SRCA_STK0,// src_a
              `SRC_X,   // src_b
              `ALU_A,   // alu
              1,        // wr_stk1
              1,        // pop
              0,        // push
              1,        // load_stk
              0,        // load_fp
              0,        // load_ip
              0,        // load_isr
              0,        // cpop
              0,        // cpush
              0,        // byt
              0,        // rd_mem
              1,        // wr_mem
              0,        // set_ien
              0         // clear_ien
            );

  #1 insn <= 16'h780E;  // STD
  #1 test_sig(`x,       // sign,
              16'hxxxx, // imm_mask
              `SRCA_STK0,// src_a
              `SRC_X,   // src_b
              `ALU_A,   // alu
              1,        // wr_stk1
              1,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              0,        // load_ip
              0,        // load_isr
              0,        // cpop
              0,        // cpush
              0,        // byt
              0,        // rd_mem
              1,        // wr_mem
              0,        // set_ien
              0         // clear_ien
            );

  #1 insn <= 16'h7810;  // INT
  #1 test_sig(`x,       // sign,
              16'hxxxx, // imm_mask
              `SRCA_IP, // src_a
              `SRC_ISR, // src_b
              `ALU_B,   // alu
              `x,       // wr_stk1
              0,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              1,        // load_ip
              0,        // load_isr
              0,        // cpop
              1,        // cpush
              `x,       // byt
              0,        // rd_mem
              0,        // wr_mem
              0,        // set_ien
              0         // clear_ien
            );

  #1 insn <= 16'h7811;  // ISR
  #1 test_sig(`x,       // sign,
              16'hxxxx, // imm_mask
              `SRCA_STK0,// src_a
              `SRC_X,   // src_b
              `ALU_A,   // alu
              `x,       // wr_stk1
              1,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              0,        // load_ip
              1,        // load_isr
              0,        // cpop
              0,        // cpush
              `x,       // byt
              0,        // rd_mem
              0,        // wr_mem
              0,        // set_ien
              0         // clear_ien
            );

  #1 insn <= 16'h7812;  // IRET
  #1 test_sig(`x,       // sign,
              16'hxxxx, // imm_mask
              `SRCA_CSTK,// src_a
              `SRC_X,   // src_b
              `ALU_A,   // alu
              `x,       // wr_stk1
              0,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              1,        // load_ip
              0,        // load_isr
              1,        // cpop
              0,        // cpush
              `x,       // byt
              0,        // rd_mem
              0,        // wr_mem
              1,        // set_ien
              0         // clear_ien
            );

end

endmodule
