`include "common.sv"

module decoder(
  input [15:0] insn,
  output sign,
  output [15:0] imm_mask,
  output [2:0] src_a,
  output [1:0] src_b,
  output [5:0] alu_sel,
  output wr_stk1,
  output pop,
  output push,
  output load_stk,
  output load_fp,
  output load_ip,
  output load_isr,
  output load_bar,
  output cpop,
  output cpush,
  output byt,
  output rd_mem,
  output wr_mem,
  output set_ien, clear_ien
);

assign imm_mask = calc_imm_mask(insn[15:12]);

assign {sign, src_a, src_b, alu_sel,
  load_stk, load_fp, load_ip, load_isr, load_bar,
  push, pop, cpush, cpop,
  wr_stk1, byt, rd_mem, wr_mem,
  set_ien, clear_ien} = decode(insn);

`define STK0 `SRCA_STK0
`define BAR  `SRCA_BAR
`define IP   `SRCA_IP
`define CSTK `SRCA_CSTK
`define FP   `SRCA_FP

`define STK1 `SRC_STK1
`define IMM  `SRC_IMM
`define ISR  `SRC_ISR

// 27bits = sign:1 + src_a:3 + src_b:2 + alu:6 + signals:15
function [27:0] decode(input [15:0] insn);
  logic sign;
  logic [2:0] src_a;
  logic [9:0] pp;
  logic [4:0] load;
  sign = insn[11];
  src_a = {1'b0, insn[11:10]};
  pp = {insn[7:6], 8'd0};
  load = src_a === `IP;

  casex (insn)
                             //                    set_ien/clear_ien
                             //         wr_stk1/byt/rd_mem/wr_mem ||
                             //          push/pop/cpush/cpop |  | ||
                             //  load_stk/fp/ip/isr/bar |  | |  | ||
    16'b1xxx_xxxx_xxxx_xxxx: // PUSH uimm15       |___| |__| |__| ||
      return {1'b0, `STK0, `IMM,  `ALU_B,     15'b10000_1000_0000_00};
    16'b0000_xxxx_xxxx_xxx0: // JMP simm12
      return {sign, `IP,   `IMM,  `ALU_ADD,   15'b00100_0000_0000_00};
    16'b0000_xxxx_xxxx_xxx1: // CALL simm12
      return {sign, `IP,   `IMM,  `ALU_ADD,   15'b00100_0010_0000_00};
    16'b0001_xxxx_xxxx_xxx0: // JZ simm12
      return {sign, `IP,   `IMM,  `ALU_ADDZ,  15'b00100_0100_0000_00};
    16'b0001_xxxx_xxxx_xxx1: // JNZ simm12
      return {sign, `IP,   `IMM,  `ALU_ADDNZ, 15'b00100_0100_0000_00};
    16'b0010_00xx_xxxx_xxxx: // LD1 0+uimm10
      return {1'b0, src_a, `IMM,  `ALU_B,     15'b10000_1000_0110_00};
    16'b0010_xxxx_xxxx_xxxx: // LD1 X+uimm10
      return {1'b0, src_a, `IMM,  `ALU_ADD,   15'b10000_1000_0110_00};
    16'b0011_00xx_xxxx_xxxx: // ST1 0+uimm10
      return {1'b0, src_a, `IMM,  `ALU_B,     15'b00000_0100_0101_00};
    16'b0011_xxxx_xxxx_xxxx: // ST1 X+uimm10
      return {1'b0, src_a, `IMM,  `ALU_ADD,   15'b00000_0100_0101_00};
    16'b0100_00xx_xxxx_xxx0: // LD 0+uimm10
      return {1'b0, src_a, `IMM,  `ALU_B,     15'b10000_1000_0010_00};
    16'b0100_xxxx_xxxx_xxx0: // LD X+uimm10
      return {1'b0, src_a, `IMM,  `ALU_ADD,   15'b10000_1000_0010_00};
    16'b0100_00xx_xxxx_xxx1: // ST 0+uimm10
      return {1'b0, src_a, `IMM,  `ALU_B,     15'b00000_0100_0001_00};
    16'b0100_xxxx_xxxx_xxx1: // ST X+uimm10
      return {1'b0, src_a, `IMM,  `ALU_ADD,   15'b00000_0100_0001_00};
    16'b0101_xxxx_xxxx_xxxx: // PUSH X+uimm10
      return {1'b0, src_a, `IMM,  `ALU_ADD,   15'b10000_1000_0000_00};
    16'b0110_01xx_xxxx_xxxx: // ADD FP,uimm10
      return {1'b0, `FP,   `IMM,  `ALU_ADD,   15'b01000_0000_0000_00};
    16'b0111_0xxx_xxxx_xxxx: // stack だけを使う演算形命令
      return {1'b0, `STK0, `STK1, insn[5:0],  15'b10000_0000_0000_00 | pp};
                             //                    set_ien/clear_ien
                             //         wr_stk1/byt/rd_mem/wr_mem ||
                             //          push/pop/cpush/cpop |  | ||
                             //  load_stk/fp/ip/isr/bar |  | |  | ||
    16'b0111_1xxx_xx00_0x0x: // RET               |___| |__| |__| ||
      return {1'b0, `CSTK, `IMM,  `ALU_A,     15'b00100_0001_0000_00};
    16'b0111_1xxx_xx00_0x10: // CPOP FP
      return {1'b0, `CSTK, `IMM,  `ALU_A,     15'b01000_0001_0000_00};
    16'b0111_1xxx_xx00_0x11: // CPUSH FP
      return {1'b0, `FP,   `IMM,  `ALU_A,     15'b00000_0010_0000_00};
    16'b0111_1xxx_xx00_10x0: // LDD
      return {1'b0, `STK0, `IMM,  `ALU_A,     15'b10000_0000_0010_00};
    16'b0111_1xxx_xx00_1100: // STA
      return {1'b0, `STK0, `IMM,  `ALU_A,     15'b10000_0100_1001_00};
    16'b0111_1xxx_xx00_1110: // STD
      return {1'b0, `STK0, `IMM,  `ALU_A,     15'b00000_0100_1001_00};
    16'b0111_1xxx_xx00_10x1: // LDD1
      return {1'b0, `STK0, `IMM,  `ALU_A,     15'b10000_0000_0110_00};
    16'b0111_1xxx_xx00_1101: // STA1
      return {1'b0, `STK0, `IMM,  `ALU_A,     15'b10000_0100_1101_00};
    16'b0111_1xxx_xx00_1111: // STD1
      return {1'b0, `STK0, `IMM,  `ALU_A,     15'b00000_0100_1101_00};
    16'b0111_1xxx_xxx1_xx0x: // INT
      return {1'b0, `IP,   `ISR,  `ALU_B,     15'b00100_0010_0000_00};
    16'b0111_1xxx_xxx1_xx1x: // IRET
      return {1'b0, `CSTK, `IMM,  `ALU_A,     15'b00100_0001_0000_10};
    16'b0111_1xxx_xx1x_xx00: // POP FP
      return {1'b0, `STK0, `IMM,  `ALU_A,     15'b01000_0100_0000_00};
    16'b0111_1xxx_xx1x_xx01: // POP IP
      return {1'b0, `STK0, `IMM,  `ALU_A,     15'b00100_0100_0000_00};
    16'b0111_1xxx_xx1x_xx10: // POP ISR
      return {1'b0, `STK0, `IMM,  `ALU_A,     15'b00010_0100_0000_00};
    16'b0111_1xxx_xx1x_xx11: // POP BAR
      return {1'b0, `STK0, `IMM,  `ALU_A,     15'b00001_0100_0000_00};
  endcase
endfunction

function [15:0] calc_imm_mask(input [3:0] op);
begin
  casex (op)
    4'b1xxx: return 16'h7fff;
    4'b000x: return 16'h0ffe;
    4'b0100: return 16'h03fe;
    default: return 16'h03ff;
  endcase
end
endfunction

endmodule
