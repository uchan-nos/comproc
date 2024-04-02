`include "common.sv"

module cpu#(
  parameter CLOCK_HZ = 27_000_000
) (
  input rst,
  input clk,
  output [`ADDR_WIDTH-1:0] mem_addr,
  output rd_mem, wr_mem,
  output byt,
  input  [15:0] rd_data,
  output [15:0] wr_data,
  output [15:0] stack0,
  output [15:0] stack1,
  output logic [15:0] insn,
  output load_insn,
  output [5:0] alu_sel,
  input irq
);

/*
引数の仕様

rd_mem    明示的メモリ読み込み命令のとき 1
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
LD1  X+uimm10  |0010xx  uimm10  | バイトバージョン
ST1  X+uimm10  |0011xx  uimm10  | バイトバージョン
LD X+uimm10    |0100xx  uimm9  0| mem[X+uimm10] から読んだ値を stack にプッシュ
ST X+uimm10    |0100xx  uimm9  1| stack からポップした値を mem[X+uimm10] に書く
PUSH X+uimm10  |0101xx  uimm10  | X+uimm10 を stack にプッシュ
                                  X の選択: 0=0, 1=bar, 2=ip, 3=cstack[0]
               |011000xxxxxxxxxx| 予約
ADD FP,uimm10  |011001  uimm10  | fp += uimm10
               |01101xxxxxxxxxxx| 予約
               |0111xxxxxxxxxxxx| 即値なし命令（別表）


命令リスト（即値なし）

mnemonic    15     87      0  説明
------------------------------------
NOP        |0111000000000000| stack[0] に ALU-A をロードするので、ALU=00h
POP        |0111000001001111| stack をポップ
                              stack[0] に ALU-B をロードするので、ALU=0fh
POP1       |0111000001000000| stack[1] 以降をポップ（stack[0] を保持）
                              stack[0] に ALU-A をロードするので、ALU=00h
INC        |0111000000000001| stack[0]++
INC2       |0111000000000010| stack[0] += 2
NOT        |0111000000000100| stack[0] = ~stack[0]

AND        |0111000001010000| stack[0] = stack[1] & stack[0]
OR         |0111000001010001| stack[0] = stack[1] | stack[0]
XOR        |0111000001010010| stack[0] = stack[1] ^ stack[0]
SHR        |0111000001010100| stack[0] = stack[1] >> stack[0]（符号なしシフト）
SAR        |0111000001010101| stack[0] = stack[1] >> stack[0]（符号付きシフト）
SHL        |0111000001010110| stack[0] = stack[1] << stack[0]
JOIN       |0111000001010111| stack[0] = stack[1] | (stack[0] << 8)

ADD        |0111000001100000| stack[0] = stack[1] + stack[0]
SUB        |0111000001100001| stack[0] = stack[1] - stack[0]
MUL        |0111000001100010| stack[0] = stack[1] * stack[0]
LT         |0111000001101000| stack[0] = stack[1] < stack[0]
EQ         |0111000001101001| stack[0] = stack[1] == stack[0]
NEQ        |0111000001101010| stack[0] = stack[1] != stack[0]
LE         |0111000001101011| stack[0] = stack[1] <= stack[0]

DUP        |0111000010000000| stack[0] を stack にプッシュ
DUP1       |0111000010001111| stack[1] を stack にプッシュ
RET        |0111100000000000| コールスタックからアドレスをポップし、ジャンプ
CPOP FP    |0111100000000010| コールスタックから値をポップし FP に書く
CPUSH FP   |0111100000000011| コールスタックに FP をプッシュ
LDD        |0111100000001000| stack からアドレスをポップし、mem[addr] を stack にプッシュ
STA        |0111100000001100| stack から値とアドレスをポップしメモリに書き、アドレスをプッシュ
STD        |0111100000001110| stack から値とアドレスをポップしメモリに書き、値をプッシュ
                              stack[1] = data, stack[0] = addr
LDD1       |0111100000001001| byte version
STA1       |0111100000001101| byte version
STD1       |0111100000001111| byte version
INT        |0111100000010000| ソフトウェア割り込みを発生
ISR        |0111100000010001| stack から値を取り出し、ISR レジスタに書く
IRET       |0111100000010010| 割り込みハンドラから戻る

           |011111xxxxxxxxxx| UART データ受信（PC -> CPU）
           |0111111111111111| プログラム送信終了マーク



即値無し命令の構造

 15  12 11  10  8    7     6   5  4 3    0
| 0111 | 0 | 000 | Push | Pop |    ALU    |  stack だけを使う演算系命令
| 0111 | 1 | 000     0     0    00 | Func |  その他の即値無し命令


信号線の構成

名前      説明
-----------------------
alu_sel   ALU の機能選択
alu_out   ALU 出力
src_a     ALU-A 入力（stack[0], BAR, IP, cstack[0], FP）
src_a_X   ALU-A に入力する値の選択
          4 つの信号線のうち 1 本だけが 1、その他は 0 となる
src_b     ALU-B 入力
src_b_sel ALU-B 入力選択
          0: stack[1]
          1: insn & imm_mask
          2: isr
          3: reserved
wr_stk1   0/1: wr_data に stack[0/1] を出力
pop/push  stack をポップ/プッシュ
load_stk  stack[0] に stack_in をロード
load_fp   FP に alu_out をロード
load_ip   IP に alu_out をロード
load_insn INSN に rd_data をロード
load_isr  ISR に alu_out をロード
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
isr       割り込みハンドラ（ISR）のアドレスを保持するレジスタ


メモリマップ

addr      説明
---------------
000h-07fh MCU 内蔵機能
080h-0ffh 周辺機器
100h-2ffh データメモリ
300h-fffh プログラムメモリ

メモリマップトレジスタ

addr      説明
---------------
000h-001h 無効
002h-003h カウントダウンタイマ
004h-005h カウントダウンタイマ設定
006h-007h UART 入出力（下位 1 バイトのみ有効）
008h-009h UART 設定
00Ah-00Bh ADC 変換結果
010h-011h FLASH608K: XADR
012h-013h FLASH608K: YADR
014h-015h FLASH608K: 5:NVSTR 4:PROG 3:ERASE 2:SE 1:YE 0:XE
018h-019h FLASH608K: DIN low 16 bits
01Ah-01Bh FLASH608K: DIN high 16 bits
01Ch-01Dh FLASH608K: DOUT low 16 bits
01Eh-01Fh FLASH608K: DOUT high 16 bits
080h      ドットマトリクス LED
081h      キャラクタ LCD
082h      GPIO

004h-005h の説明
ビット 0: IF 割り込みフラグ
ビット 1: IE 割り込み有効（IF & IE == 1 で割り込み発生）

081h の説明
ビット 0: E
ビット 1: R/W
ビット 2: RS
ビット 4 - 7: DB4 - DB7

082h-083h の説明
入出力とも、下位 8 ビットが有効
入力は最後に受信された値が読める（一度読んでもクリアされない）
入力データは上位 8 ビットを 0xfe とし、下位 8 ビットに有効値を載せる

084h-085h の説明
ビット 0: RW  RF 受信データ存在フラグ（データレジスタ読み込みでクリア）
ビット 1: RW  RIE 受信割り込み有効（RF & RIE == 1 で割り込み発生）
ビット 2: RW  TF 送信データ空フラグ（データレジスタ書き込みでクリア）
ビット 3: RW  TIE 送信割り込み有効（TF & TIE == 1 で割り込み発生）


信号タイミング
doc/signal-timing-design に記載
*/

// CPU コアの信号
logic sign, wr_stk1, pop, push,
  load_stk, load_fp, load_ip, load_isr, cpop, cpush,
  irq_masked, ien, set_ien, clear_ien;
logic [2:0] src_a_sel;
logic [1:0] src_b_sel;
logic [15:0] alu_out, src_a, src_b, stack_in, cstack0, imm_mask, wr_data_raw;

// レジスタ群
logic [15:0] bar, ip, isr, fp;
logic [`ADDR_WIDTH-1:0] addr_d;

// 結線
assign src_a = src_a_sel === `SRCA_BAR  ? bar
             : src_a_sel === `SRCA_IP   ? ip
             : src_a_sel === `SRCA_CSTK ? cstack0
             : src_a_sel === `SRCA_FP   ? fp
             : stack0;
assign src_b = src_b_sel === 2'd0 ? stack1
               : src_b_sel === 2'd1 ? mask_imm(insn, imm_mask, sign)
               : isr;
assign stack_in = rd_mem ? byte_format(rd_data, byt, addr_d[0]) : alu_out;
assign mem_addr = alu_out[`ADDR_WIDTH-1:0];
assign wr_data_raw = wr_stk1 ? stack1 : stack0;
assign wr_data = mem_addr[0] ? {wr_data_raw[7:0], 8'd0} : wr_data_raw;
assign irq_masked = ien & irq;

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
  .irq(irq_masked),
  .insn(insn),
  .sign(sign),
  .imm_mask(imm_mask),
  .src_a_sel(src_a_sel),
  //.src_a_fp(src_a_fp),
  //.src_a_ip(src_a_ip),
  //.src_a_cstk(src_a_cstk),
  .src_b_sel(src_b_sel),
  .alu_sel(alu_sel),
  .wr_stk1(wr_stk1),
  .pop(pop),
  .push(push),
  .load_stk(load_stk),
  .load_fp(load_fp),
  .load_ip(load_ip),
  .load_insn(load_insn),
  .load_isr(load_isr),
  .cpop(cpop),
  .cpush(cpush),
  .byt(byt),
  .rd_mem(rd_mem),
  .wr_mem(wr_mem),
  .set_ien(set_ien),
  .clear_ien(clear_ien)
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
    isr <= 16'd0;
  else if (load_isr)
    isr <= alu_out;
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

always @(posedge clk, posedge rst) begin
  if (rst)
    ien <= 1'b1;
  else if (set_ien)
    ien <= 1'b1;
  else if (clear_ien)
    ien <= 1'b0;
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

endmodule
