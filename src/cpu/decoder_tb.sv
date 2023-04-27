module decoder_tb;

logic [15:0] insn;
logic imm, wr_stk1, load, pop, push, load_stk, load_fp, load_ip, byt, wr;
logic [15:0] imm_mask;
logic [1:0] src_a;
logic [5:0] alu_sel;

decoder decoder(.*);

`define test_sig1(SIG) \
  if (e_``SIG !== 1'bx && SIG !== e_``SIG) $error("%s must be %d", `"SIG`", e_``SIG);

task test_sig(
  input e_imm,
  input [15:0] e_imm_mask,
  input [1:0] e_src_a,
  input [5:0] e_alu_sel,
  input e_wr_stk1,
  input e_load,
  input e_pop,
  input e_push,
  input e_load_stk,
  input e_load_fp,
  input e_load_ip,
  input e_byt,
  input e_wr);
begin
  `test_sig1(imm);
  if (e_imm_mask !== 16'hxxxx && imm_mask !== e_imm_mask)
    $error("imm_mask must be 0x%04x", e_imm_mask);
  if (e_src_a  !== 2'hx  && src_a  !== e_src_a)
    $error("src_a must be %d", e_src_a);
  if (e_alu_sel  !== 6'hxx  && alu_sel  !== e_alu_sel)
    $error("alu_sel must be 0x%02x", e_alu_sel);
  `test_sig1(wr_stk1);
  `test_sig1(load);
  `test_sig1(pop);
  `test_sig1(push);
  `test_sig1(load_stk);
  `test_sig1(load_fp);
  `test_sig1(load_ip);
  `test_sig1(byt);
  `test_sig1(wr);
end
endtask

`define x 1'bx
`define src_stk0 2'h0
`define src_fp   2'h1
`define src_ip   2'h2
`define src_cstk 2'h3
`define src_x    2'hx

initial begin
  $monitor("%d: insn=%04x imm=%d mask=%04x src_a=%d wr_stk1=%d load=%d pop=%d push=%d fp=%d ip=%d byt=%d wr=%d alu=%02x",
           $time, insn, imm, imm_mask, src_a, wr_stk1, load, pop, push, load_fp, load_ip, byt, wr, alu_sel);

  insn <= 16'h0BEF;     // push uimm15
  #1 test_sig(1,        // imm,
              16'h7fff, // imm_mask
              `src_x,   // src_a
              6'h0f,    // alu
              `x,       // wr_stk1
              0,        // load
              0,        // pop
              1,        // push
              1,        // load_stk
              0,        // load_fp
              0,        // load_ip
              `x,       // byt
              0         // wr
            );

  #1 insn <= 16'h8020;  // jmp ip+0x20
  #1 test_sig(1,        // imm,
              16'h0ffe, // imm_mask
              `src_ip,  // src_a
              6'h20,    // alu
              `x,       // wr_stk1
              0,        // load
              0,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              1,        // load_ip
              `x,       // byt
              0         // wr
            );

  #1 insn <= 16'hB430;  // st fp+0x30
  #1 test_sig(1,        // imm,
              16'h03fe, // imm_mask
              `src_fp,  // src_a
              6'h20,    // alu
              0,        // wr_stk1
              0,        // load
              1,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              0,        // load_ip
              0,        // byt
              1         // wr
            );

  #1 insn <= 16'hF050;  // and
  #1 test_sig(0,        // imm,
              16'hxxxx, // imm_mask
              `src_stk0,// src_a
              6'h10,    // alu
              `x,       // wr_stk1
              0,        // load
              1,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              0,        // load_ip
              `x,       // byt
              0         // wr
            );

  #1 insn <= 16'hF8C0;  // ldd
  #1 test_sig(0,        // imm,
              16'hxxxx, // imm_mask
              `src_stk0,// src_a
              6'h00,    // alu
              0,        // wr_stk1
              1,        // load
              0,        // pop
              0,        // push
              1,        // load_stk
              0,        // load_fp
              0,        // load_ip
              0,        // byt
              0         // wr
            );

  #1 insn <= 16'hF840;  // std
  #1 test_sig(0,        // imm,
              16'hxxxx, // imm_mask
              `src_stk0,// src_a
              6'h00,    // alu
              1,        // wr_stk1
              0,        // load
              1,        // pop
              0,        // push
              0,        // load_stk
              0,        // load_fp
              0,        // load_ip
              0,        // byt
              1         // wr
            );

  #1 insn <= 16'hF846;  // sta
  #1 test_sig(0,        // imm,
              16'hxxxx, // imm_mask
              `src_stk0,// src_a
              6'h00,    // alu
              1,        // wr_stk1
              0,        // load
              1,        // pop
              0,        // push
              1,        // load_stk
              0,        // load_fp
              0,        // load_ip
              0,        // byt
              1         // wr
            );

end

endmodule
