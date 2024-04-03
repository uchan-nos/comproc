`include "common.sv"

module signals(
  input rst,
  input clk,
  input irq,
  input [15:0] insn,
  output sign,
  output [15:0] imm_mask,
  output [2:0] src_a_sel,
  //output src_a_fp,
  //output src_a_ip,
  //output src_a_cstk,
  output [1:0] src_b_sel,
  output [5:0] alu_sel,
  output wr_stk1,
  output pop,
  output push,
  output load_stk,
  output load_fp,
  output load_ip,
  output load_insn,
  output load_isr,
  output load_bar,
  output cpop,
  output cpush,
  output byt,
  output rd_mem,
  output wr_mem,
  output set_ien, clear_ien
);

logic src_a_bar, src_a_ip, src_a_cstk, src_a_fp;

assign src_a_sel = src_a_bar ? `SRCA_BAR
                   : src_a_ip ? `SRCA_IP
                   : src_a_cstk ? `SRCA_CSTK
                   : src_a_fp ? `SRCA_FP
                   : `SRCA_STK0;
assign src_a_bar = phase_half & (insn_src_a === `SRCA_BAR) & ~irq_pend;
assign src_a_ip = ~phase_half | (insn_src_a === `SRCA_IP) | irq_pend;
assign src_a_cstk = phase_half & (insn_src_a === `SRCA_CSTK) & ~irq_pend;
assign src_a_fp = phase_half & (insn_src_a === `SRCA_FP) & ~irq_pend;
assign src_b_sel = irq_pend ? `SRCB_ISR : insn_src_b;
assign alu_sel = phase_exec ? (irq_pend ? `ALU_B : insn_alu_sel) : phase_fetch ? `ALU_INC2 : `ALU_A;
assign pop = (insn_pop & ~irq_pend) & phase_exec;
assign push = (insn_push & ~irq_pend) & (insn_rd ? phase_rdmem : phase_exec);
assign load_stk = (insn_stk & ~irq_pend) & (insn_rd ? phase_rdmem : phase_exec);
assign load_fp = (insn_fp & ~irq_pend) & phase_exec;
assign load_ip = reload_ip | (phase_fetch & ~irq /* not irq_pend */);
assign load_insn = phase_fetch;
assign load_isr = (insn_isr & ~irq_pend) & phase_exec;
assign load_bar = (insn_bar & ~irq_pend) & phase_exec;
assign cpop = (insn_cpop & ~irq_pend) & phase_exec;
assign cpush = (insn_cpush | irq_pend) & phase_decode;
assign byt = (insn_byt & ~irq_pend);
assign rd_mem = phase_rdmem & insn_rd;
assign wr_mem = (insn_wr & ~irq_pend) & phase_exec;
assign set_ien = (insn_set_ien & ~irq_pend) & phase_exec;
assign clear_ien = (insn_clear_ien | irq_pend) & phase_exec;

logic phase_decode, phase_exec, phase_rdmem, phase_fetch, irq_pend;
signalizer signalizer(.*);

logic [2:0] insn_src_a;
logic [1:0] insn_src_b;
logic [5:0] insn_alu_sel;
logic insn_pop, insn_push, insn_stk, insn_fp, insn_ip, insn_isr, insn_bar,
  insn_cpop, insn_cpush, insn_byt, insn_rd, insn_wr,
  insn_set_ien, insn_clear_ien;
decoder decoder(
  .insn(insn),
  .sign(sign),
  .imm_mask(imm_mask),
  .src_a(insn_src_a),
  .src_b(insn_src_b),
  .alu_sel(insn_alu_sel),
  .wr_stk1(wr_stk1),
  .pop(insn_pop),
  .push(insn_push),
  .load_stk(insn_stk),
  .load_fp(insn_fp),
  .load_ip(insn_ip),
  .load_isr(insn_isr),
  .load_bar(insn_bar),
  .cpop(insn_cpop),
  .cpush(insn_cpush),
  .byt(insn_byt),
  .rd_mem(insn_rd),
  .wr_mem(insn_wr),
  .set_ien(insn_set_ien),
  .clear_ien(insn_clear_ien)
);

logic reload_ip;
assign reload_ip = (insn_ip | irq_pend) & phase_exec;

logic phase_half;
assign phase_half = phase_decode | phase_exec;

always @(posedge rst, posedge clk) begin
  if (rst)
    irq_pend <= 1'b0;
  else if (phase_fetch)
    irq_pend <= irq;
end

endmodule
