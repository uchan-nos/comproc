`include "common.sv"

module decoder(
  input [15:0] insn,
  output sign,
  output [15:0] imm_mask,
  output [1:0] src_a,
  output [1:0] src_b,
  output [5:0] alu_sel,
  output wr_stk1,
  output pop,
  output push,
  output load_stk,
  output load_fp,
  output load_ip,
  output load_isr,
  output cpop,
  output cpush,
  output byt,
  output rd_mem,
  output wr_mem,
  output set_ien, clear_ien
);

assign sign = calc_sign(insn);
assign imm_mask = calc_imm_mask(insn[15:12]);
assign src_a = calc_src_a(insn);
assign src_b = calc_src_b(insn);
assign alu_sel = calc_alu_sel(insn);
assign wr_stk1 = src_b === `SRC_STK1 & insn[3];
assign pop = calc_pop(insn);
assign push = calc_push(insn);
assign load_stk = calc_load_stk(insn);
assign load_fp = calc_load_fp(insn);
assign load_ip = calc_load_ip(insn);
assign load_isr = insn[15:0] === 16'h7811;
assign cpop = calc_cpop(insn);
assign cpush = calc_cpush(insn);
assign byt = calc_byt(insn);
assign rd_mem = calc_rd_mem(insn);
assign wr_mem = calc_wr_mem(insn);
assign set_ien = insn === 16'h7812;
assign clear_ien = 1'b0;

function [15:0] calc_sign(input [15:0] insn);
begin
  casex (insn)
    16'b000x_xxxx_xxxx_xxxx: calc_sign = insn[11];
    default:                 calc_sign = 1'b0;
  endcase
end
endfunction

function [15:0] calc_imm_mask(input [3:0] op);
begin
  casex (op)
    4'b1xxx: calc_imm_mask = 16'h7fff;
    4'b000x: calc_imm_mask = 16'h0ffe;
    4'b0100: calc_imm_mask = 16'h03fe;
    default: calc_imm_mask = 16'h03ff;
  endcase
end
endfunction

function [1:0] calc_src_a(input [15:0] insn);
begin
  casex (insn)
    16'b000x_xxxx_xxxx_xxxx: calc_src_a = `SRC_IP;     // JMP, CALL, JZ, JNZ
    16'b001x_xxxx_xxxx_xxxx: calc_src_a = insn[11:10]; // LD.1, ST.1
    16'b010x_xxxx_xxxx_xxxx: calc_src_a = insn[11:10]; // LD, ST, PUSH
    16'b0110_01xx_xxxx_xxxx: calc_src_a = `SRC_FP;     // ADD FP
    16'b0111_1xxx_xxx1_xx1x: calc_src_a = `SRC_CSTK;   // IRET
    16'b0111_1xxx_xxx1_xxx0: calc_src_a = `SRC_IP;     // INT
    16'b0111_1xxx_xxxx_00x0: calc_src_a = `SRC_CSTK;   // RET, CPOP FP
    16'b0111_1xxx_xxxx_0011: calc_src_a = `SRC_FP;     // CPUSH FP
    default:                 calc_src_a = `SRC_STK0;
  endcase
end
endfunction

function [1:0] calc_src_b(input [15:0] insn);
begin
  casex (insn)
    16'b0111_1xxx_xxx1_xxxx: calc_src_b = `SRC_ISR;    // INT
    16'b0111_xxxx_xxxx_xxxx: calc_src_b = `SRC_STK1;
    default:                 calc_src_b = `SRC_IMM;
  endcase
end
endfunction

function [5:0] calc_alu_sel(input [15:0] insn);
begin
  casex (insn)
    16'b1xxx_xxxx_xxxx_xxxx: calc_alu_sel = `ALU_B;    // PUSH
    16'b0001_xxxx_xxxx_xxx0: calc_alu_sel = `ALU_ADDZ; // JZ
    16'b0001_xxxx_xxxx_xxx1: calc_alu_sel = `ALU_ADDNZ;// JNZ
    16'b001x_00xx_xxxx_xxxx: calc_alu_sel = `ALU_B;    // LD.1 etc X=0
    16'b010x_00xx_xxxx_xxxx: calc_alu_sel = `ALU_B;    // LD etc X=0
    16'b0110_00xx_xxxx_xxxx: calc_alu_sel = `ALU_B;    // ICALL
    16'b0111_0xxx_xxxx_xxxx: calc_alu_sel = insn[5:0]; // ALU
    16'b0111_1xxx_xxx1_xx00: calc_alu_sel = `ALU_B;    // INT
    16'b0111_1xxx_xxxx_xxxx: calc_alu_sel = `ALU_A;    // CSTK, MEM, ISR, IRET
    default:                 calc_alu_sel = `ALU_ADD;
  endcase
end
endfunction

function calc_rd_mem(input [15:0] insn);
begin
  casex (insn)
    16'b0010_xxxx_xxxx_xxxx: calc_rd_mem = 1'b1; // LD.1
    16'b0100_xxxx_xxxx_xxx0: calc_rd_mem = 1'b1; // LD
    16'b0110_00xx_xxxx_xxxx: calc_rd_mem = 1'b1;
    16'b0111_1xxx_xxxx_10xx: calc_rd_mem = 1'b1; // LDD, LDD.1
    default:                 calc_rd_mem = 1'b0;
  endcase
end
endfunction

function calc_pop(input [15:0] insn);
begin
  casex (insn)
    16'b0001_xxxx_xxxx_xxxx: calc_pop = 1'b1; // JZ, JNZ
    16'b0011_xxxx_xxxx_xxxx: calc_pop = 1'b1; // ST.1
    16'b0100_xxxx_xxxx_xxx1: calc_pop = 1'b1; // ST
    16'b0111_0xxx_x1xx_xxxx: calc_pop = 1'b1; // ALU pop=1
    16'b0111_1xxx_xxxx_x1xx: calc_pop = 1'b1; // STA, STD
    16'b0111_1xxx_xxx1_xxx1: calc_pop = 1'b1; // ISR
    default:                 calc_pop = 1'b0;
  endcase
end
endfunction

function calc_push(input [15:0] insn);
begin
  casex (insn)
    16'b1xxx_xxxx_xxxx_xxxx: calc_push = 1'b1; // PUSH
    16'b0010_xxxx_xxxx_xxxx: calc_push = 1'b1; // LD.1
    16'b0100_xxxx_xxxx_xxx0: calc_push = 1'b1; // LD
    16'b0101_xxxx_xxxx_xxxx: calc_push = 1'b1; // PUSH
    16'b0111_xxxx_1xxx_xxxx: calc_push = 1'b1; // ALU push=1
    default:                 calc_push = 1'b0;
  endcase
end
endfunction

function calc_load_stk(input [15:0] insn);
begin
  casex (insn)
    16'b0111_0xxx_xxxx_xxxx: calc_load_stk = 1'b1; // ALU
    16'b0111_1xxx_xxxx_1x0x: calc_load_stk = 1'b1; // LDD, STA
    default:                 calc_load_stk = calc_push(insn);
  endcase
end
endfunction

function calc_load_fp(input [15:0] insn);
begin
  casex (insn)
    16'b0110_01xx_xxxx_xxxx: calc_load_fp = 1'b1;
    16'b0111_1xxx_xxx0_0010: calc_load_fp = 1'b1;
    default:                 calc_load_fp = 1'b0;
  endcase
end
endfunction

function calc_load_ip(input [15:0] insn);
begin
  casex (insn)
    16'b000x_xxxx_xxxx_xxxx: calc_load_ip = 1'b1;
    16'b0110_00xx_xxxx_xxxx: calc_load_ip = 1'b1;
    16'b0111_1xxx_xxxx_0000: calc_load_ip = 1'b1;
    16'b0111_1xxx_xxx1_0010: calc_load_ip = 1'b1;
    default:                 calc_load_ip = 1'b0;
  endcase
end
endfunction

function calc_cpop(input [15:0] insn);
begin
  casex (insn)
    16'b0111_1xxx_xxx0_00x0: calc_cpop = 1'b1;
    16'b0111_1xxx_xxx1_xx1x: calc_cpop = 1'b1;
    default:                 calc_cpop = 1'b0;
  endcase
end
endfunction

function calc_cpush(input [15:0] insn);
begin
  casex (insn)
    16'b0000_xxxx_xxxx_xxx1: calc_cpush = 1'b1;
    16'b0110_00xx_xxxx_xxxx: calc_cpush = 1'b1;
    16'b0111_1xxx_xxx1_xx00: calc_cpush = 1'b1;
    16'b0111_1xxx_xxxx_0011: calc_cpush = 1'b1;
    default:                 calc_cpush = 1'b0;
  endcase
end
endfunction

function calc_byt(input [15:0] insn);
begin
  casex (insn)
    16'b001x_xxxx_xxxx_xxxx: calc_byt = 1'b1;
    16'b0111_xxxx_xxxx_xxx1: calc_byt = 1'b1;
    default:                 calc_byt = 1'b0;
  endcase
end
endfunction

function calc_wr_mem(input [15:0] insn);
begin
  casex (insn)
    16'b0011_xxxx_xxxx_xxxx: calc_wr_mem = 1'b1; // ST.1
    16'b0100_xxxx_xxxx_xxx1: calc_wr_mem = 1'b1; // ST
    16'b0111_1xxx_xxxx_11xx: calc_wr_mem = 1'b1;
    default:                 calc_wr_mem = 1'b0;
  endcase
end
endfunction

endmodule
