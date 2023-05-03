`include "common.sv"

module cpu#(
  parameter CLOCK_HZ = 27_000_000
) (
  input rst,
  input clk,
  output [`ADDR_WIDTH-1:0] mem_addr,
  output wr_mem,
  output byt,
  input  [15:0] rd_data,
  output [15:0] wr_data,
  output [15:0] stack0,
  output [15:0] stack1,
  output [5:0] alu_sel
);

/*
引数の仕様

wr_mem    メモリ書き込み命令のとき 1
byt       バイトアクセスなら 1
rd_data   メモリからの読み込みデータ
          byt=0 なら [15:0] が有効
          byt=1 なら、mem_addr の最下位ビットに応じて [15:8] か [7:0] が有効
wr_data   メモリへの書き込みデータ
          byt とビットの有効範囲は rd_data と同じ


命令リスト（即値有り）

mnemonic        15     87      0  説明
------------------------------------
PUSH uimm15    |1    uimm15     | uimm15 を stack にプッシュ
JMP simm12     |0000   simm11  0| pc+simm12 にジャンプ
CALL simm12    |0000   simm11  1| コールスタックに pc+2 をプッシュし、pc+simm12 にジャンプ
JZ simm12      |0001   simm11  0| stack から値をポップし、0 なら pc+simm12 にジャンプ
JNZ simm12     |0001   simm11  1| stack から値をポップし、1 なら pc+simm12 にジャンプ
LD X+simm10    |0010xx  simm9  0| mem[X+simm10] から読んだ値を stack にプッシュ
ST X+simm10    |0010xx  simm9  1| stack からポップした値を mem[X+simm10] に書く
PUSH X+simm10  |0011xx  simm10  | X+simm10 を stack にプッシュ
                                  X の選択: 0=0, 1=fp, 2=ip, 3=cstack[0]
ADD FP,simm10  |010000  simm10  | fp += simm10
               |010001xxxxxxxxxx| 予約
               |01001xxxxxxxxxxx| 予約
               |0101xxxxxxxxxxxx| 予約
               |0110xxxxxxxxxxxx| 予約
               |0111xxxxxxxxxxxx| 即値なし命令（別表）


命令リスト（即値なし）

mnemonic    15     87      0  説明
------------------------------------
NOP        |0111000000000000| stack[0] に ALU-A をロードするので、ALU=00h
POP        |0111000001001111| stack をポップ
                              stack[0] に ALU-B をロードするので、ALU=0fh
POP 1      |0111000001000000| stack[1] 以降をポップ（stack[0] を保持）
                              stack[0] に ALU-A をロードするので、ALU=00h
INC        |0111000000000001| stack[0]++
INC2       |0111000000000010| stack[0] += 2
NOT        |0111000000000100| stack[0] = ~stack[0]

AND        |0111000001010000| stack[0] &= stack[1]
OR         |0111000001010001| stack[0] |= stack[1]
XOR        |0111000001010010| stack[0] ^= stack[1]
SHR        |0111000001010100| stack[0] >>= stack[1]（符号なしシフト）
SAR        |0111000001010101| stack[0] >>= stack[1]（符号付きシフト）
SHL        |0111000001010110| stack[0] <<= stack[1]
JOIN       |0111000001010111| stack[0] |= (stack[1] << 8)

ADD        |0111000001100000| stack[0] += stack[1]
SUB        |0111000001100001| stack[0] -= stack[1]
MUL        |0111000001100010| stack[0] *= stack[1]
LT         |0111000001101000| stack[0] = stack[0] < stack[1]
EQ         |0111000001101001| stack[0] = stack[0] == stack[1]
NEQ        |0111000001101010| stack[0] = stack[0] != stack[1]

DUP        |0111000010000000| stack[0] を stack にプッシュ
DUP 1      |0111000010001111| stack[1] を stack にプッシュ
RET        |0111100000000000| コールスタックからアドレスをポップし、ジャンプ
CPOP FP    |0111100000000010| コールスタックから値をポップし FP に書く
CPUSH FP   |0111100000000011| コールスタックに FP をプッシュ
LDD        |0111100000001000| stack からアドレスをポップし、mem[addr] を stack にプッシュ
STA        |0111100000001100| stack から値とアドレスをポップしメモリに書き、アドレスをプッシュ
STD        |0111100000001110| stack から値とアドレスをポップしメモリに書き、値をプッシュ
                              stack[1] = data, stack[0] = addr
LDD.1      |0111100000001001| byte version
STA.1      |0111100000001101| byte version
STD.1      |0111100000001111| byte version


即値無し命令の構造

 15  12 11  10  8    7     6   5  4 3    0
| 0111 | 0 | 000 | Push | Pop |    ALU    |  stack だけを使う演算系命令
| 0111 | 1 | 000     0     0    00 | Func |  その他の即値無し命令


信号線の構成

名前      説明
-----------------------
alu_sel   ALU の機能選択
alu_out   ALU 出力
src_a     ALU-A 入力（stack[0], FP, IP, cstack[0]）
src_b     ALU-B 入力（stack[1], insn & imm_mask）
src_a_X   ALU-A に入力する値の選択
          4 つの信号線のうち 1 本だけが 1、その他は 0 となる
imm       0: 即値無し命令（src_b は stack[1] を選択）
          1: 即値有り命令（src_b は insn & imm_mask を選択）
wr_stk1   0/1: wr_data に stack[0/1] を出力
pop/push  stack をポップ/プッシュ
load_stk  stack[0] に stack_in をロード
load_fp   FP に alu_out をロード
load_ip   IP に alu_out をロード
cpop      cstack をポップ
cpush     cstack に値をプッシュ
rd_mem    stack_in に接続する値の選択
          0: alu_out, 1: rd_data
wr_mem    メモリに wr_data を書き込む
stack_in  stack[0] の入力値（alu_out, rd_data）
imm_mask  insn から即値を取り出すためのビットマスク

- stack: 演算用スタック
- cstack: コールスタック（CALL の戻り先アドレスと FP の記憶）


レジスタ

名前      説明
-----------------------
fp        フレームポインタ（スタックフレームの先頭を指す）
ip        命令（instruction）ポインタ（次に実行する命令を指す）
insn      命令（instruction）レジスタ
addr0_d   mem_addr の最下位ビットを 1 クロック遅延した値


メモリマップ

addr      説明
---------------
000h-07fh CPU 内蔵機能
080h-0ffh 周辺機器
100h-2ffh データメモリ
300h-fffh プログラムメモリ

メモリマップトレジスタ

addr      説明
---------------
000h-001h 無効
002h-003h カウントダウンタイマ
080h      ドットマトリクス LED
081h      キャラクタ LCD
082h-083h UART 入出力

081h の説明
ビット 0: E
ビット 1: R/W
ビット 2: RS
ビット 4 - 7: DB4 - DB7

082h-083h の説明
入出力とも、下位 8 ビットが有効
入力は最後に受信された値が読める（一度読んでもクリアされない）
入力データは上位 8 ビットを 0xfe とし、下位 8 ビットに有効値を載せる


信号タイミング
doc/signal-timing-design に記載
*/

// CPU コアの信号
logic imm, sign, src_a_stk0, src_a_fp, src_a_ip, src_a_cstk, wr_stk1, pop, push,
  load_stk, load_fp, load_ip, load_insn, cpop, cpush, rd_mem;
logic [15:0] alu_out, src_a, src_b, stack_in, cstack0, imm_mask, wr_data_raw;

// レジスタ群
logic [15:0] fp, ip, insn;
logic [`ADDR_WIDTH-1:0] addr_d;

// 結線
assign src_a = src_a_fp ? fp
               : src_a_ip ? ip
               : src_a_cstk ? cstack0 : stack0;
assign src_b = imm ? mask_imm(insn, imm_mask, sign) : stack1;
assign stack_in = rd_mem ? byte_format(data_memreg, byt, addr_d[0]) : alu_out;
assign mem_addr = alu_out[`ADDR_WIDTH-1:0];
assign wr_data_raw = wr_stk1 ? stack1 : stack0;
assign wr_data = mem_addr[0] ? {wr_data_raw[7:0], 8'd0} : wr_data_raw;

// CPU コアモジュール群
alu alu(
  .a(src_a),
  .b(src_b),
  .cond(stack0[0]),
  .sel(alu_sel),
  .out(alu_out)
);

stack stack(
  .rst(rst),
  .clk(clk),
  .pop(pop),
  .push(push),
  .load(load_stk),
  .data_in(stack_in),
  .data0(stack0),
  .data1(stack1)
);

stack cstack(
  .rst(rst),
  .clk(clk),
  .pop(cpop),
  .push(cpush),
  .load(cpush),
  .data_in(alu_out),
  .data0(cstack0)
);

signals signals(
  .rst(rst),
  .clk(clk),
  .insn(insn),
  .imm(imm),
  .sign(sign),
  .imm_mask(imm_mask),
  .src_a_stk0(src_a_stk0),
  .src_a_fp(src_a_fp),
  .src_a_ip(src_a_ip),
  .src_a_cstk(src_a_cstk),
  .alu_sel(alu_sel),
  .wr_stk1(wr_stk1),
  .pop(pop),
  .push(push),
  .load_stk(load_stk),
  .load_fp(load_fp),
  .load_ip(load_ip),
  .load_insn(load_insn),
  .cpop(cpop),
  .cpush(cpush),
  .byt(byt),
  .rd_mem(rd_mem),
  .wr_mem(wr_mem)
);

// CPU コアのレジスタ群
always @(posedge clk, posedge rst) begin
  if (rst)
    fp <= 16'd0;
  else if (load_fp)
    fp <= alu_out;
end

always @(posedge clk, posedge rst) begin
  if (rst)
    ip <= 16'h0300;
  else if (load_ip)
    ip <= alu_out;
end

always @(posedge clk, posedge rst) begin
  if (rst)
    insn <= 16'd0;
  else if (load_insn)
    insn <= rd_data;
end

always @(posedge clk, posedge rst) begin
  if (rst)
    addr_d <= `ADDR_WIDTH'd0;
  else
    addr_d <= mem_addr;
end

// CPU コア用の function 定義
function [15:0] byte_format(input [15:0] val16, input byt, input addr1);
begin
  if (~byt)
    byte_format = val16;
  else begin
    if (addr1)
      byte_format = val16 >> 8;
    else
      byte_format = val16 & 16'h00ff;
  end
end
endfunction

function [15:0] mask_imm(input [15:0] imm16, input [15:0] imm_mask, input sign);
begin
  logic [5:0] sign_bits;
  logic [15:0] masked;
  sign_bits = 6'b111111 ^ imm_mask[15:10];
  masked = imm16 & imm_mask;
  mask_imm = sign ? (masked | (sign_bits << 10)) : masked;
end
endfunction

// CPU 内蔵周辺機能の信号
logic cdtimer_to, load_cdtimer;
logic [15:0] data_memreg, data_reg, cdtimer_cnt;

// 結線
assign data_memreg = addr_d >= `ADDR_WIDTH'h080 ? rd_data : data_reg;
assign data_reg = addr_d[6:0] === 7'h02 ? cdtimer_cnt : 16'd0;
assign load_cdtimer = wr_mem & mem_addr === `ADDR_WIDTH'h002;

// CPU 内蔵周辺機能モジュール群
cdtimer#(.PERIOD(CLOCK_HZ/1000)) cdtimer(
  .rst(rst),
  .clk(clk),
  .load(load_cdtimer),
  .data(wr_data),
  .counter(cdtimer_cnt),
  .timeout(cdtimer_to)
);

endmodule
