module cpu(
  input rst,
  input clk,
  input [15:0] insn,
  output logic [9:0] pc,
  output [7:0] mem_addr,
  output logic mem_wr,
  input        [7:0] rd_data,
  output logic [7:0] wr_data,
  output logic [7:0] stack[0:15]
);

/*
オペコードの構成

値の範囲    役割
-----------------------
00h - 07h   PUSH/POP 系命令
08h - 0fh   メモリアクセス命令
10h - 1fh   ジャンプ命令
20h - 20h   2 項算術論理演算
21h - 21h   単項算術論理演算
ffh         無効命令


命令リスト（算術論理演算以外）

mnemonic    code  説明
------------------------------------
PUSH imm8   00h   imm8 を stack にプッシュ
POP         01h   stack をポップ
DUP 0/1     02h   stack[0/1] を stack にプッシュ
LD imm8     08h   mem[imm8] から読んだ値を stack にプッシュ
ST imm8     0ch   stack からポップした値を mem[imm8] に書く
STA         0dh   stack からアドレスと値をポップしメモリに書き、アドレスをプッシュ
                  stack[0] = addr, stack[1] = data
STD         0eh   stack からアドレスと値をポップしメモリに書き、値をプッシュ
JMP imm8    10h   pc+imm8 にジャンプ
JZ imm8     11h   stack から値をポップし、0 なら pc+imm8 にジャンプ


制御線の構成

名前  説明
-----------------------
imm   0: insn[7:0] は ALU 機能選択
      1: insn[7:0] は即値
load  演算用スタックの先頭にロードする値の選択
      0: stack[0], 1: stack[1], 2: alu_out, 3: rd_data
rd    メモリ読み込み
wr    メモリ書き込み
pop   演算用スタックから値をポップ
push  演算用スタックに値をプッシュ
jmp   ジャンプ条件
      0: ジャンプしない, 1: 無条件, 2: stack[0] == 0

imm8=insn[7:0] 即値、ALU 機能選択


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

logic [1:0] phase; // 0=命令実行 1=メモリアクセス 2=PC更新 3=時間待ち
logic [7:0] alu_out;

logic imm, rd, wr, pop, push;
logic [1:0] load, jmp;
logic [7:0] imm8;

//localparam CLK_DIVIDER=32'd2_000_000;
localparam CLK_DIVIDER=32'd1;
logic [31:0] clk_div;

assign {imm, load, rd, wr, pop, push, jmp} = decode(insn);
assign imm8 = insn[7:0];

assign alu_out = alu(imm, imm8, stack[0], stack[1]);
assign mem_addr = alu_out;

integer i;

// 演算用スタックを更新
always @(posedge clk, posedge rst) begin
  if (rst)
    for (i = 0; i < 8; i = i+1) stack[i] <= 8'd0;
  else if (phase == 2'd2) begin
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
  else if (phase != 2'd3)
    phase <= phase + 2'd1;
  else if (clk_div == CLK_DIVIDER - 1)
    phase <= 2'd0;
end

// 命令実行が完了したらプログラムカウンタを進める
always @(posedge clk, posedge rst) begin
  if (rst)
    pc <= 10'd0;
  else if (insn == 16'hffff)
    ;
  else if (phase == 2'd2)
    if ((jmp == 2'd1) ||
        (jmp == 2'd2 && stack[0] == 8'd0))
      pc <= pc + { {2{imm8[7]}}, imm8};
    else
      pc <= pc + 10'd1;
end

always @(posedge clk, posedge rst) begin
  if (rst)
    clk_div <= 32'd0;
  else if (phase == 2'd3)
    clk_div <= clk_div + 32'd1;
  else
    clk_div <= 32'd0;
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

function [8:0] decode(input [15:0] insn);
begin
  case (insn[15:8])
    //                 i l  rw pp j
    //                 m o  dr ou m
    //                 m a     ps p
    //                   d      h
    8'h00: decode = 9'b1_10_00_01_00;
    8'h01: decode = 9'b0_01_00_10_00;
    8'h02: decode = 9'b0_00_00_01_00 | (insn[0] << 6);
    8'h08: decode = 9'b1_11_10_01_00;
    8'h0c: decode = 9'b1_01_01_10_00;
    8'h0d: decode = 9'b0_00_01_10_00;
    8'h0e: decode = 9'b0_01_01_10_00;
    8'h10: decode = 9'b1_00_00_00_01;
    8'h11: decode = 9'b1_01_00_10_10;
    8'h20: decode = 9'b0_10_00_10_00;
    default: decode = 9'd0;
  endcase
end
endfunction

endmodule
