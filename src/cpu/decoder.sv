`include "common.sv"

module decoder(
  input [15:0] insn,
  output imm,
  output [15:0] imm_mask,
  output [1:0] src_a,
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

`define src_stk0 2'h0
`define src_fp   2'h1
`define src_ip   2'h2
`define src_cstk 2'h3
`define src_x    2'hx

assign imm = insn[15:12] !== 4'h7;
assign imm_mask = calc_imm_mask(insn[15:12]);
assign src_a = calc_src_a(insn);
assign alu_sel = calc_alu_sel(insn);
assign wr_stk1 = insn[15:12] === 4'h7 & insn[3];
assign pop = calc_pop(insn);
assign push = calc_push(insn);
assign load_stk = calc_load_stk(insn);
assign load_fp = calc_load_fp(insn);
assign load_ip = calc_load_ip(insn);
assign cpop = calc_cpop(insn);
assign cpush = calc_cpush(insn);
assign byt = insn[0];
assign rd_mem = calc_rd_mem(insn);
assign wr_mem = calc_wr_mem(insn);

function [15:0] calc_imm_mask(input [3:0] op);
begin
  casex (op)
    4'b1xxx: calc_imm_mask = 16'h7fff;
    4'b000x: calc_imm_mask = 16'h0ffe;
    4'b001x: calc_imm_mask = 16'h03fe;
    default: calc_imm_mask = 16'h03ff;
  endcase
end
endfunction

function [1:0] calc_src_a(input [15:0] insn);
begin
  casex (insn[15:12])
    4'b000x: calc_src_a = `src_ip;
    4'b001x: calc_src_a = insn[11:10];
    4'b0100: calc_src_a = insn[11:10];
    4'b0101: calc_src_a = `src_fp;
    4'b0111: calc_src_a = calc_src_a_no_imm(insn);
    default: calc_src_a = 2'h0;
  endcase
end
endfunction

function [1:0] calc_src_a_no_imm(input [15:0] insn);
begin
  if (insn[11])
    casex (insn[3:0])
      4'b00x0: calc_src_a_no_imm = `src_cstk;
      4'b0011: calc_src_a_no_imm = `src_fp;
      default: calc_src_a_no_imm = `src_stk0;
    endcase
  else
    calc_src_a_no_imm = `src_stk0;
end
endfunction

function [5:0] calc_alu_sel(input [15:0] insn);
begin
  casex (insn[15:12])
    4'b1xxx: calc_alu_sel = 6'h0f;
    4'b00xx: calc_alu_sel = 6'h20;
    4'b010x: calc_alu_sel = 6'h20;
    default: calc_alu_sel = insn[11:10] == 2'h0 ? insn[5:0] : 6'h00;
  endcase
end
endfunction

function calc_rd_mem(input [15:0] insn);
begin
  casex (insn[15:12])
    4'b00xx: calc_rd_mem = 1'b1;
    4'b0111: calc_rd_mem = insn[11] & (insn[3:2] === 2'b10);
    default: calc_rd_mem = 1'b0;
  endcase
end
endfunction

function calc_pop(input [15:0] insn);
begin
  casex (insn[15:12])
    4'b00x1: calc_pop = 1'b1;
    4'b0111: calc_pop = (~insn[11] & insn[6]) | (insn[11] & insn[2]);
    default: calc_pop = 1'b0;
  endcase
end
endfunction

function calc_push(input [15:0] insn);
begin
  casex (insn[15:12])
    4'b1xxx: calc_push = 1'b1;
    4'b0010: calc_push = 1'b1;
    4'b0100: calc_push = 1'b1;
    4'b0111: calc_push = insn[7];
    default: calc_push = 1'b0;
  endcase
end
endfunction

function calc_load_stk(input [15:0] insn);
begin
  if (calc_push(insn))
    calc_load_stk = 1'b1;
  else if (insn[15:12] === 4'h7)
    calc_load_stk = ~insn[11] | (insn[3] & ~insn[1]);
  else
    calc_load_stk = 1'b0;
end
endfunction

function calc_load_fp(input [15:0] insn);
begin
  casex (insn[15:12])
    4'b0101: calc_load_fp = 1'b1;
    4'b0111: calc_load_fp = insn[11] & insn[3:0] === 4'b0010;
    default: calc_load_fp = 1'b0;
  endcase
end
endfunction

function calc_load_ip(input [15:0] insn);
begin
  casex (insn[15:12])
    4'b000x: calc_load_ip = 1'b1;
    4'b0111: calc_load_ip = insn[11] & insn[3:0] === 4'b0000;
    default: calc_load_ip = 1'b0;
  endcase
end
endfunction

function calc_cpop(input [15:0] insn);
begin
  if (insn[15:11] === 5'b01111)
    casex (insn[3:0])
      4'b00x0: calc_cpop = 1'b1;
      default: calc_cpop = 1'b0;
    endcase
  else
    calc_cpop = 1'b0;
end
endfunction

function calc_cpush(input [15:0] insn);
begin
  casex (insn[15:12])
    4'b0000: calc_cpush = ((insn[15:12] === 4'b0000) & insn[0]);
    4'b0111: calc_cpush = (insn[11] & (insn[3:0] === 4'b0011));
    default: calc_cpush = 1'b0;
  endcase
end
endfunction

function calc_wr_mem(input [15:0] insn);
begin
  casex (insn[15:12])
    4'b0011: calc_wr_mem = 1'b1;
    4'b0111: calc_wr_mem = insn[11] & insn[3:2] === 2'b11;
    default: calc_wr_mem = 1'b0;
  endcase
end
endfunction

endmodule
