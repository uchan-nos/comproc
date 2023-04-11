`include "common.sv"

module cpu#(
  parameter CLOCK_HZ = 27_000_000
) (
  input rst,
  input clk,
  output [`ADDR_WIDTH-1:0] mem_addr,
  output logic mem_wr,
  output mem_byt,
  input        [15:0] rd_data,
  output logic [15:0] wr_data,
  output logic [15:0] stack[0:15]
);

/*
引数の仕様

mem_wr    メモリ書き込み命令のとき 1
mem_byt   バイトアクセスなら 1
rd_data   メモリからの読み込みデータ
          mem_byt=0 なら [15:0] が有効
          mem_byt=1 なら、mem_addr の最下位ビットに応じて [15:8] か [7:0] が有効
wr_data   メモリへの書き込みデータ
          mem_byt とビットの有効範囲は rd_data と同じ


命令リスト（即値有り）

mnemonic        15     87      0  説明
------------------------------------
PUSH imm15     |0     imm15     | imm15 を stack にプッシュ
JMP imm12      |1000   imm11   0| pc+imm12 にジャンプ
CALL imm12     |1000   imm11   1| コールスタックに pc+2 をプッシュし、pc+imm12 にジャンプ
JZ imm12       |1001   imm11   0| stack から値をポップし、0 なら pc+imm12 にジャンプ
JNZ imm12      |1001   imm11   1| stack から値をポップし、1 なら pc+imm12 にジャンプ
LD X+imm10     |1010xx  imm9   0| mem[X+imm10] から読んだ値を stack にプッシュ
ST X+imm10     |1011xx  imm9   0| stack からポップした値を mem[X+imm10] に書く
PUSH X+imm10   |1100xx  imm10   | X+imm10 を stack にプッシュ
                                  X の選択: 0=stack[0], 1=fp, 2=ip, 3=cstack[0]
ADD FP,imm10   |110100  imm10   | fp += imm10
SUB FP,imm10   |110101  imm10   | fp -= imm10
               |11011xxxxxxxxxxx| 予約
               |1110xxxxxxxxxxxx| 予約


命令リスト（即値なし）

mnemonic    15     87      0  説明
------------------------------------
POP        |1111000000001111| stack をポップ
                              stack[0] に ALU-B をロードするので、ALU=0fh
POP 1      |1111000000000000| stack[1] 以降をポップ（stack[0] を保持）
                              stack[0] に ALU-A をロードするので、ALU=00h
INC        |1111000000000001| stack[0]++
INC2       |1111000000000010| stack[0] += 2
NOT        |1111000000000100| stack[0] = ~stack[0]

AND        |1111000000010000| stack[0] &= stack[1]
OR         |1111000000010001| stack[0] |= stack[1]
XOR        |1111000000010010| stack[0] ^= stack[1]
SHR        |1111000000010100| stack[0] >>= stack[1]（符号なしシフト）
SAR        |1111000000010101| stack[0] >>= stack[1]（符号付きシフト）
SHL        |1111000000010110| stack[0] <<= stack[1]
JOIN       |1111000000010111| stack[0] |= (stack[1] << 8)

ADD        |1111000000100000| stack[0] += stack[1]
SUB        |1111000000100001| stack[0] -= stack[1]
MUL        |1111000000100010| stack[0] *= stack[1]
LT         |1111000000101000| stack[0] = stack[0] < stack[1]
EQ         |1111000000101001| stack[0] = stack[0] == stack[1]
NEQ        |1111000000101010| stack[0] = stack[0] != stack[1]

DUP        |1111000001000000| stack[0] を stack にプッシュ
DUP 1      |1111000001000001| stack[1] を stack にプッシュ
LDD        |1111000010000000| stack からアドレスをポップし、mem[addr] を stack にプッシュ
STD        |1111000010000010| stack から値とアドレスをポップしメモリに書き、値をプッシュ
STA        |1111000010000011| stack から値とアドレスをポップしメモリに書き、アドレスをプッシュ
                              stack[0] = data, stack[1] = addr
LDD.1      |1111000011000000| byte version
STD.1      |1111000011000010| byte version
STA.1      |1111000011000011| byte version
RET        |1111000100000000| コールスタックからアドレスをポップし、ジャンプ
CPOP FP    |1111000100000010| コールスタックから値をポップし FP に書く
CPUSH FP   |1111000100000011| コールスタックに FP をプッシュ


ALU 機能

番号  名前  説明
----------------
00h   A     A
01h   INC   A + 1
02h   INC2  A + 2
03h   INC3  A + 3
04h   NOT   ~A
0fh   B     B
10h   AND   A & B
11h   OR    A | B
12h   XOR   A ^ B
14h   SHR   A >> B
15h   SAR   A >> B (符号付きシフト)
16h   SHL   A << B
17h   JOIN  A | (B << 8)
20h   ADD   A + B
21h   SUB   A - B
22h   MUL   A * B
28h   LT    A < B
29h   EQ    A == B
2ah   NEQ   A != B
30h   IF    cond ? A : B


制御線の構成
TODO: 新しい ISA に対応した説明に修正する

名前    説明
-----------------------
imm     0: insn[7:0] は ALU 機能選択
        1: insn[7:0] は即値
load    演算用スタックの先頭にロードする値の選択
        0: stack[0], 1: stack[1], 2: alu_out, 3: rd_data
rd      メモリ読み込み
wr      メモリ書き込み
pop     演算用スタックから値をポップ
push    演算用スタックに値をプッシュ
jmp     ジャンプ条件
        0: ジャンプしない, 1: 無条件, 2: stack[0] == 0, 3: stack[0] != 0
load_bp bp にロードする値の選択
        0/1: bp, 2: rd_data, 3: alu_out
load_fp fp にロードする値の選択
        0: fp, 1: fp+2, 2: fp-2, 3: alu_out

imm8=insn[7:0] 即値、ALU 機能選択



メモリマップ
TODO: 新しい ISA に対応した説明に修正する

addr      説明
---------------
000h-00fh CPU 内蔵機能
010h-01fh 周辺機器
020h-1ffh データメモリ
200h-3ffh プログラムメモリ

メモリマップトレジスタ

addr      説明
---------------
000h-001h カウントダウンタイマ
01ch      ドットマトリクス LED
01dh      キャラクタ LCD
01eh-01fh UART 入出力

01ch の説明
ビット 0: E
ビット 1: R/W
ビット 2: RS
ビット 4 - 7: DB4 - DB7

01eh-01fh の説明
入出力とも、下位 8 ビットが有効
入力は最後に受信された値が読める（一度読んでもクリアされない）
入力データは上位 8 ビットを 0xfe とし、下位 8 ビットに有効値を載せる


信号タイミング
TODO: 新しい ISA に対応した説明に修正する
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
TODO: 新しい ISA に対応した説明に修正する
3->0  命令フェッチ
0     デコード
0->1  メモリ読み込み（データ）
1->2  メモリ書き込み、PC 更新、演算スタック更新
2->3  メモリ読み込み（命令）
*/

/* メモリとスタックフレーム
          mem                 mem                 mem
bp -> |  old bp  |        |  old bp  |        |  old bp  |
      | stack    |        | stack    |        | stack    |
      |    frame |        |    frame |        |    frame |
fp -> |          |  bp=   | ret addr |        | ret addr |
      |          |  fp -> |  old bp  |  bp -> |  old bp  |
      |          |        |          |        | local    |
      |          |        |          |        |    vars  |
      |          |        |          |  fp -> |          |

        初期状態          CALL & ENTER     ローカル変数の配置

関数呼び出しによるスタックフレームの変化
*/
logic [1:0] phase;
logic [15:0] alu_out;
logic [15:0] insn;
logic [`ADDR_WIDTH-1:0] pc;
logic [`ADDR_WIDTH-1:0] bp, fp;
logic [15:0] cd_timer;
logic [15:0] cd_timer_ms;

logic imm, rd, wr, pop, push, byt;
logic [1:0] load;
logic [1:0] jmp;
logic [7:0] imm8;
logic [8:0] imm9;
logic [1:0] load_bp, load_fp;
logic [15:0] rd_mem_reg;

//localparam CLK_DIVIDER=32'd2_000_000;
localparam CLK_DIVIDER=32'd1;
logic [31:0] clk_div;

assign {imm, load, rd, wr, pop, push, jmp, byt, load_bp, load_fp} = decode(insn);
assign imm8 = insn[7:0];
assign imm9 = insn[8:0];

assign alu_out = alu(imm, insn, stack[0], stack[1]);
assign mem_addr = (phase <= 2'd1) ?
  (insn[15:9] == 7'h53 /* CALL */ ? fp
   : (insn[15:9] == 7'h54 /* RET */ ? fp - 2
   : alu_out[`ADDR_WIDTH-1:0])) : pc;
assign mem_byt = byt;

assign rd_mem_reg = read_mem_or_reg(mem_addr, rd_data, cd_timer);

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
      3'd0: stack[0] <= stack[0];
      3'd1: stack[0] <= stack[1];
      3'd2: stack[0] <= alu_out;
      3'd3: stack[0] <= byte_format(rd_mem_reg, byt, mem_addr & 1);
      3'd4: stack[0] <= { {16-`ADDR_WIDTH{1'b0}}, pc } + `ADDR_WIDTH'd2;
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
    if (insn[15:8] == 8'hc2) // ENTER
      wr_data <= bp;
    else if (insn[15:9] == 7'h53) // CALL
      wr_data <= pc + `ADDR_WIDTH'd2;
    else
      if (byt) begin
        if (mem_addr[0])
          wr_data[15:8] <= {imm ? stack[0][7:0] : stack[1][7:0]};
        else
          wr_data[7:0] <= {imm ? stack[0][7:0] : stack[1][7:0]};
      end else
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
    pc <= `ADDR_WIDTH'h200;
  else if (insn == 16'hffff)
    ;
  else if (phase == 2'd1)
    if ((jmp == 2'd1) ||
        (jmp == 2'd2 && stack[0] == 16'd0) ||
        (jmp == 2'd3 && stack[0] != 16'd0)) begin
      if (imm)
        pc <= pc + { {`ADDR_WIDTH-10{imm9[8]}}, imm9, 1'b0};
      else
        pc <= rd_data;
    end
    else
      pc <= pc + `ADDR_WIDTH'd2;
end

// スタックフレーム BP 制御
always @(posedge clk, posedge rst) begin
  if (rst)
    bp <= 16'd0;
  else if (phase == 2'd1)
    if (insn[15:8] == 8'hc2) // ENTER
      bp <= fp;
    else if (insn[15:8] == 8'hc3) // LEAVE
      bp <= rd_data;
end

// スタックフレーム FP 制御
always @(posedge clk, posedge rst) begin
  if (rst)
    fp <= `ADDR_WIDTH'd0;
  else if (phase == 2'd1)
    case (load_fp)
      2'd0: fp <= fp;
      2'd1: fp <= fp + `ADDR_WIDTH'd2;
      2'd2: fp <= fp - `ADDR_WIDTH'd2;
      2'd3: fp <= alu_out;
    endcase
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
  logic [15:0] sub;
  sub = stack0 - stack1;
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
      8'h08: alu = sub[15] ^ is_overflow(stack0[15], stack1[15], sub[15]);
      8'h09: alu = stack0 == stack1;
      8'h0a: alu = stack0 != stack1;
      8'h10: alu = stack0 & stack1;
      8'h11: alu = stack0 ^ stack1;
      8'h12: alu = stack0 | stack1;
      8'h13: alu = ~stack0;
      8'h14: alu = stack0 >> stack1;
      8'h15: alu = stack0 << stack1;
      8'h16: alu = shiftr_signed(stack0, stack1[3:0]);
      8'h20: alu = bp;
      8'h21: alu = fp;
    endcase
end
endfunction

function [13:0] decode(input [15:0] insn);
begin
  casex (insn[15:8])
    //                        i l  rw pp j  b b  f
    //                        m o  dr ou m  y p  p
    //                        m a     ps p  t
    //                          d      h
    8'b0xxxxxxx: decode = 14'b1_10_00_01_00_0_00_00;
    8'h81:       decode = 14'b0_01_00_10_00_0_00_00;
    8'h82:       decode = 14'b0_00_00_01_00_0_00_00 | {insn[0], 11'd0};
    8'h90:       decode = 14'b1_11_10_01_00_0_00_00;
    8'h91:       decode = 14'b0_11_10_11_00_0_00_00;
    8'h94:       decode = 14'b1_01_01_10_00_0_00_00;
    8'h95:       decode = 14'b0_00_01_10_00_0_00_00;
    8'h96:       decode = 14'b0_01_01_10_00_0_00_00;
    8'h98:       decode = 14'b1_11_10_01_00_1_00_00;
    8'h99:       decode = 14'b0_11_10_11_00_1_00_00;
    8'h9c:       decode = 14'b1_01_01_10_00_1_00_00;
    8'h9d:       decode = 14'b0_00_01_10_00_1_00_00;
    8'h9e:       decode = 14'b0_01_01_10_00_1_00_00;
    8'b1010000x: decode = 14'b1_00_00_00_01_0_00_00; // JMP
    8'b1010001x: decode = 14'b1_01_00_10_10_0_00_00; // JZ
    8'b1010010x: decode = 14'b1_01_00_10_11_0_00_00; // JNZ
    8'b1010011x: decode = 14'b1_00_01_00_01_0_00_01; // CALL
    8'b1010100x: decode = 14'b0_00_10_00_01_0_00_10; // RET
    8'hb0:       decode = 14'b0_10_00_10_00_0_00_00;
    8'hb1:       decode = 14'b0_10_00_11_00_0_00_00;
    8'hc0:       decode = 14'b0_10_00_01_00_0_00_00;
    8'hc1:       decode = 14'b0_01_00_10_00_0_00_11;
    8'hc2:       decode = 14'b0_00_01_00_00_0_11_00;
    8'hc3:       decode = 14'b0_00_10_00_00_0_10_11;
    default:     decode = 14'd0;
  endcase
end
endfunction

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

function is_overflow(input a, input b, input a_sub_b);
begin
  is_overflow = (a & ~b & ~a_sub_b) | (~a & b & a_sub_b);
end
endfunction

function [15:0] shiftr_signed(input [15:0] v, input [3:0] n);
begin
  case (n)
    4'd0:  shiftr_signed = v;
    4'd1:  shiftr_signed = {{ 2{v[15]}}, v[14:1]};
    4'd2:  shiftr_signed = {{ 3{v[15]}}, v[14:2]};
    4'd3:  shiftr_signed = {{ 4{v[15]}}, v[14:3]};
    4'd4:  shiftr_signed = {{ 5{v[15]}}, v[14:4]};
    4'd5:  shiftr_signed = {{ 6{v[15]}}, v[14:5]};
    4'd6:  shiftr_signed = {{ 7{v[15]}}, v[14:6]};
    4'd7:  shiftr_signed = {{ 8{v[15]}}, v[14:7]};
    4'd8:  shiftr_signed = {{ 9{v[15]}}, v[14:8]};
    4'd9:  shiftr_signed = {{10{v[15]}}, v[14:9]};
    4'd10: shiftr_signed = {{11{v[15]}}, v[14:10]};
    4'd11: shiftr_signed = {{12{v[15]}}, v[14:11]};
    4'd12: shiftr_signed = {{13{v[15]}}, v[14:12]};
    4'd13: shiftr_signed = {{14{v[15]}}, v[14:13]};
    4'd14: shiftr_signed = {{15{v[15]}}, v[14]};
    4'd15: shiftr_signed = {16{v[15]}};
  endcase
end
endfunction

function [15:0] read_mem_or_reg(
  input [`ADDR_WIDTH-1:0] addr,
  input [15:0] mem,
  input [15:0] cd_timer
);
begin
  casex (addr)
    `ADDR_WIDTH'b000x: read_mem_or_reg = cd_timer;
    `ADDR_WIDTH'b001x: read_mem_or_reg = 16'd1;
    `ADDR_WIDTH'b01xx: read_mem_or_reg = 16'd2;
    `ADDR_WIDTH'b1xxx: read_mem_or_reg = 16'd3;
    default:           read_mem_or_reg = mem;
  endcase
end
endfunction

// カウントダウンタイマ
always @(posedge clk, posedge rst) begin
  if (rst) begin
    cd_timer <= 16'd0;
    cd_timer_ms <= 16'd0; // 1ms 周期生成用
  end else if (phase == 2'd1 && wr && mem_addr == `ADDR_WIDTH'h000) begin
    cd_timer <= wr_data;
    cd_timer_ms <= 16'd0;
  end else if (cd_timer > 16'd0) begin
    if (cd_timer_ms < (CLOCK_HZ/1000) - 1) // Clock = 27MHz
      cd_timer_ms <= cd_timer_ms + 1;
    else begin
      cd_timer <= cd_timer - 1;
      cd_timer_ms <= 16'd0;
    end
  end
end

endmodule
