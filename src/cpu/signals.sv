`include "common.sv"

module signals(
  input rst,
  input clk,
  input [15:0] insn,
  output imm,
  output [15:0] imm_mask,
  output src_a_stk0,
  output src_a_fp,
  output src_a_ip,
  output src_a_cstk,
  output [5:0] alu_sel,
  output wr_stk1,
  output pop,
  output push,
  output load_stk,
  output load_fp,
  output load_ip,
  output cpop,
  output cpush,
  output byt,
  output rd_mem,
  output wr_mem
);

assign src_a_stk0 = ~src_a_fp & ~src_a_ip & ~src_a_cstk;
assign src_a_fp = phase_half & (insn_src_a === 2'b01);
assign src_a_ip = ~phase_half | (insn_src_a === 2'b10);
assign src_a_cstk = phase_half & (insn_src_a === 2'b11);
assign alu_sel = phase_exec ? insn_alu_sel : phase_fetch ? `ALU_INC2 : `ALU_A;
assign pop = insn_pop & phase_exec;
assign push = insn_push & (insn_rd ? phase_rdmem : phase_exec);
assign load_stk = insn_stk & (push | pop);
assign load_fp = insn_fp & phase_exec;
assign load_ip = reload_ip | phase_fetch;
assign cpop = insn_cpop & phase_exec;
assign cpush = insn_cpush & phase_decode;
assign byt = insn_byt & phase_rdmem;
assign rd_mem = insn_rd & phase_rdmem;
assign wr_mem = insn_wr & phase_exec;

logic phase_decode, phase_exec, phase_rdmem, phase_fetch;
signalizer signalizer(.*);

logic [1:0] insn_src_a;
logic [5:0] insn_alu_sel;
logic insn_pop, insn_push, insn_stk, insn_fp, insn_ip, insn_cpop, insn_cpush,
  insn_byt, insn_rd, insn_wr;
decoder decoder(
  .insn(insn),
  .imm(imm),
  .imm_mask(imm_mask),
  .src_a(insn_src_a),
  .alu_sel(insn_alu_sel),
  .wr_stk1(wr_stk1),
  .pop(insn_pop),
  .push(insn_push),
  .load_stk(insn_stk),
  .load_fp(insn_fp),
  .load_ip(insn_ip),
  .cpop(insn_cpop),
  .cpush(insn_cpush),
  .byt(insn_byt),
  .rd_mem(insn_rd),
  .wr_mem(insn_wr)
);

logic reload_ip;
assign reload_ip = insn_ip & phase_exec;

logic phase_half;
assign phase_half = phase_decode | phase_exec;

endmodule
