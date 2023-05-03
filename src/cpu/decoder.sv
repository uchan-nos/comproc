`include "common.sv"

module decoder(
  input [15:0] insn,
  output imm,
  output sign,
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
assign sign = calc_sign(insn);
assign imm_mask = calc_imm_mask(insn[15:12]);
assign src_a = calc_src_a(insn);
assign alu_sel = calc_alu_sel(insn);
assign wr_stk1 = ~imm & insn[3];
assign pop = calc_pop(insn);
assign push = calc_push(insn);
assign load_stk = calc_load_stk(insn);
assign load_fp = calc_load_fp(insn);
assign load_ip = calc_load_ip(insn);
assign cpop = calc_cpop(insn);
assign cpush = calc_cpush(insn);
assign byt = insn[14] & insn[0];
assign rd_mem = calc_rd_mem(insn);
assign wr_mem = calc_wr_mem(insn);

function [15:0] calc_sign(input [15:0] insn);
begin
  casex (insn)
    16'b000x_xxxx_xxxx_xxxx: calc_sign = insn[11];
    16'b001x_xxxx_xxxx_xxxx: calc_sign = insn[9];
    16'b0100_xxxx_xxxx_xxxx: calc_sign = insn[9];
    default:                 calc_sign = 1'b0;
  endcase
end
endfunction

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
  casex (insn)
    16'b000x_xxxx_xxxx_xxxx: calc_src_a = `src_ip;
    16'b001x_xxxx_xxxx_xxxx: calc_src_a = insn[11:10];
    16'b0100_xxxx_xxxx_xxxx: calc_src_a = `src_fp;
    16'b0111_1xxx_xxxx_00x0: calc_src_a = `src_cstk;
    16'b0111_1xxx_xxxx_0011: calc_src_a = `src_fp;
    default:                 calc_src_a = `src_stk0;
  endcase
end
endfunction

function [5:0] calc_alu_sel(input [15:0] insn);
begin
  casex (insn)
    16'b1xxx_xxxx_xxxx_xxxx: calc_alu_sel = `ALU_B;
    16'b0001_xxxx_xxxx_xxx0: calc_alu_sel = `ALU_ADDZ;
    16'b0001_xxxx_xxxx_xxx1: calc_alu_sel = `ALU_ADDNZ;
    16'b001x_00xx_xxxx_xxxx: calc_alu_sel = `ALU_B;   // X=0
    16'b0111_0xxx_xxxx_xxxx: calc_alu_sel = insn[5:0];
    16'b0111_1xxx_xxxx_xxxx: calc_alu_sel = `ALU_A;
    default:                 calc_alu_sel = `ALU_ADD;
  endcase
end
endfunction

function calc_rd_mem(input [15:0] insn);
begin
  casex (insn)
    16'b000x_xxxx_xxxx_xxxx: calc_rd_mem = 1'b1;
    16'b0010_xxxx_xxxx_xxx0: calc_rd_mem = 1'b1;
    16'b0111_1xxx_xxxx_10xx: calc_rd_mem = 1'b1;
    default:                 calc_rd_mem = 1'b0;
  endcase
end
endfunction

function calc_pop(input [15:0] insn);
begin
  casex (insn)
    16'b0001_xxxx_xxxx_xxxx: calc_pop = 1'b1;
    16'b0010_xxxx_xxxx_xxx1: calc_pop = 1'b1;
    16'b0111_0xxx_x1xx_xxxx: calc_pop = 1'b1;
    16'b0111_1xxx_xxxx_x1xx: calc_pop = 1'b1;
    default:                 calc_pop = 1'b0;
  endcase
end
endfunction

function calc_push(input [15:0] insn);
begin
  casex (insn)
    16'b1xxx_xxxx_xxxx_xxxx: calc_push = 1'b1;
    16'b0010_xxxx_xxxx_xxx0: calc_push = 1'b1;
    16'b0011_xxxx_xxxx_xxxx: calc_push = 1'b1;
    16'b0111_xxxx_1xxx_xxxx: calc_push = 1'b1;
    default:                 calc_push = 1'b0;
  endcase
end
endfunction

function calc_load_stk(input [15:0] insn);
begin
  casex (insn)
    16'b0111_0xxx_xxxx_xxxx: calc_load_stk = 1'b1;
    16'b0111_1xxx_xxxx_1x0x: calc_load_stk = 1'b1;
    default:                 calc_load_stk = calc_push(insn);
  endcase
end
endfunction

function calc_load_fp(input [15:0] insn);
begin
  casex (insn)
    16'b0100_xxxx_xxxx_xxxx: calc_load_fp = 1'b1;
    16'b0111_1xxx_xxxx_0010: calc_load_fp = 1'b1;
    default:                 calc_load_fp = 1'b0;
  endcase
end
endfunction

function calc_load_ip(input [15:0] insn);
begin
  casex (insn)
    16'b000x_xxxx_xxxx_xxxx: calc_load_ip = 1'b1;
    16'b0111_1xxx_xxxx_0000: calc_load_ip = 1'b1;
    default:                 calc_load_ip = 1'b0;
  endcase
end
endfunction

function calc_cpop(input [15:0] insn);
begin
  casex (insn)
    16'b0111_1xxx_xxxx_00x0: calc_cpop = 1'b1;
    default:                 calc_cpop = 1'b0;
  endcase
end
endfunction

function calc_cpush(input [15:0] insn);
begin
  casex (insn)
    16'b0000_xxxx_xxxx_xxx1: calc_cpush = 1'b1;
    16'b0111_1xxx_xxxx_0011: calc_cpush = 1'b1;
    default:                 calc_cpush = 1'b0;
  endcase
end
endfunction

function calc_wr_mem(input [15:0] insn);
begin
  casex (insn)
    16'b0010_xxxx_xxxx_xxx1: calc_wr_mem = 1'b1;
    16'b0111_1xxx_xxxx_11xx: calc_wr_mem = 1'b1;
    default:                 calc_wr_mem = 1'b0;
  endcase
end
endfunction

endmodule
