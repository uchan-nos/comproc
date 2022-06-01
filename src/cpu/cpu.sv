`include "common.sv"

module cpu(
  input rst,
  input clk,
  output [`ADDR_WIDTH-1:0] mem_addr,
  output logic mem_wr,
  input        [15:0] rd_data,
  output logic [15:0] wr_data,
  output logic [15:0] stack[0:15]
);

/*
オペコードの構成

値の範囲    役割
-----------------------
00h - 7fh   PUSH imm15
80h - 8fh   PUSH/POP 系命令
90h - 9fh   メモリアクセス命令
a0h - afh   ジャンプ命令
b0h - b0h   2 項算術論理演算
b1h - b1h   単項算術論理演算
ffh         無効命令


命令リスト（算術論理演算以外）

mnemonic    code  説明
------------------------------------
PUSH imm15  00h   imm15 を stack にプッシュ
POP         81h   stack をポップ
DUP 0/1     82h   stack[0/1] を stack にプッシュ
LD imm8     90h   mem[imm8] から読んだ値を stack にプッシュ
LDD         91h   stack からアドレスをポップし、mem[addr] を stack にプッシュ
ST imm8     94h   stack からポップした値を mem[imm8] に書く
STA         95h   stack からアドレスと値をポップしメモリに書き、アドレスをプッシュ
                  stack[0] = addr, stack[1] = data
STD         96h   stack からアドレスと値をポップしメモリに書き、値をプッシュ
LD.B imm8   98h   byte version
LDD.B       99h   byte version
ST.B imm8   9ch   byte version
STA.B       9dh   byte version
STD.B       9eh   byte version
JMP imm8    a0h   pc+imm8 にジャンプ
JZ imm8     a1h   stack から値をポップし、0 なら pc+imm8 にジャンプ
JNZ imm8    a2h   stack から値をポップし、0 以外なら pc+imm8 にジャンプ


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
      0: ジャンプしない, 1: 無条件, 2: stack[0] == 0, 3: stack[0] != 0

imm8=insn[7:0] 即値、ALU 機能選択


ALU 機能

番号  名前  説明
----------------
00h         stack[0]
01h         stack[1]
02h   ADD   stack[0] + stack[1]
03h   SUB   stack[0] - stack[1]
04h   MUL   stack[0] * stack[1]
05h   JOIN  stack[0] | (stack[1] << 8)
06h   AND   stack[0] & stack[1]
08h   LT    stack[0] < stack[1]
09h   EQ    stack[0] == stack[1]
0ah   NEQ   stack[0] != stack[1]


メモリマップ

addr      説明
---------------
000h      無効
001h      UART 入出力
002h-01fh 予約
020h-0ffh データメモリ
100h-1ffh プログラムメモリ


信号タイミング
../../doc/signal-timing-design/cpu-mem-timing.png

タイミング図生成ツール
https://rawgit.com/osamutake/tchart-coffee/master/bin/editor-offline.html

タイミング図ソースコード
clock   ~_~_~_~_~_~_~_~_~_~_~_
phase   X3=X0=X1=X2=X3=X0=X1=X2=X3=X0=X1=
rw_addr =PC=X=addr==X=PC+1==X=addr==X=PC+2==X=addr==
rd_data =?Xinsn===Xdata===Xinsn===Xdata===Xinsn===X
wr_data =?===Xdata=X?===============
mem_wr  ____~~________________
*/

/*
3->0  命令フェッチ
0     デコード
0->1  メモリ読み込み（データ）
1->2  メモリ書き込み、PC 更新、演算スタック更新
2->3  メモリ読み込み（命令）
*/
logic [1:0] phase;
logic [15:0] alu_out;
logic [15:0] insn;
logic [`ADDR_WIDTH-1:0] pc;

logic imm, rd, wr, pop, push, byt;
logic [1:0] load, jmp;
logic [7:0] imm8;

//localparam CLK_DIVIDER=32'd2_000_000;
localparam CLK_DIVIDER=32'd1;
logic [31:0] clk_div;

assign {imm, load, rd, wr, pop, push, jmp, byt} = decode(insn);
assign imm8 = insn[7:0];

assign alu_out = alu(imm, insn, stack[0], stack[1]);
assign mem_addr = (phase <= 2'd1) ? alu_out[`ADDR_WIDTH-1:0] : pc;

integer i;

// 命令フェッチ
always @(posedge clk, posedge rst) begin
  if (rst)
    insn <= 16'd0;
  else if (phase == 2'd3)
    insn <= rd_data;
end

// 演算用スタックを更新
always @(posedge clk, posedge rst) begin
  if (rst)
    for (i = 0; i < 8; i = i+1) stack[i] <= 8'd0;
  else if (phase == 2'd1) begin
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
  else if (phase == 2'd0 && wr)
    mem_wr <= 1'b1;
  else
    mem_wr <= 1'b0;
end

// メモリに書き込むためのデータを wr_data に設定
always @(posedge clk, posedge rst) begin
  if (rst)
    wr_data <= 16'd0;
  else if (phase == 2'd0)
    if (byt)
      wr_data <= {8'd0, {imm ? stack[0][7:0] : stack[1][7:0]}};
    else
      wr_data <= imm ? stack[0] : stack[1];
end

// 命令実行フェーズを更新
always @(posedge clk, posedge rst) begin
  if (rst)
    phase <= 2'd2;
  else if (phase != 2'd3)
    phase <= phase + 2'd1;
  else if (clk_div == CLK_DIVIDER - 1)
    phase <= 2'd0;
end

// 命令実行が完了したらプログラムカウンタを進める
always @(posedge clk, posedge rst) begin
  if (rst)
    pc <= 10'h100;
  else if (insn == 16'hffff)
    ;
  else if (phase == 2'd1)
    if ((jmp == 2'd1) ||
        (jmp == 2'd2 && stack[0] == 16'd0) ||
        (jmp == 2'd3 && stack[0] != 16'd0))
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
function [15:0] alu(
  input imm,
  input [15:0] insn,
  input [15:0] stack0,
  input [15:0] stack1);
begin
  if (imm)
    if (insn[15])
      alu = {8'd0, insn[7:0]};
    else
      alu = {1'd0, insn[14:0]};
  else
    case (insn[7:0])
      8'h00: alu = stack0;
      8'h01: alu = stack1;
      8'h02: alu = stack0 + stack1;
      8'h03: alu = stack0 - stack1;
      8'h04: alu = stack0 * stack1;
      8'h05: alu = stack0 | (stack1 << 8);
      8'h06: alu = stack0 & stack1;
      8'h08: alu = stack0 < stack1;
      8'h09: alu = stack0 == stack1;
      8'h0a: alu = stack0 != stack1;
    endcase
end
endfunction

function [9:0] decode(input [15:0] insn);
begin
  casex (insn[15:8])
    //                        i l  rw pp j  b
    //                        m o  dr ou m  y
    //                        m a     ps p  t
    //                          d      h
    8'b0xxxxxxx: decode = 10'b1_10_00_01_00_0;
    8'h81:       decode = 10'b0_01_00_10_00_0;
    8'h82:       decode = 10'b0_00_00_01_00_0 | (insn[0] << 7);
    8'h90:       decode = 10'b1_11_10_01_00_0;
    8'h91:       decode = 10'b0_11_10_11_00_0;
    8'h94:       decode = 10'b1_01_01_10_00_0;
    8'h95:       decode = 10'b0_00_01_10_00_0;
    8'h96:       decode = 10'b0_01_01_10_00_0;
    8'h98:       decode = 10'b1_11_10_01_00_1;
    8'h99:       decode = 10'b0_11_10_11_00_1;
    8'h9c:       decode = 10'b1_01_01_10_00_1;
    8'h9d:       decode = 10'b0_00_01_10_00_1;
    8'h9e:       decode = 10'b0_01_01_10_00_1;
    8'ha0:       decode = 10'b1_00_00_00_01_0;
    8'ha1:       decode = 10'b1_01_00_10_10_0;
    8'ha2:       decode = 10'b1_01_00_10_11_0;
    8'hb0:       decode = 10'b0_10_00_10_00_0;
    default:     decode = 10'd0;
  endcase
end
endfunction

endmodule
