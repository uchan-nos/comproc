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
  output load_stk,
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
assign src_a = calc_src_a(insn);
assign alu_sel = calc_alu_sel(insn);
assign wr_stk1 = insn[15:12] === 4'hf & insn[3];
assign load = calc_load(insn);
assign pop = calc_pop(insn);
assign push = calc_push(insn);
assign load_stk = calc_load_stk(insn);
assign load_fp = calc_load_fp(insn);
assign load_ip = calc_load_ip(insn);
assign byt = insn[0];
assign wr = calc_wr(insn);

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
  casex ({insn[11:10], insn[7:6]})
    4'b0110: calc_src_a_no_imm = `src_fp;
    4'b01xx: calc_src_a_no_imm = `src_cstk;
    default: calc_src_a_no_imm = `src_stk0;
  endcase
end
endfunction

function [5:0] calc_alu_sel(input [15:0] insn);
begin
  casex (insn[15:12])
    4'b0xxx: calc_alu_sel = 6'h0f;
    4'b10xx: calc_alu_sel = 6'h20;
    4'b110x: calc_alu_sel = 6'h20;
    default: calc_alu_sel = insn[11:10] == 2'h0 ? insn[5:0] : 6'h00;
  endcase
end
endfunction

function calc_load(input [15:0] insn);
begin
  casex (insn[15:12])
    4'b10xx: calc_load = 1'b1;
    4'b1111: calc_load = insn[11] & (insn[3:2] === 2'b10);
    default: calc_load = 1'b0;
  endcase
end
endfunction

function calc_pop(input [15:0] insn);
begin
  casex (insn[15:12])
    4'b10x1: calc_pop = 1'b1;
    4'b1111: calc_pop = (~insn[11] & insn[6]) | (insn[11] & insn[2]);
    default: calc_pop = 1'b0;
  endcase
end
endfunction

function calc_push(input [15:0] insn);
begin
  casex (insn[15:12])
    4'b0xxx: calc_push = 1'b1;
    4'b1010: calc_push = 1'b1;
    4'b1100: calc_push = 1'b1;
    4'b1111: calc_push = insn[7];
    default: calc_push = 1'b0;
  endcase
end
endfunction

function calc_load_stk(input [15:0] insn);
begin
  if (calc_push(insn))
    calc_load_stk = 1'b1;
  else if (insn[15:12] === 4'hf)
    calc_load_stk = ~insn[11] | (insn[3] & ~insn[1]);
  else
    calc_load_stk = 1'b0;
end
endfunction

function calc_load_fp(input [15:0] insn);
begin
  casex (insn[15:12])
    4'b1101: calc_load_fp = 1'b1;
    4'b1111: calc_load_fp = insn[11] & insn[3:0] === 4'b0010;
    default: calc_load_fp = 1'b0;
  endcase
end
endfunction

function calc_load_ip(input [15:0] insn);
begin
  casex (insn[15:12])
    4'b100x: calc_load_ip = 1'b1;
    4'b1111: calc_load_ip = insn[11] & insn[3:0] === 4'b0000;
    default: calc_load_ip = 1'b0;
  endcase
end
endfunction

function calc_wr(input [15:0] insn);
begin
  casex (insn[15:12])
    4'b1011: calc_wr = 1'b1;
    4'b1111: calc_wr = insn[11] & insn[3:2] === 2'b11;
    default: calc_wr = 1'b0;
  endcase
end
endfunction

endmodule
