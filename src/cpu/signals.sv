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

logic phase_decode, phase_exec, phase_rdmem, phase_fetch;
signalizer signalizer(.*);

endmodule
