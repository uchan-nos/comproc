`include "common.sv"

module decoder(
  input [15:0] insn,
  output imm,
  output [15:0] imm_mask,
  output [1:0] src_a,
  output [5:0] alu_sel,
  output wr_stk1,
  output load,
  output pop,
  output push,
  output load_fp,
  output load_ip,
  output byt,
  output wr
);

`define src_stk0 2'h0
`define src_fp   2'h1
`define src_ip   2'h2
`define src_cstk 2'h3
`define src_x    2'hx

assign imm = insn[15:12] !== 4'hf;
assign imm_mask = calc_imm_mask(insn[15:12]);

function [15:0] calc_imm_mask(input [3:0] op);
begin
  casex (op)
    4'b0xxx: calc_imm_mask = 16'h7fff;
    4'b100x: calc_imm_mask = 16'h0ffe;
    4'b101x: calc_imm_mask = 16'h03fe;
    default: calc_imm_mask = 16'h03ff;
  endcase
end
endfunction

function [1:0] calc_src_a(input [15:0] insn);
begin
  casex (insn[15:12])
    4'b100x: calc_src_a = `src_ip;
    4'b101x: calc_src_a = insn[11:10];
    4'b1100: calc_src_a = insn[11:10];
    4'b1101: calc_src_a = `src_fp;
    4'b1111: calc_src_a = calc_src_a_no_imm(insn);
    default: calc_src_a = 2'h0;
  endcase
end
endfunction

function [1:0] calc_src_a_no_imm(input [15:0] insn);
begin
  casex (insn[11:10])
    2'h1: calc_src_a_no_imm = `src_cstk;
    4'b101x: calc_src_a = insn[11:10];
    4'b1100: calc_src_a = insn[11:10];
    4'b1101: calc_src_a = `src_fp;
    4'b1111: calc_src_a = calc_src_a_no_imm(insn);
  endcase
end
endfunction

endmodule
