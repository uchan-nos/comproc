module cpu(
  input rst,
  input clk,
  input [15:0] insn,
  output logic [9:0] pc,
  output [7:0] mem_addr,
  output logic mem_wr,
  input        [7:0] rd_data,
  output logic [7:0] wr_data
);

/*
オペコードの構成

bit   名前  説明
------------------------------
15    imm   0: insn[7:0] は ALU 機能選択
            1: insn[7:0] は即値
14          jz
13:12 load  演算用スタックの先頭にロードする値の選択
            0: stack[0], 1: stack[1], 2: alu_out, 3: rd_data
11    rd    メモリ読み込み
10    wr    メモリ書き込み
9     pop   演算用スタックから値をポップ
8     push  演算用スタックに値をプッシュ
7:0   imm8  即値、ALU 機能選択


ALU 機能

番号  説明
----------------
00h   stack[0]
01h   stack[1]
02h   stack[0] + stack[1]
03h   stack[0] - stack[1]
04h   stack[0] * stack[1]
08h   stack[0] < stack[1]


メモリマップ

addr    説明
---------------
00h     無効
01h     UART 入出力
02h-1fh 予約
20h-ffh 一般メモリ
*/

logic [7:0] stack[0:15];
logic [1:0] phase; // 0=命令実行 1=メモリアドレス 2=メモリアクセス 3=PC更新
logic [7:0] alu_out;

logic imm, jz, rd, wr, pop, push;
logic [1:0] load;
logic [7:0] imm8;

assign imm = insn[15];
assign jz = insn[14];
assign load = insn[13:12];
assign rd = insn[11];
assign wr = insn[10];
assign pop = insn[9];
assign push = insn[8];
assign imm8 = insn[7:0];

assign alu_out = alu(imm, imm8, stack[0], stack[1]);
assign mem_addr = alu_out;

integer i;

// 演算用スタックを更新
always @(posedge clk, posedge rst) begin
  if (rst)
    for (i = 0; i < 8; i = i+1) stack[i] <= 8'd0;
  else if (phase == 2'd3) begin
    /*
    if (load)
      stack[0] <= rd ? rd_data : alu_out;
    else
      stack[0] <= stack[1];
    */
    case (load)
      2'd0: stack[0] <= stack[0];
      2'd1: stack[0] <= stack[1];
      2'd2: stack[0] <= alu_out;
      2'd3: stack[0] <= rd_data;
    endcase

    if (~pop & push)
      for (i = 1; i < 8; i = i+1) stack[i] <= stack[i - 1];
    if (pop & ~push)
      for (i = 1; i < 7; i = i+1) stack[i] <= stack[i + 1];
  end
end

// メモリ書き込み命令だったら mem_wr を有効化する
always @(posedge clk, posedge rst) begin
  if (rst)
    mem_wr <= 1'b0;
  else if (phase == 2'd1 && wr)
    mem_wr <= 1'b1;
  else
    mem_wr <= 1'b0;
end

// メモリに書き込むためのデータを wr_data に設定
always @(posedge clk, posedge rst) begin
  if (rst)
    wr_data <= 8'd0;
  else if (phase == 2'd1)
    wr_data <= imm ? stack[0] : stack[1];
end

// 命令実行フェーズを更新
always @(posedge clk, posedge rst) begin
  if (rst)
    phase <= 2'd0;
  else
    phase <= phase + 2'd1;
end

// 命令実行が完了したらプログラムカウンタを進める
always @(posedge clk, posedge rst) begin
  if (rst)
    pc <= 10'd0;
  else if (insn == 16'hffff)
    ;
  else if (phase == 2'd2)
    pc <= pc + 10'd1;
end

// jz ビットが 1 なら条件ジャンプ
always @(posedge clk, posedge rst) begin
  if (rst)
    ;
  else if (phase == 2'd0 && jz && stack[0] == 8'd0)
    pc <= imm;
end

// ALU 本体
function [7:0] alu(
  input imm,
  input [7:0] imm8,
  input [7:0] stack0,
  input [7:0] stack1);
begin
  if (imm)
    alu = imm8;
  else
    case (imm8)
      8'h00: alu = stack0;
      8'h01: alu = stack1;
      8'h02: alu = stack0 + stack1;
      8'h03: alu = stack0 - stack1;
      8'h04: alu = stack0 * stack1;
      8'h08: alu = stack0 < stack1;
    endcase
end
endfunction

endmodule
